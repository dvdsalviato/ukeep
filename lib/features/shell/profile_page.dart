import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.coupleId});
  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser!;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profilo', style: t.headlineMedium),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage:
                user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user.displayName ?? ''),
          subtitle: Text(user.email ?? ''),
        ),
        const Divider(height: 32),
        StreamBuilder<Map<String, dynamic>?>(
          stream: ref.read(coupleServiceProvider).watchCouple(coupleId),
          builder: (context, snap) {
            final data = snap.data;
            final members = (data?['members'] as List?)?.length ?? 1;
            final code = data?['inviteCode'] as String? ?? '…';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spazio condiviso', style: t.titleMedium),
                const SizedBox(height: 8),
                Text(members >= 2
                    ? 'Siete in due: tutto è sincronizzato.'
                    : 'Manca ancora il tuo partner. Mandagli questo codice:'),
                if (members < 2)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(code,
                        style: t.headlineSmall?.copyWith(letterSpacing: 4)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Codice copiato')));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => ref.read(authServiceProvider).signOut(),
          child: const Text('Esci'),
        ),
      ],
    );
  }
}
