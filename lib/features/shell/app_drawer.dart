import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/update.dart';
import '../../data/providers.dart';
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

    final titleStyle = TextStyle(
        color: UColors.accent, fontWeight: FontWeight.w700, fontSize: 16.5);
    final subStyle = TextStyle(color: UColors.muted, fontSize: 13);
    return Drawer(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UColors.bgTop, UColors.bgMid, UColors.bgBottom],
          ),
        ),
        child: ListTileTheme(
          iconColor: UColors.accent,
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
                              style: serif(24,
                                  style: FontStyle.italic,
                                  color: UColors.accent)),
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
              title: Text('Profilo', style: titleStyle),
              subtitle: Text('Foto, data di inizio, impronta', style: subStyle),
              onTap: () => go(() => openProfile(context)),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text('Notifiche', style: titleStyle),
              subtitle: Text('Mattino, sera, promemoria', style: subStyle),
              onTap: () => go(() => showNotifSheet(context)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: ThemeCtl.dark,
              builder: (context, dark, _) => SwitchListTile(
                secondary: Icon(dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined),
                title: Text('Tema scuro', style: titleStyle),
                value: dark,
                activeThumbColor: UColors.dark,
                onChanged: (_) {
                  Navigator.of(context).pop();
                  ThemeCtl.toggle();
                },
              ),
            ),
            const Spacer(),
            Divider(height: 1, color: UColors.muted.withAlpha(40)),
            ListTile(
              leading: Image.asset('assets/logo.png', width: 28, height: 28),
              title: Text(
                  AppVersion.build > 0
                      ? 'Ukeep · build ${AppVersion.build}'
                      : 'Ukeep',
                  style: titleStyle),
              subtitle: Text('Scarica l\'ultima versione', style: subStyle),
              onTap: () => go(openLatestApk),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
