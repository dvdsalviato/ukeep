import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/repo.dart';
import 'theme.dart';
import 'ui.dart';
import 'shop.dart';
import 'undo.dart';

/// Voci di una lista / passi di un progetto.
/// Ogni voce è un documento a sé: couples/{id}/{parent}/{pid}/{sub}/{voce}
/// così due telefoni possono modificare insieme senza perdere niente.
/// Campi: t (testo), d (fatto), o (ordine), by, doneBy, doneAt.
class SubItems {
  SubItems(this.repo, this.parent, this.parentId, this.sub);
  final Repo repo;
  final String parent;
  final String parentId;
  final String sub;

  CollectionReference<Map<String, dynamic>> get ref =>
      repo.col(parent).doc(parentId).collection(sub);

  Stream<List<Item>> watch() => ref.snapshots().map((s) {
        final l = s.docs.map((d) => Item(d.id, d.data())).toList();
        l.sort((a, b) {
          final oa = (a.data['o'] as num?) ?? 0;
          final ob = (b.data['o'] as num?) ?? 0;
          final c = oa.compareTo(ob);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
        return l;
      });

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> add(String text, {int q = 1, String? cat}) => ref.add({
        't': text,
        'd': false,
        'o': DateTime.now().millisecondsSinceEpoch,
        'by': _uid,
        if (q != 1) 'q': q,
        if (cat != null) 'cat': cat,
      });

  Future<void> setQty(Item i, int q) =>
      ref.doc(i.id).update({'q': q < 1 ? 1 : q});

  Future<void> setCat(Item i, String cat) =>
      ref.doc(i.id).update({'cat': cat});

  /// Ricorda quante volte avete comprato una cosa (per i suggerimenti).
  Future<void> countFreq(String name) {
    final k = freqKey(name);
    if (k.isEmpty) return Future.value();
    return repo.col(parent).doc(parentId).update({
      'freq.$k.n': FieldValue.increment(1),
      'freq.$k.t': name,
    });
  }

  Future<void> toggle(Item i) {
    final done = !i.flag('d');
    return ref.doc(i.id).update({
      'd': done,
      'doneBy': done ? _uid : null,
      'doneAt': done ? Timestamp.now() : null,
    });
  }

  Future<void> rename(Item i, String t) => ref.doc(i.id).update({'t': t});

  Future<void> clearDone(List<Item> items) {
    final b = FirebaseFirestore.instance.batch();
    for (final i in items.where((i) => i.flag('d'))) {
      b.delete(ref.doc(i.id));
    }
    return b.commit();
  }

  static final Set<String> _migrated = {};

  /// Sposta le voci dal vecchio formato (array nel documento) alle voci
  /// separate. Gli id sono fissi (ricavati dal testo), così anche se entrambi
  /// i telefoni lo fanno insieme non si creano doppioni.
  Future<void> migrate(Item parentItem, String field) async {
    final raw = parentItem.data[field];
    if (raw is! List) return;
    final key = '$parent/$parentId';
    if (_migrated.contains(key)) return;
    _migrated.add(key);
    final arr = parentItem.steps(field);
    final base =
        (parentItem.date('createdAt') ?? DateTime(2025)).millisecondsSinceEpoch;
    final b = FirebaseFirestore.instance.batch();
    for (var i = 0; i < arr.length; i++) {
      final t = '${arr[i]['t'] ?? ''}'.trim();
      if (t.isEmpty) continue;
      b.set(
          ref.doc('m${_hash(t.toLowerCase())}'),
          {
            't': t,
            'd': arr[i]['d'] == true,
            'o': base + i,
            'by': parentItem.data['by'],
          },
          SetOptions(merge: true));
    }
    b.update(repo.col(parent).doc(parentId), {field: FieldValue.delete()});
    try {
      await b.commit();
    } catch (_) {
      _migrated.remove(key);
    }
  }

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }
}

/// Costruisce un widget con le voci aggiornate in tempo reale.
class SubItemsBuilder extends StatelessWidget {
  const SubItemsBuilder(
      {super.key,
      required this.items,
      required this.parentItem,
      required this.legacyField,
      required this.builder});
  final SubItems items;
  final Item parentItem;
  final String legacyField;
  final Widget Function(BuildContext context, List<Item> items) builder;

  @override
  Widget build(BuildContext context) {
    items.migrate(parentItem, legacyField);
    return StreamBuilder<List<Item>>(
      stream: items.watch(),
      builder: (context, snap) => builder(context, snap.data ?? const []),
    );
  }
}

String _first(List<Item> members, String? uid) {
  if (uid == null) return '';
  for (final m in members) {
    if (m.id == uid) {
      final n = m.str('name').trim();
      return n.isEmpty ? '' : n.split(' ').first;
    }
  }
  return '';
}

/// Riga per aggiungere + elenco con spunta, scorrimento, pressione lunga
/// e "fatto da". In modalità spesa: quantità, reparti e suggerimenti.
class SubItemsPanel extends StatefulWidget {
  const SubItemsPanel({
    super.key,
    required this.items,
    required this.parentItem,
    required this.legacyField,
    required this.members,
    required this.hint,
    required this.emptyIcon,
    required this.emptyText,
    this.round = true,
    this.shop = false,
    this.big = false,
    this.onAdded,
  });
  final SubItems items;
  final Item parentItem;
  final String legacyField;
  final List<Item> members;
  final String hint;
  final IconData emptyIcon;
  final String emptyText;
  final bool round;
  final bool shop;
  final bool big;
  final void Function(String text)? onAdded;

  @override
  State<SubItemsPanel> createState() => _SubItemsPanelState();
}

class _SubItemsPanelState extends State<SubItemsPanel> {
  final _input = TextEditingController();
  late Stream<List<Item>> _stream = widget.items.watch();

  @override
  void didUpdateWidget(covariant SubItemsPanel old) {
    super.didUpdateWidget(old);
    if (old.items.parentId != widget.items.parentId) {
      _stream = widget.items.watch();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  int _q(Item i) => ((i.data['q'] as num?) ?? 1).toInt();

  void _add(List<Item> current, [String? raw]) {
    final text = (raw ?? _input.text).trim();
    if (text.isEmpty) return;
    if (raw == null) _input.clear();
    var q = 1;
    var t = text;
    if (widget.shop) {
      final r = parseQty(text);
      q = r.$1;
      t = r.$2;
    }
    // niente doppioni: se c'è già (non fatta) aumento la quantità
    for (final i in current) {
      if (!i.flag('d') && i.str('t').toLowerCase() == t.toLowerCase()) {
        if (widget.shop) {
          widget.items.setQty(i, _q(i) + q);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"$t" c\'era già: ora ×${_q(i) + q}')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('"$t" c\'è già')));
        }
        return;
      }
    }
    if (widget.shop) {
      widget.items.add(t, q: q, cat: guessDept(t).key);
      widget.items.countFreq(t);
    } else {
      widget.items.add(t);
    }
    widget.onAdded?.call(q > 1 ? '$t ×$q' : t);
  }

  List<String> _suggestions(List<Item> all) {
    final f = widget.parentItem.data['freq'];
    if (f is! Map) return [];
    final open = all
        .where((i) => !i.flag('d'))
        .map((i) => i.str('t').toLowerCase())
        .toSet();
    final list = <MapEntry<String, int>>[];
    f.forEach((k, v) {
      if (v is Map) {
        final t = '${v['t'] ?? ''}';
        final n = ((v['n'] as num?) ?? 0).toInt();
        if (t.isNotEmpty && !open.contains(t.toLowerCase())) {
          list.add(MapEntry(t, n));
        }
      }
    });
    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(10).map((e) => e.key).toList();
  }

  Future<void> _pickDept(Item it) async {
    final key = await showUSheet<String>(
      context,
      Builder(
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reparto di "${it.str('t')}"', style: serif(24)),
            const SizedBox(height: 8),
            for (final d in [...depts, otherDept])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(d.icon, style: const TextStyle(fontSize: 22)),
                title: Text(d.name),
                trailing: it.str('cat') == d.key
                    ? Icon(Icons.check, color: UColors.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, d.key),
              ),
          ],
        ),
      ),
    );
    if (key != null) widget.items.setCat(it, key);
  }

  Widget _row(Item it, String? me) {
    final big = widget.big;
    final done = it.flag('d');
    final q = _q(it);
    return Dismissible(
      key: ValueKey(it.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        child: Icon(Icons.delete_outline, color: UColors.danger),
      ),
      onDismissed: (_) => deleteDocWithUndo(
          context, widget.items.ref.doc(it.id), it.data,
          label: it.str('t')),
      child: GestureDetector(
        onLongPress: () => itemMenu(context,
            title: it.str('t'),
            editLabel: 'Rinomina',
            onOpen: widget.shop ? () => _pickDept(it) : null,
            openLabel: 'Cambia reparto',
            onEdit: () async {
              final t = await askText(context, 'Rinomina', it.str('t'));
              if (t == null || t.isEmpty) return;
              widget.items.rename(it, t);
            },
            onDelete: () => deleteDocWithUndo(
                context, widget.items.ref.doc(it.id), it.data,
                label: it.str('t'))),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: UColors.accent,
          visualDensity: big ? VisualDensity.comfortable : null,
          shape: widget.round ? const CircleBorder() : null,
          value: done,
          onChanged: (_) => widget.items.toggle(it),
          title: Text(
            q > 1 ? '${it.str('t')}  ×$q' : it.str('t'),
            style: TextStyle(
              fontSize: big ? 22 : 16.5,
              fontWeight: big ? FontWeight.w600 : null,
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? UColors.muted : UColors.ink,
            ),
          ),
          secondary: widget.shop && !done && !big
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.remove_circle_outline,
                          size: 20, color: UColors.muted),
                      onPressed:
                          q > 1 ? () => widget.items.setQty(it, q - 1) : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.add_circle_outline,
                          size: 20, color: UColors.muted),
                      onPressed: () => widget.items.setQty(it, q + 1),
                    ),
                  ],
                )
              : null,
          subtitle: big
              ? null
              : Builder(builder: (_) {
                  final who = done ? it.str('doneBy') : it.str('by');
                  if (who.isEmpty) return const SizedBox.shrink();
                  final name =
                      who == me ? 'te' : _first(widget.members, who);
                  if (name.isEmpty) return const SizedBox.shrink();
                  return Text(
                      done ? 'Fatto da $name' : 'Aggiunto da $name',
                      style: TextStyle(color: UColors.muted, fontSize: 12));
                }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.items.migrate(widget.parentItem, widget.legacyField);
    final me = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<Item>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Item>[];
        final open = all.where((i) => !i.flag('d')).toList();
        final done = all.where((i) => i.flag('d')).toList();
        final sugg = widget.shop && !widget.big ? _suggestions(all) : <String>[];

        // gruppi per reparto (solo spesa)
        final groups = <Dept, List<Item>>{};
        if (widget.shop) {
          for (final d in [...depts, otherDept]) {
            final g = open
                .where((i) => (i.str('cat').isEmpty
                        ? guessDept(i.str('t')).key
                        : i.str('cat')) ==
                    d.key)
                .toList();
            if (g.isNotEmpty) groups[d] = g;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _add(all),
                      decoration: InputDecoration(
                          hintText: widget.shop
                              ? 'Aggiungi… (es. 2 latte)'
                              : widget.hint,
                          border: InputBorder.none),
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: UColors.dark,
                        foregroundColor: UColors.onDark),
                    onPressed: () => _add(all),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            if (sugg.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final t in sugg)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(t),
                          backgroundColor: UColors.card,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () => _add(all, t),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (all.isEmpty)
              EmptyHint(widget.emptyIcon, widget.emptyText)
            else if (widget.shop) ...[
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Text('${g.key.icon}  ${g.key.name}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: widget.big ? 18 : 14,
                          color: UColors.muted)),
                ),
                UCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                      children: [for (final it in g.value) _row(it, me)]),
                ),
                const SizedBox(height: 10),
              ],
              if (done.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Text('🛒  Nel carrello',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: widget.big ? 18 : 14,
                          color: UColors.muted)),
                ),
                UCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                      children: [for (final it in done) _row(it, me)]),
                ),
              ],
            ] else
              UCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (final it in [...open, ...done]) _row(it, me),
                  ],
                ),
              ),
            if (done.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Text('${done.length} di ${all.length} fatti',
                        style: TextStyle(color: UColors.muted)),
                    TextButton(
                      onPressed: () => widget.items.clearDone(all),
                      child: Text(widget.shop
                          ? 'Svuota il carrello'
                          : 'Rimuovi i completati'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
