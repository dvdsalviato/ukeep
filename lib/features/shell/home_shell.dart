import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
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

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white.withAlpha(235),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: UColors.rose.withAlpha(90),
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                TextStyle(
                    fontSize: 12,
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
