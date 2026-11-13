import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                UAvatar(name: user.displayName, photo: user.photoURL, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? '', style: serif(24)),
                      const SizedBox(height: 2),
                      Text(user.email ?? '',
                          style: const TextStyle(color: UColors.muted)),
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
                      UAvatar(
                          name: partners.first.str('name'),
                          photo: partners.first.str('photo'),
                          size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'Siete in due con ${firstName(partners.first.str('name'))}: tutto è sincronizzato.'),
                      ),
                    ],
                  )
                else ...[
                  const Text(
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: repo == null
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(1980),
                            lastDate: now,
                            helpText: 'Da quando state insieme?',
                          );
                          if (d != null) repo.setSince(d);
                        },
                ),
                Divider(height: 1, color: UColors.muted.withAlpha(40)),
                ListTile(
                  leading: const Icon(Icons.logout, color: UColors.danger),
                  title: const Text('Esci',
                      style: TextStyle(color: UColors.danger)),
                  onTap: () => ref.read(authServiceProvider).signOut(),
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
              const Text('Ukeep',
                  style: TextStyle(color: UColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
