import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed.dart';
import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/update.dart';
import '../../data/providers.dart';
import '../search/search_page.dart';
import '../tasks/tasks_page.dart';
import 'profile_page.dart';

/// Apre il Profilo come pagina.
void openProfile(BuildContext context) {
  final id =
      ProviderScope.containerOf(context, listen: false).read(coupleIdProvider).value;
  if (id == null) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(),
      body: ProfilePage(coupleId: id),
    ),
  ));
}

/// Menu laterale (le tre lineette in Home).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.coupleId});
  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser;
    final members = ref.watch(membersProvider).value ?? [];
    final meItem = memberById(members, me?.uid);

    void go(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      backgroundColor: UColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => go(() => openProfile(context)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    UAvatar(
                        name: me?.displayName,
                        photo: me?.photoURL,
                        b64: meItem?.str('photoB64'),
                        size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me?.displayName ?? 'Profilo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: serif(22)),
                          Text('Il tuo profilo ›',
                              style: TextStyle(color: UColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: UColors.muted.withAlpha(40)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profilo'),
              subtitle: const Text('Foto, data di inizio, impronta'),
              onTap: () => go(() => openProfile(context)),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notifiche'),
              subtitle: const Text('Mattino, sera, promemoria'),
              onTap: () => go(() => showNotifSheet(context)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ThemeCtl.dark,
              builder: (context, dark, _) => SwitchListTile(
                secondary: Icon(dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined),
                title: const Text('Tema scuro'),
                value: dark,
                activeThumbColor: UColors.dark,
                onChanged: (_) {
                  Navigator.of(context).pop();
                  ThemeCtl.toggle();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Novità'),
              subtitle: const Text('Tutto quello che avete fatto'),
              onTap: () => go(() => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedPage()))),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Cerca'),
              onTap: () => go(() => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchPage()))),
            ),
            const Spacer(),
            Divider(height: 1, color: UColors.muted.withAlpha(40)),
            ListTile(
              leading: Image.asset('assets/logo.png', width: 28, height: 28),
              title: Text(AppVersion.build > 0
                  ? 'Ukeep · build ${AppVersion.build}'
                  : 'Ukeep'),
              subtitle: const Text('Scarica l\'ultima versione'),
              onTap: () => go(openLatestApk),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
