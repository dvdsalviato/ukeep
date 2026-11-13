import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../calendar/calendar_page.dart';
import '../home/home_page.dart';
import '../lists/lists_page.dart';
import '../tasks/tasks_page.dart';
import 'profile_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.coupleId});
  final String coupleId;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifService.instance.init().then((_) => _syncNotifs());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncNotifs();
  }

  void _syncNotifs() {
    final list = ref.read(tasksProvider).value;
    if (list != null) {
      NotifService.instance
          .sync(list, FirebaseAuth.instance.currentUser?.uid);
    }
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    ref.listen(tasksProvider, (prev, next) {
      final list = next.value;
      if (list != null) {
        NotifService.instance
            .sync(list, FirebaseAuth.instance.currentUser?.uid);
      }
    });
    final pages = <Widget>[
      HomePage(onGoTo: _go),
      const TasksPage(),
      const ListsHub(),
      const CalendarPage(),
      ProfilePage(coupleId: widget.coupleId),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(215)],
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            iconTheme: WidgetStateProperty.resolveWith((states) =>
                IconThemeData(
                    size: 27,
                    color: states.contains(WidgetState.selected)
                        ? UColors.ink
                        : UColors.muted)),
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                TextStyle(
                    fontSize: 12,
                    color: states.contains(WidgetState.selected)
                        ? UColors.ink
                        : UColors.muted,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ),
          child: NavigationBar(
            elevation: 0,
            selectedIndex: _index,
            onDestinationSelected: _go,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Attività'),
              NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Liste'),
              NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Calendario'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profilo'),
            ],
          ),
        ),
      ),
    );
  }
}
