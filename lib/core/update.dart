import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/providers.dart';
import 'theme.dart';
import 'ui.dart';

/// Aggiornamento obbligatorio per entrambi.
///
/// Ogni telefono conosce il proprio numero di build (quello di GitHub
/// Actions). Il documento della coppia tiene la build più nuova installata
/// da uno dei due (couples/{id}.appBuild): chi ha una build più vecchia
/// vede solo la schermata "Aggiorna Ukeep".
class AppVersion {
  AppVersion._();
  static int build = 0;
  static String name = '';

  static Future<void> load() async {
    // la webapp è sempre aggiornata: niente numero di build, così non
    // obbliga il telefono ad aggiornare e non viene bloccata
    if (kIsWeb) return;
    try {
      final i = await PackageInfo.fromPlatform();
      build = int.tryParse(i.buildNumber) ?? 0;
      name = i.version;
    } catch (_) {}
  }
}

const _repo = 'dvdsalviato/ukeep';

/// Apre il download dell'APK più recente (o la pagina delle Releases).
Future<void> openLatestApk() async {
  var url = 'https://github.com/$_repo/releases';
  try {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/$_repo/releases?per_page=1'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final list = jsonDecode(r.body) as List;
      if (list.isNotEmpty) {
        final assets = (list.first as Map)['assets'] as List? ?? [];
        for (final a in assets) {
          final u = '${(a as Map)['browser_download_url'] ?? ''}';
          if (u.endsWith('.apk')) {
            url = u;
            break;
          }
        }
      }
    }
  } catch (_) {}
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Mette davanti all'app la schermata di aggiornamento quando serve,
/// e registra la propria build se è la più nuova.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.coupleId, required this.child});
  final String coupleId;
  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  int _written = 0;

  @override
  Widget build(BuildContext context) {
    final couple = ref.watch(coupleDocProvider).value;
    final need = (couple?['appBuild'] as num?)?.toInt() ?? 0;
    final mine = AppVersion.build;
    if (mine > 0 && couple != null && mine > need && _written != mine) {
      _written = mine;
      FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .update({'appBuild': mine});
    }
    if (mine > 0 && need > mine) return UpdatePage(need: need);
    return widget.child;
  }
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.need});
  final int need;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Image.asset('assets/logo.png',
                        width: 110, height: 110)),
                const SizedBox(height: 26),
                Text('Aggiorna Ukeep',
                    textAlign: TextAlign.center, style: serif(36)),
                const SizedBox(height: 12),
                Text(
                  'Il tuo partner usa già la versione nuova. Per tenere i '
                  'vostri dati in ordine serve la stessa versione anche qui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu hai la build ${AppVersion.build}, serve la ${widget.need} o più nuova.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  style: pillStyle,
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await openLatestApk();
                          if (mounted) setState(() => _busy = false);
                        },
                  icon: const Icon(Icons.download),
                  label: Text(_busy ? 'Apro il download…' : 'Scarica l\'aggiornamento'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Si scarica l\'APK: aprilo e tocca "Aggiorna". '
                  'Non serve disinstallare, i dati restano.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
