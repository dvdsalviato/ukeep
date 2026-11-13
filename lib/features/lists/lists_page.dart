import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../projects/projects_page.dart';
import '../wishes/wishes_page.dart';

/// Scheda "Liste": contiene Liste, Desideri e Progetti.
class ListsHub extends ConsumerWidget {
  const ListsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    return ValueListenableBuilder<int>(
      valueListenable: listsSegment,
      builder: (context, seg, _) {
        VoidCallback? add;
        String label = 'Nuova lista';
        if (repo != null) {
          if (seg == 0) {
            add = () => showListSheet(context, repo);
          } else if (seg == 1) {
            label = 'Nuovo desiderio';
            add = () => showWishSheet(context, repo);
          } else {
            label = 'Nuovo progetto';
            add = () => showProjectSheet(context, repo);
          }
        }
        return Scaffold(
          floatingActionButton:
              add == null ? null : pillFab(label: label, onPressed: add),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              const PageHeader(
                  title: 'Liste', subtitle: 'Tutto quello che condividete'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(190),
                      selectedBackgroundColor: UColors.dark,
                      selectedForegroundColor: Colors.white,
                      foregroundColor: UColors.ink,
                      side: BorderSide.none,
                    ),
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Liste')),
                      ButtonSegment(value: 1, label: Text('Desideri')),
                      ButtonSegment(value: 2, label: Text('Progetti')),
                    ],
                    selected: {seg},
                    onSelectionChanged: (s) => listsSegment.value = s.first,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (seg == 0) const ListsSection(),
              if (seg == 1) const WishesSection(),
              if (seg == 2) const ProjectsSection(),
            ],
          ),
        );
      },
    );
  }
}

List<Map<String, dynamic>> _items(Item l) => l.steps('items');

class ListsSection extends ConsumerWidget {
  const ListsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = [...(ref.watch(listsProvider).value ?? <Item>[])]..sort(
        (a, b) => (a.date('createdAt') ?? DateTime(2100))
            .compareTo(b.date('createdAt') ?? DateTime(2100)));
    if (lists.isEmpty) {
      return const EmptyHint(Icons.list_alt,
          'Nessuna lista ancora. Create la spesa, i film da vedere, le idee per il viaggio…');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final l in lists)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ListDetailPage(listId: l.id))),
                child: Builder(builder: (context) {
                  final items = _items(l);
                  final done = items.where((i) => i['d'] == true).length;
                  return Row(
                    children: [
                      Text(l.str('icon', '📝'),
                          style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.str('name'), style: serif(22)),
                            const SizedBox(height: 4),
                            Text(
                                items.isEmpty
                                    ? 'Vuota'
                                    : '$done di ${items.length} fatti',
                                style:
                                    const TextStyle(color: UColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: UColors.muted),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showListSheet(BuildContext context, Repo repo, {Item? item}) =>
    showUSheet(context, _ListForm(repo: repo, item: item));

class _ListForm extends StatefulWidget {
  const _ListForm({required this.repo, this.item});
  final Repo repo;
  final Item? item;

  @override
  State<_ListForm> createState() => _ListFormState();
}

class _ListFormState extends State<_ListForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item?.str('name'));
  late String _icon = widget.item?.str('icon', '🛒') ?? '🛒';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.item == null) {
      widget.repo.add('lists', {'name': name, 'icon': _icon, 'items': []});
    } else {
      widget.repo.update('lists', widget.item!.id, {'name': name, 'icon': _icon});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const icons = ['🛒', '🧺', '✈️', '🎬', '🍽️', '🏠', '🎁', '📚', '🎵', '📝'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuova lista' : 'Modifica lista',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Nome', hint: 'Es. Spesa'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in icons)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _icon == i
                        ? UColors.rose.withAlpha(100)
                        : UColors.bgMid,
                    borderRadius: BorderRadius.circular(16),
                    border: _icon == i
                        ? Border.all(color: UColors.dark, width: 1.4)
                        : null,
                  ),
                  child: Text(i, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}

class ListDetailPage extends ConsumerStatefulWidget {
  const ListDetailPage({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends ConsumerState<ListDetailPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _set(Repo repo, List<Map<String, dynamic>> items) =>
      repo.update('lists', widget.listId, {'items': items});

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final lists = ref.watch(listsProvider).value ?? [];
    Item? list;
    for (final l in lists) {
      if (l.id == widget.listId) list = l;
    }
    if (list == null || repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = _items(list);
    final order = [
      ...List.generate(items.length, (i) => i).where((i) => items[i]['d'] != true),
      ...List.generate(items.length, (i) => i).where((i) => items[i]['d'] == true),
    ];
    final doneCount = items.where((i) => i['d'] == true).length;

    void add() {
      final t = _input.text.trim();
      if (t.isEmpty) return;
      _set(repo, [
        ...items,
        {'t': t, 'd': false}
      ]);
      _input.clear();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${list.str('icon', '📝')}  ${list.str('name')}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                showListSheet(context, repo, item: list);
              } else if (v == 'clear') {
                _set(repo, items.where((i) => i['d'] != true).toList());
              } else if (v == 'delete') {
                if (await confirm(context, 'Eliminare la lista "${list!.str('name')}"?')) {
                  repo.remove('lists', widget.listId);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Modifica')),
              PopupMenuItem(value: 'clear', child: Text('Rimuovi i completati')),
              PopupMenuItem(value: 'delete', child: Text('Elimina lista')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + bottomInset(context)),
        children: [
          UCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => add(),
                    decoration: const InputDecoration(
                        hintText: 'Aggiungi un elemento…',
                        border: InputBorder.none),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: UColors.dark),
                  onPressed: add,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyHint(Icons.playlist_add, 'La lista è vuota. Scrivi qui sopra il primo elemento.')
          else
            UCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (final i in order)
                    Dismissible(
                      key: ValueKey('${widget.listId}-$i-${items[i]['t']}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12),
                        child: const Icon(Icons.delete_outline,
                            color: UColors.danger),
                      ),
                      onDismissed: (_) {
                        final next = [...items]..removeAt(i);
                        _set(repo, next);
                      },
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: UColors.accent,
                        shape: const CircleBorder(),
                        value: items[i]['d'] == true,
                        onChanged: (v) {
                          final next = [...items];
                          next[i] = {...next[i], 'd': v == true};
                          _set(repo, next);
                        },
                        title: Text(
                          '${items[i]['t']}',
                          style: TextStyle(
                            fontSize: 16.5,
                            decoration: items[i]['d'] == true
                                ? TextDecoration.lineThrough
                                : null,
                            color: items[i]['d'] == true
                                ? UColors.muted
                                : UColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (doneCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text('$doneCount di ${items.length} fatti',
                    style: const TextStyle(color: UColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}
