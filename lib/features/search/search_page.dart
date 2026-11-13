import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secret.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../calendar/calendar_page.dart';
import '../expenses/expenses_page.dart';
import '../lists/lists_page.dart';
import '../projects/projects_page.dart';
import '../tasks/tasks_page.dart';
import '../wishes/wishes_page.dart';

class _Hit {
  _Hit(this.icon, this.title, this.sub, this.open);
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback open;
}

/// Cerca in attività, liste (anche nelle voci), desideri, progetti, date e spese.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _q = TextEditingController();
  final Map<String, List<String>> _listItems = {};
  final Map<String, List<String>> _projectSteps = {};
  bool _loaded = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadSub(Repo repo, List<Item> lists, List<Item> projects) async {
    if (_loaded) return;
    _loaded = true;
    for (final l in lists.where((l) => !isLocked(l))) {
      final s = await repo.col('lists').doc(l.id).collection('items').get();
      _listItems[l.id] = s.docs.map((d) => '${d.data()['t'] ?? ''}').toList();
    }
    for (final p in projects.where((p) => !isLocked(p))) {
      final s = await repo.col('projects').doc(p.id).collection('steps').get();
      _projectSteps[p.id] = s.docs.map((d) => '${d.data()['t'] ?? ''}').toList();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final tasks = ref.watch(tasksProvider).value ?? [];
    final lists = ref.watch(listsProvider).value ?? [];
    final wishes = ref.watch(wishesProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];
    final expenses = ref.watch(expensesProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    if (repo != null && (lists.isNotEmpty || projects.isNotEmpty)) {
      _loadSub(repo, lists, projects);
    }

    final q = _q.text.trim().toLowerCase();
    bool has(String s) => s.toLowerCase().contains(q);
    final hits = <_Hit>[];
    if (q.length >= 2 && repo != null) {
      for (final t in tasks) {
        if (has(t.str('title')) || has(t.str('note'))) {
          hits.add(_Hit(
              t.flag('done') ? Icons.check_circle : Icons.check_circle_outline,
              t.str('title'),
              t.flag('done') ? 'Attività fatta' : 'Attività',
              () => showTaskSheet(context, repo, members, item: t)));
        }
      }
      for (final l in lists.where((l) => !isLocked(l))) {
        final inside = [
          ...?_listItems[l.id],
          ...l.steps('items').map((m) => '${m['t'] ?? ''}'),
        ].where(has).toList();
        if (has(l.str('name')) || inside.isNotEmpty) {
          hits.add(_Hit(
              Icons.list_alt,
              l.str('name'),
              inside.isEmpty ? 'Lista' : 'Nella lista: ${inside.take(3).join(', ')}',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ListDetailPage(listId: l.id)))));
        }
      }
      for (final w in wishes) {
        if (has(w.str('title')) || has(w.str('note'))) {
          hits.add(_Hit(Icons.star_border, w.str('title'), 'Desiderio',
              () => showWishSheet(context, repo, item: w)));
        }
      }
      for (final p in projects.where((p) => !isLocked(p))) {
        final inside = [
          ...?_projectSteps[p.id],
          ...p.steps('steps').map((m) => '${m['t'] ?? ''}'),
        ].where(has).toList();
        if (has(p.str('title')) || has(p.str('desc')) || inside.isNotEmpty) {
          hits.add(_Hit(
              Icons.flag_outlined,
              p.str('title'),
              inside.isEmpty ? 'Progetto' : 'Passo: ${inside.take(2).join(', ')}',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProjectDetailPage(projectId: p.id)))));
        }
      }
      for (final e in events) {
        if (has(e.str('title'))) {
          final d = e.date('date');
          hits.add(_Hit(eventIcon(e.str('type')), e.str('title'),
              d == null ? 'Data' : 'Data · ${fmtDay(d)}',
              () => showEventSheet(context, repo, item: e)));
        }
      }
      for (final x in expenses) {
        if (has(x.str('title'))) {
          hits.add(_Hit(Icons.euro, x.str('title'),
              'Spesa · ${eur(expenseAmount(x))}',
              () => showExpenseSheet(context, repo, members, item: x)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: UColors.ink, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Cerca in Ukeep…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: UColors.muted),
          ),
        ),
        actions: [
          if (_q.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _q.clear()),
            ),
        ],
      ),
      body: q.length < 2
          ? EmptyHint(Icons.search,
              'Scrivi almeno 2 lettere: cerco in attività, liste, desideri, progetti, date e spese.')
          : hits.isEmpty
              ? EmptyHint(Icons.search_off, 'Niente trovato per "${_q.text}"')
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 24 + bottomInset(context)),
                  children: [
                    UCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Column(
                        children: [
                          for (final h in hits)
                            ListTile(
                              leading: Icon(h.icon, color: UColors.accent),
                              title: Text(h.title),
                              subtitle: Text(h.sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: UColors.muted)),
                              onTap: h.open,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
