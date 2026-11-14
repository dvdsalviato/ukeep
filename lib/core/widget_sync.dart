import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../features/tasks/tasks_page.dart';
import 'feed.dart';
import 'push.dart';

/// Widget sulla schermata Home del telefono:
/// - UkeepWidget: attività di oggi, si spuntano toccandole;
/// - UkeepHugWidget: "Ti penso" (manda l'abbraccio) / "Giulia ti pensa".
class WidgetSync {
  WidgetSync._();
  static String _last = '';
  static String _lastId = '';

  /// Attività di oggi (mie o di entrambi, non fatte, scadute comprese).
  static Future<void> update({
    required String? coupleId,
    required List<Item> today,
    required String next,
  }) async {
    final list = today
        .take(6)
        .map((t) => {
              'id': t.id,
              't': t.str('time').isEmpty
                  ? t.str('title')
                  : '${t.str('time')}  ${t.str('title')}',
            })
        .toList();
    final count = today.isEmpty
        ? 'Oggi niente da fare 🎉'
        : (today.length == 1
            ? '1 cosa da fare oggi'
            : '${today.length} cose da fare oggi');
    final json = jsonEncode(list);
    final sig = '$coupleId|$count|$json|$next';
    if (sig == _last) return;
    _last = sig;
    try {
      if (coupleId != null) {
        await HomeWidget.saveWidgetData<String>('coupleId', coupleId);
      }
      await HomeWidget.saveWidgetData<String>('count', count);
      await HomeWidget.saveWidgetData<String>('tasks_json', json);
      await HomeWidget.saveWidgetData<String>('next', next);
      await HomeWidget.updateWidget(androidName: 'UkeepWidget');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }

  /// Chi sono io e chi è il partner (serve al widget "Ti penso").
  static Future<void> saveIdentity({
    required String? coupleId,
    required String? myUid,
    required String myName,
    required String? partnerUid,
    required String partnerName,
    required String partnerToken,
    required bool partnerOff,
  }) async {
    final sig =
        '$coupleId|$myUid|$myName|$partnerUid|$partnerName|$partnerToken|$partnerOff';
    if (sig == _lastId) return;
    _lastId = sig;
    try {
      if (coupleId != null) {
        await HomeWidget.saveWidgetData<String>('coupleId', coupleId);
      }
      await HomeWidget.saveWidgetData<String>('myUid', myUid ?? '');
      await HomeWidget.saveWidgetData<String>('myName', myName);
      await HomeWidget.saveWidgetData<String>('partnerUid', partnerUid ?? '');
      await HomeWidget.saveWidgetData<String>('partnerName', partnerName);
      await HomeWidget.saveWidgetData<String>('partnerToken', partnerToken);
      await HomeWidget.saveWidgetData<bool>('partnerOff', partnerOff);
      await HomeWidget.saveWidgetData<String>(
          'hug_label', 'Pensa a $partnerName');
      await HomeWidget.updateWidget(androidName: 'UkeepHugWidget');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }

  /// Stato del widget "Ti penso": idle, sent, recv.
  static Future<void> setHug(String state, {String? from}) async {
    try {
      final now = DateFormat('HH:mm').format(DateTime.now());
      await HomeWidget.saveWidgetData<String>('hug_state', state);
      if (state == 'recv') {
        await HomeWidget.saveWidgetData<String>(
            'hug_recv', '${from ?? 'Il partner'} ti pensa');
        await HomeWidget.saveWidgetData<String>('hug_time', 'alle $now');
      } else if (state == 'sent') {
        await HomeWidget.saveWidgetData<String>('hug_time', 'Inviato alle $now 💌');
      } else {
        await HomeWidget.saveWidgetData<String>('hug_time', '');
      }
      await HomeWidget.updateWidget(androidName: 'UkeepHugWidget');
    } catch (e) {
      debugPrint('Widget hug: $e');
    }
  }
}

Future<void> _bootFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  }
}

/// Manda l'abbraccio dal widget (app chiusa).
Future<bool> _hugFromWidget() async {
  final couple = await HomeWidget.getWidgetData<String>('coupleId');
  if (couple == null || couple.isEmpty) return false;
  await _bootFirebase();
  final repo = Repo(couple);
  await Push.instance.initForWidget();
  repo.add('hugs', {'at': FieldValue.serverTimestamp()});
  Feed.log(repo, icon: '🤗', text: 'ha mandato un abbraccio', push: false);
  return Push.instance.toPartner(
    title: '🤗 ${Push.instance.myName} ti pensa',
    body: 'Ti ha mandato un abbraccio',
    tag: 'hug',
    data: {'type': 'hug', 'from': Push.instance.myName},
  );
}

/// Arriva qui quando si tocca qualcosa nei widget.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  try {
    switch (uri.host) {
      case 'done':
        final id = uri.queryParameters['id'];
        if (id == null) return;
        // subito via dal widget, poi salvo
        final raw = await HomeWidget.getWidgetData<String>('tasks_json') ?? '[]';
        final list = (jsonDecode(raw) as List)
            .where((e) => (e as Map)['id'] != id)
            .toList();
        await HomeWidget.saveWidgetData<String>('tasks_json', jsonEncode(list));
        await HomeWidget.saveWidgetData<String>(
            'count',
            list.isEmpty
                ? 'Tutto fatto 🎉'
                : (list.length == 1
                    ? '1 cosa da fare oggi'
                    : '${list.length} cose da fare oggi'));
        await HomeWidget.updateWidget(androidName: 'UkeepWidget');
        final couple = await HomeWidget.getWidgetData<String>('coupleId');
        if (couple == null) return;
        await _bootFirebase();
        final repo = Repo(couple);
        final snap = await repo.col('tasks').doc(id).get();
        final data = snap.data();
        if (data != null && data['done'] != true) {
          await toggleTask(repo, Item(snap.id, data));
        }
        break;
      case 'hug':
      case 'hugback':
        await WidgetSync.setHug('sent');
        await _hugFromWidget();
        break;
      case 'hugclear':
        await WidgetSync.setHug('idle');
        break;
    }
  } catch (e) {
    debugPrint('Widget callback: $e');
  }
}
