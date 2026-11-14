import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/mood.dart';
import '../../core/notifications.dart';
import '../../core/push.dart';
import '../../core/widget_sync.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../calendar/calendar_page.dart';
import '../expenses/expenses_page.dart';
import '../home/home_page.dart';
import '../lists/lists_page.dart';
import '../tasks/tasks_page.dart';
import 'app_drawer.dart';

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
    NotifService.instance.setCouple(widget.coupleId);
    NotifService.instance.init().then((_) {
      _recurring();
      _syncNotifs();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) Push.instance.init(uid);
      final m = ref.read(membersProvider).value;
      if (m != null) {
        Push.instance.setMembers(m, uid, coupleId: widget.coupleId);
      }
      _syncWidget();
      _checkMood();
    });
  }

  bool _moodAsked = false;

  void _recurring() {
    final ex = ref.read(expensesProvider).value;
    final repo = ref.read(repoProvider);
    if (ex == null) return;
    NotifService.instance.setExpenses(ex);
    if (repo != null) processRecurringExpenses(repo, ex);
  }

  void _checkMood() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final members = ref.read(membersProvider).value;
    if (uid == null || members == null || members.isEmpty) return;
    _moodAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        maybeAskMood(context, members, uid, repo: ref.read(repoProvider));
      }
    });
  }

  void _syncWidget() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final tasks = ref.read(tasksProvider).value ?? [];
    final events = ref.read(eventsProvider).value ?? [];
    final today = dayOnly(DateTime.now());
    final todayTasks = tasks.where((t) {
      if (t.flag('done')) return false;
      final a = t.data['assignee'] as String?;
      if (a != null && a != uid) return false;
      final d = t.date('due');
      return d != null && !dayOnly(d).isAfter(today);
    }).toList()
      ..sort(compareOpen);
    DateTime? best;
    String next = '';
    for (final e in events) {
      final n = nextOccurrence(e, today);
      if (n != null && (best == null || n.isBefore(best))) {
        best = n;
        final days = n.difference(today).inDays;
        next = days == 0
            ? '🎉 Oggi: ${e.str('title')}'
            : '⏳ ${e.str('title')} tra $days ${days == 1 ? 'giorno' : 'giorni'}';
      }
    }
    WidgetSync.update(
        coupleId: widget.coupleId, today: todayTasks, next: next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNotifs();
      _syncWidget();
      _checkMood();
      _recurring();
    }
  }

  void _syncNotifs() {
    final list = ref.read(tasksProvider).value;
    if (list != null) {
      NotifService.instance
          .sync(list, FirebaseAuth.instance.currentUser?.uid);
    }
  }

  /// Schede visitate, per il tasto indietro.
  final List<int> _history = [];

  final _scaffold = GlobalKey<ScaffoldState>();

  void _go(int i) {
    if (i == _index) {
      scrollTabTop(i);
      return;
    }
    setState(() {
      _history.remove(_index);
      _history.add(_index);
      if (_history.length > 10) _history.removeAt(0);
      _index = i;
    });
  }

  Future<void> _back() async {
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      _scaffold.currentState?.closeDrawer();
      return;
    }
    if (_history.isNotEmpty) {
      setState(() => _index = _history.removeLast());
      return;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UColors.surface,
        content: const Text('Vuoi uscire da Ukeep?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Resta')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Esci')),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tasksProvider, (prev, next) {
      final list = next.value;
      if (list != null) {
        NotifService.instance
            .sync(list, FirebaseAuth.instance.currentUser?.uid);
        _syncWidget();
      }
    });
    ref.listen(membersProvider, (prev, next) {
      final m = next.value;
      if (m == null) return;
      Push.instance.setMembers(m, FirebaseAuth.instance.currentUser?.uid,
          coupleId: widget.coupleId);
      if (!_moodAsked) _checkMood();
    });
    ref.listen(eventsProvider, (prev, next) => _syncWidget());
    ref.listen(expensesProvider, (prev, next) {
      final ex = next.value;
      if (ex == null) return;
      NotifService.instance.setExpenses(ex);
      final repo = ref.read(repoProvider);
      if (repo != null) processRecurringExpenses(repo, ex);
    });
    ref.listen(coupleDocProvider, (prev, next) => _syncWidget());
    final pages = <Widget>[
      HomePage(onGoTo: _go),
      const TasksPage(),
      const ListsHub(),
      const CalendarPage(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
      key: _scaffold,
      drawer: AppDrawer(coupleId: widget.coupleId),
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [UColors.surface.withAlpha(0), UColors.surface.withAlpha(215)],
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
            ],
          ),
        ),
      ),
    ),
    );
  }
}
