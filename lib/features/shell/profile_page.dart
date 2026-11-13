import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/photo.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../tasks/tasks_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.coupleId});
  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser!;
    final couple = ref.watch(coupleDocProvider).value;
    final members = ref.watch(membersProvider).value ?? [];
    final repo = ref.watch(repoProvider);
    final partners = members.where((m) => m.id != user.uid).toList();
    final meItem = memberById(members, user.uid);
    DateTime? since;
    final rawSince = couple?['since'];
    if (rawSince is Timestamp) since = rawSince.toDate();
    final code = couple?['inviteCode'] as String? ?? '…';
    final count = (couple?['members'] as List?)?.length ?? 1;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const PageHeader(title: 'Profilo'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UCard(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => changeProfilePhoto(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UAvatar(
                          name: user.displayName,
                          photo: user.photoURL,
                          b64: meItem?.str('photoB64'),
                          size: 72),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: UColors.dark, shape: BoxShape.circle),
                          child: Icon(Icons.photo_camera,
                              size: 14, color: UColors.onDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? '', style: serif(24)),
                      const SizedBox(height: 2),
                      Text(user.email ?? '',
                          style: TextStyle(color: UColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Il vostro spazio', style: serif(24)),
                const SizedBox(height: 10),
                if (count >= 2 && partners.isNotEmpty)
                  Row(
                    children: [
                      UAvatar.member(partners.first, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'Siete in due con ${firstName(partners.first.str('name'))}: tutto è sincronizzato.'),
                      ),
                    ],
                  )
                else ...[
                  Text(
                      'Manca ancora il tuo partner. Mandagli questo codice:',
                      style: TextStyle(color: UColors.muted)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: UColors.bgMid,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(code,
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Codice copiato')));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Data di inizio della coppia'),
                  subtitle: Text(since == null
                      ? 'Non ancora impostata'
                      : '${DateFormat('d MMMM y', 'it_IT').format(since)} · ${togetherText(since).replaceFirst('Insieme da ', '')}'),
                  trailing: Text(since == null ? 'Imposta' : 'Cambia',
                      style: TextStyle(
                          color: UColors.accent, fontWeight: FontWeight.w700)),
                  onTap: repo == null
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: since ?? now,
                            firstDate: DateTime(1980),
                            lastDate: now,
                            helpText: 'Da quando state insieme?',
                          );
                          if (d != null) repo.setSince(d);
                        },
                ),
                Divider(height: 1, color: UColors.muted.withAlpha(40)),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Esci (disconnetti)'),
                  onTap: () => ref.read(authServiceProvider).signOut(),
                ),
                Divider(height: 1, color: UColors.muted.withAlpha(40)),
                ListTile(
                  leading: Icon(Icons.heart_broken_outlined,
                      color: UColors.danger),
                  title: Text('Lascia la coppia',
                      style: TextStyle(color: UColors.danger)),
                  subtitle: const Text(
                      'Esci da questo spazio: i dati restano al partner'),
                  onTap: () async {
                    final ok = await _sure(
                        context,
                        'Lasciare la coppia?',
                        'Non vedrai più liste, attività e ricordi condivisi. '
                            'Il partner li conserva. Potrai creare o unirti '
                            'a un altro spazio.',
                        'Lascia');
                    if (!ok) return;
                    await ref
                        .read(coupleServiceProvider)
                        .leaveCouple(user.uid, coupleId);
                  },
                ),
                Divider(height: 1, color: UColors.muted.withAlpha(40)),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined,
                      color: UColors.danger),
                  title: Text('Elimina account',
                      style: TextStyle(color: UColors.danger)),
                  subtitle: const Text('Per sempre: ti chiederà di riconfermare Google'),
                  onTap: () async {
                    final ok = await _sure(
                        context,
                        'Eliminare l\'account?',
                        'Il tuo profilo e il tuo accesso vengono cancellati '
                            'per sempre. I dati condivisi restano al partner.',
                        'Elimina');
                    if (!ok) return;
                    try {
                      await ref
                          .read(authServiceProvider)
                          .deleteAccount(coupleId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Non riuscito: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Image.asset('assets/logo.png', width: 56),
              const SizedBox(height: 6),
              Text('Ukeep',
                  style: TextStyle(color: UColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

Future<bool> _sure(
    BuildContext context, String title, String text, String action) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: TextStyle(color: UColors.danger))),
      ],
    ),
  );
  return r ?? false;
}
