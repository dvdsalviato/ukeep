import 'package:flutter/material.dart';

import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.coupleId});
  final String coupleId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ComingSoon('Home'),
      const _ComingSoon('Attività'),
      const _ComingSoon('Liste'),
      const _ComingSoon('Calendario'),
      ProfilePage(coupleId: widget.coupleId),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('$title — in arrivo',
            style: Theme.of(context).textTheme.titleLarge),
      );
}
