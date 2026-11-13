import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secret.dart';
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
                child: _Seg(value: seg, onChanged: (v) => listsSegment.value = v),
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

class _Seg extends StatelessWidget {
  const _Seg({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Liste', 'Desideri', 'Progetti'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(190),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == i ? UColors.dark : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: value == i ? Colors.white : UColors.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _items(Item l) => l.steps('items');

class ListsSection extends ConsumerWidget {
  const ListsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final lists = [...(ref.watch(listsProvider).value ?? <Item>[])]..sort(
        (a, b) => (a.date('createdAt') ?? DateTime(2100))
            .compareTo(b.date('createdAt') ?? DateTime(2100)));

    const templates = [
      ['🛒', 'Spesa'],
      ['🎬', 'Film da vedere'],
      ['✈️', 'Idee viaggio'],
      ['🍽️', 'Ristoranti da provare'],
      ['🎁', 'Idee regalo'],
      ['🏠', 'Cose per casa'],
    ];
    final existing = lists.map((l) => l.str('name')).toSet();
    final missing =
        templates.where((t) => !existing.contains(t[1])).toList();

    Widget templateBlock(String title) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in missing)
                    templateChip(t[0], t[1], () {
                      repo?.add('lists',
                          {'name': t[1], 'icon': t[0], 'items': []});
                    }),
                ],
              ),
            ),
          ],
        );

    if (lists.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmptyCard(
            emoji: '📝',
            title: 'La vostra prima lista',
            text:
                'Spesa, film da vedere, idee per il viaggio: una lista che vedete e spuntate in due.',
          ),
          templateBlock('Parti da un modello'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final l in lists)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: isLocked(l)
                      ? LockedCard(
                          item: l,
                          titleKey: 'name',
                          what: 'Lista',
                          onOpen: () async {
                            if (await unlockItem(
                                context, l, l.str('name'))) {
                              if (!context.mounted) return;
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      ListDetailPage(listId: l.id)));
                            }
                          },
                          onDelete: () async {
                            if (await confirm(context,
                                'Eliminare la lista segreta "${l.str('name')}"?')) {
                              ref.read(repoProvider)?.remove('lists', l.id);
                            }
                          },
                        )
                      : UCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ListDetailPage(listId: l.id))),
                    child: Builder(builder: (context) {
                      final items = _items(l);
                      final done = items.where((i) => i['d'] == true).length;
                      final open =
                          items.where((i) => i['d'] != true).take(2).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                      colors: [
                                        UColors.bgTop,
                                        UColors.bgBottom
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                ),
                                child: Text(l.str('icon', '📝'),
                                    style: const TextStyle(fontSize: 26)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(l.str('name'), style: serif(22)),
                                    const SizedBox(height: 3),
                                    Text(
                                        items.isEmpty
                                            ? 'Vuota: tocca per aggiungere'
                                            : '$done di ${items.length} fatti',
                                        style: const TextStyle(
                                            color: UColors.muted,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: UColors.muted),
                            ],
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: done / items.length,
                                minHeight: 6,
                                backgroundColor: UColors.bgMid,
                                color: UColors.accent,
                              ),
                            ),
                          ],
                          for (final i in open)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('•  ${i['t']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15)),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
        if (missing.isNotEmpty) templateBlock('Altre idee'),
      ],
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
  late bool _secret = widget.item?.flag('locked') ?? false;
  String? _newPin;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final wasSecret = widget.item?.flag('locked') ?? false;
    final sec = <String, dynamic>{
      if (_secret && _newPin != null) ...secretFields(_newPin),
      if (!_secret && wasSecret) ...secretFields(null),
    };
    if (widget.item == null) {
      widget.repo.add('lists',
          {'name': name, 'icon': _icon, 'items': [], ...sec});
    } else {
      widget.repo.update(
          'lists', widget.item!.id, {'name': name, 'icon': _icon, ...sec});
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
        const SizedBox(height: 14),
        SecretSwitch(
          value: _secret,
          what: 'Lista',
          onChanged: (on, pin) => setState(() {
            _secret = on;
            _newPin = pin;
          }),
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
