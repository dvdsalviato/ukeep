import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed.dart';
import '../../core/secret.dart';
import '../../core/sub_items.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../expenses/expenses_page.dart';
import '../polls/polls_page.dart';
import '../projects/projects_page.dart';
import '../wishes/wishes_page.dart';

/// Scheda "Liste": Liste, Desideri, Progetti, Spese e Sondaggi.
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
          } else if (seg == 2) {
            label = 'Nuovo progetto';
            add = () => showProjectSheet(context, repo);
          } else if (seg == 3) {
            label = 'Nuova spesa';
            final members = ref.read(membersProvider).value ?? [];
            final all = ref.read(expensesProvider).value ?? [];
            final budget = ((ref.read(coupleDocProvider).value?['budget']
                        as num?) ??
                    0)
                .toDouble();
            add = () => showExpenseSheet(context, repo, members,
                all: all, budget: budget);
          } else {
            label = 'Nuovo sondaggio';
            add = () => showPollSheet(context, repo);
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
              _Seg(value: seg, onChanged: (v) => listsSegment.value = v),
              const SizedBox(height: 12),
              if (seg == 0) const ListsSection(),
              if (seg == 1) const WishesSection(),
              if (seg == 2) const ProjectsSection(),
              if (seg == 3) const ExpensesSection(),
              if (seg == 4) const PollsSection(),
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
    const labels = ['📝 Liste', '⭐ Desideri', '🎯 Progetti', '💸 Spese', '🗳️ Sondaggi'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: value == i ? UColors.dark : UColors.card,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: value == i ? UColors.onDark : UColors.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ListsSection extends ConsumerWidget {
  const ListsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    if (repo == null) return const SizedBox.shrink();
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
                      repo.add('lists', {'name': t[1], 'icon': t[0]});
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
                          onDelete: () => deleteItem(context, repo, 'lists', l,
                              label: l.str('name')),
                        )
                      : UCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ListDetailPage(listId: l.id))),
                    onLongPress: () => itemMenu(context,
                            title: l.str('name'),
                            onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ListDetailPage(listId: l.id))),
                            onEdit: () =>
                                showListSheet(context, repo, item: l),
                            onDelete: () => deleteItem(
                                context, repo, 'lists', l,
                                label: l.str('name'))),
                    child: SubItemsBuilder(
                        items: SubItems(repo, 'lists', l.id, 'items'),
                        parentItem: l,
                        legacyField: 'items',
                        builder: (context, subs) {
                      final items = [
                        for (final x in subs) {'t': x.str('t'), 'd': x.flag('d')}
                      ];
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
                                  gradient: LinearGradient(
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
                                        style: TextStyle(
                                            color: UColors.muted,
                                            fontSize: 13.5)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
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
  late bool _shop =
      widget.item == null ? true : isShopList(widget.item!);
  bool _shopTouched = false;

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
    final shop = _shopTouched ? _shop : (_icon == '🛒' || _shop && widget.item != null);
    if (widget.item == null) {
      widget.repo.add(
          'lists', {'name': name, 'icon': _icon, 'shop': shop, ...sec});
    } else {
      widget.repo.update('lists', widget.item!.id,
          {'name': name, 'icon': _icon, 'shop': shop, ...sec});
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
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _shopTouched ? _shop : (_icon == '🛒' || (widget.item != null && _shop)),
          activeThumbColor: UColors.dark,
          title: const Text('🛒 Lista della spesa'),
          subtitle: const Text('Reparti, quantità (es. "2 latte") e suggerimenti'),
          onChanged: (v) => setState(() {
            _shop = v;
            _shopTouched = true;
          }),
        ),
        const SizedBox(height: 8),
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

bool isShopList(Item l) => l.data['shop'] is bool
    ? l.flag('shop')
    : (l.str('icon') == '🛒' || l.str('name').toLowerCase().contains('spesa'));

class ListDetailPage extends ConsumerStatefulWidget {
  const ListDetailPage({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends ConsumerState<ListDetailPage> {
  bool _big = false;

  String get listId => widget.listId;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final lists = ref.watch(listsProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    Item? found;
    for (final l in lists) {
      if (l.id == listId) found = l;
    }
    if (found == null || repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final Item list = found;
    final subs = SubItems(repo, 'lists', list.id, 'items');
    final shop = isShopList(list);

    return Scaffold(
      appBar: AppBar(
        title: Text('${list.str('icon', '📝')}  ${list.str('name')}'),
        actions: [
          if (shop)
            IconButton(
              tooltip: _big ? 'Vista normale' : 'Modalità supermercato',
              onPressed: () => setState(() => _big = !_big),
              icon: Icon(_big ? Icons.zoom_in_map : Icons.storefront_outlined),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                showListSheet(context, repo, item: list);
              } else if (v == 'delete') {
                deleteItem(context, repo, 'lists', list,
                    label: list.str('name'));
                Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Modifica')),
              PopupMenuItem(value: 'delete', child: Text('Elimina lista')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + bottomInset(context)),
        children: [
          if (_big)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('🛒 Modalità supermercato: tocca per mettere nel carrello',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: UColors.muted)),
            ),
          SubItemsPanel(
            items: subs,
            parentItem: list,
            legacyField: 'items',
            members: members,
            shop: shop,
            big: _big,
            hint: 'Aggiungi un elemento…',
            emptyIcon: Icons.playlist_add,
            emptyText: 'La lista è vuota. Scrivi qui sopra il primo elemento.',
            onAdded: isLocked(list)
                ? null
                : (t) => Feed.log(repo,
                      icon: list.str('icon', '📝'),
                      text: 'ha aggiunto "$t" a ${list.str('name')}',
                      tag: 'list-${list.id}',
                    ),
          ),
        ],
      ),
    );
  }
}
