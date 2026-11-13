import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/repo.dart';
import 'theme.dart';
import 'ui.dart';
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

  Future<void> add(String text) => ref.add({
        't': text,
        'd': false,
        'o': DateTime.now().millisecondsSinceEpoch,
        'by': _uid,
      });

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
/// e "fatto da".
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

  void _add(List<Item> current) {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    // niente doppioni: se c'è già (non fatta) non la riaggiungo
    final dup = current.any(
        (i) => !i.flag('d') && i.str('t').toLowerCase() == t.toLowerCase());
    if (dup) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$t" c\'è già')));
      return;
    }
    widget.items.add(t);
    widget.onAdded?.call(t);
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
        final ordered = [...open, ...done];
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
                          hintText: widget.hint, border: InputBorder.none),
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
            const SizedBox(height: 14),
            if (all.isEmpty)
              EmptyHint(widget.emptyIcon, widget.emptyText)
            else
              UCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (final it in ordered)
                      Dismissible(
                        key: ValueKey(it.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.delete_outline,
                              color: UColors.danger),
                        ),
                        onDismissed: (_) => deleteDocWithUndo(context,
                            widget.items.ref.doc(it.id), it.data,
                            label: it.str('t')),
                        child: GestureDetector(
                          onLongPress: () => itemMenu(context,
                              title: it.str('t'),
                              editLabel: 'Rinomina',
                              onEdit: () async {
                                final t = await askText(
                                    context, 'Rinomina', it.str('t'));
                                if (t == null || t.isEmpty) return;
                                widget.items.rename(it, t);
                              },
                              onDelete: () => deleteDocWithUndo(context,
                                  widget.items.ref.doc(it.id), it.data,
                                  label: it.str('t'))),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: UColors.accent,
                            shape: widget.round ? const CircleBorder() : null,
                            value: it.flag('d'),
                            onChanged: (_) => widget.items.toggle(it),
                            title: Text(
                              it.str('t'),
                              style: TextStyle(
                                fontSize: 16.5,
                                decoration: it.flag('d')
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    it.flag('d') ? UColors.muted : UColors.ink,
                              ),
                            ),
                            subtitle: Builder(builder: (_) {
                              final who = it.flag('d')
                                  ? it.str('doneBy')
                                  : it.str('by');
                              if (who.isEmpty) return const SizedBox.shrink();
                              final name = who == me
                                  ? 'te'
                                  : _first(widget.members, who);
                              if (name.isEmpty) return const SizedBox.shrink();
                              return Text(
                                  it.flag('d')
                                      ? 'Fatto da $name'
                                      : 'Aggiunto da $name',
                                  style: TextStyle(
                                      color: UColors.muted, fontSize: 12));
                            }),
                          ),
                        ),
                      ),
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
                      child: const Text('Rimuovi i completati'),
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
