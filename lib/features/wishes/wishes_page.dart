import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../expenses/expenses_page.dart';
import '../tasks/tasks_page.dart';

class WishesSection extends ConsumerStatefulWidget {
  const WishesSection({super.key});

  @override
  ConsumerState<WishesSection> createState() => _WishesSectionState();
}

class _WishesSectionState extends ConsumerState<WishesSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final wishes = ref.watch(wishesProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser?.uid;
    Item? partner;
    for (final m in members) {
      if (m.id != me) partner = m;
    }
    final partnerName =
        partner == null ? 'Partner' : (firstName(partner.str('name')).isEmpty ? 'Partner' : firstName(partner.str('name')));

    final viewingPartner = _tab == 1 && partner != null;
    final owner = viewingPartner ? partner!.id : me;
    final shown = wishes.where((w) => w.str('owner') == owner).toList()
      ..sort((a, b) => (b.date('createdAt') ?? DateTime(2100))
          .compareTo(a.date('createdAt') ?? DateTime(2100)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('I miei desideri'),
                selected: !viewingPartner,
                onSelected: (_) => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              if (partner != null)
                ChoiceChip(
                  label: Text('Di $partnerName'),
                  selected: viewingPartner,
                  onSelected: (_) => setState(() => _tab = 1),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              viewingPartner
                  ? 'Spunta quello che hai già preso: solo tu vedi la spunta.'
                  : 'Quello che vorresti ricevere: così i regali fanno centro.',
              style: TextStyle(color: UColors.muted),
            ),
          ),
        ),
        if (shown.isEmpty)
          EmptyCard(
            emoji: '🎁',
            title: viewingPartner ? 'Ancora niente' : 'Cosa vorresti?',
            text: viewingPartner
                ? '$partnerName non ha ancora aggiunto desideri.'
                : 'Aggiungi quello che ti piacerebbe ricevere: il partner lo vedrà e i regali faranno centro.',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final w in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: UCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      onTap: (repo == null || viewingPartner)
                          ? null
                          : () => showWishSheet(context, repo, item: w),
                      onLongPress: (repo == null || viewingPartner)
                          ? null
                          : () => itemMenu(context,
                              title: w.str('title'),
                              onEdit: () =>
                                  showWishSheet(context, repo, item: w),
                              onDelete: () => deleteItem(context, repo, 'wishes', w)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                        children: [
                          if (viewingPartner)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => repo?.update('wishes', w.id,
                                    {'gifted': !w.flag('gifted')}),
                                child: Icon(
                                  w.flag('gifted')
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: w.flag('gifted')
                                      ? UColors.accent
                                      : UColors.muted,
                                  size: 28,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.str('title'),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    decoration:
                                        (viewingPartner && w.flag('gifted'))
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                ),
                                if (w.str('note').isNotEmpty)
                                  Text(w.str('note'),
                                      style: TextStyle(
                                          color: UColors.muted)),
                                if (w.str('link').isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: w.str('link')));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Link copiato')));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(w.str('link'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: UColors.lilac,
                                              decoration:
                                                  TextDecoration.underline)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (w.str('price').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(w.str('price'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: UColors.accent)),
                            ),
                        ],
                      ),
                          if (repo != null)
                            WishSavings(
                                wish: w,
                                repo: repo,
                                members: members,
                                isOwner: !viewingPartner),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showWishSheet(BuildContext context, Repo repo, {Item? item}) =>
    showUSheet(context, _WishForm(repo: repo, item: item));

class _WishForm extends StatefulWidget {
  const _WishForm({required this.repo, this.item});
  final Repo repo;
  final Item? item;

  @override
  State<_WishForm> createState() => _WishFormState();
}

class _WishFormState extends State<_WishForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.str('title'));
  late final TextEditingController _price =
      TextEditingController(text: widget.item?.str('price'));
  late final TextEditingController _link =
      TextEditingController(text: widget.item?.str('link'));
  late final TextEditingController _note =
      TextEditingController(text: widget.item?.str('note'));

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final data = <String, dynamic>{
      'title': title,
      'price': _price.text.trim(),
      'link': _link.text.trim(),
      'note': _note.text.trim(),
    };
    if (widget.item == null) {
      widget.repo.add('wishes', {
        ...data,
        'owner': FirebaseAuth.instance.currentUser?.uid,
        'gifted': false,
      });
      Feed.log(widget.repo,
          icon: '⭐', text: 'ha aggiunto un desiderio: $title', tag: 'wishes');
    } else {
      widget.repo.update('wishes', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuovo desiderio' : 'Modifica desiderio',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Cosa desideri?'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _price, decoration: fieldDeco('Prezzo (facoltativo)', hint: 'Es. 49 €')),
        const SizedBox(height: 12),
        TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: fieldDeco('Link (facoltativo)')),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Nota (taglia, colore…)'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (widget.item != null)
              IconButton(
                onPressed: () {
                  deleteItem(context, widget.repo, 'wishes', widget.item!);
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete_outline, color: UColors.danger),
              ),
            Expanded(
              child: FilledButton(
                  style: pillStyle,
                  onPressed: _save,
                  child: const Text('Salva')),
            ),
          ],
        ),
      ],
    );
  }
}


// ------------------------------------------------------------ risparmi

double _num(dynamic v) => v is num ? v.toDouble() : 0;

Map<String, double> _map(Item w, String k) {
  final v = w.data[k];
  if (v is! Map) return {};
  return {for (final e in v.entries) '${e.key}': _num(e.value)};
}

/// Barra "messi da parte" sotto ogni desiderio.
/// saved.{uid}: visibili a tutti · gift.{uid}: di nascosto, il proprietario
/// del desiderio non li vede (per i regali a sorpresa).
class WishSavings extends StatelessWidget {
  const WishSavings(
      {super.key,
      required this.wish,
      required this.repo,
      required this.members,
      required this.isOwner});
  final Item wish;
  final Repo repo;
  final List<Item> members;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final target = parseEuro(wish.str('price')) ?? 0;
    final saved = _map(wish, 'saved');
    final gift = isOwner ? <String, double>{} : _map(wish, 'gift');
    final per = <String, double>{};
    for (final m in [saved, gift]) {
      m.forEach((k, v) => per[k] = (per[k] ?? 0) + v);
    }
    final total = per.values.fold<double>(0, (a, b) => a + b);
    String who(String uid) {
      if (uid == me) return 'Tu';
      final m = memberById(members, uid);
      final n = firstName(m?.str('name'));
      return n.isEmpty ? 'Partner' : n;
    }

    final parts = [
      for (final e in per.entries)
        if (e.value.abs() >= 0.01) '${who(e.key)} ${eur(e.value)}'
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target > 0 || total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: target > 0 ? (total / target).clamp(0.0, 1.0) : 0,
                minHeight: 7,
                backgroundColor: UColors.bgMid,
                color: total >= target && target > 0
                    ? UColors.accent
                    : UColors.rose,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                target > 0
                    ? (total >= target
                        ? '🎉 Obiettivo raggiunto: ${eur(total)}'
                        : '${eur(total)} di ${eur(target)} · mancano ${eur(target - total)}')
                    : 'Messi da parte: ${eur(total)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: UColors.ink)),
            if (parts.isNotEmpty)
              Text(parts.join(' · '),
                  style: TextStyle(color: UColors.muted, fontSize: 12.5)),
          ],
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact),
                onPressed: () => showUSheet(
                    context,
                    _DepositForm(
                        wish: wish, repo: repo, isOwner: isOwner)),
                icon: const Text('🐷'),
                label: const Text('Metti da parte'),
              ),
              if (total != 0)
                TextButton(
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  onPressed: () => showUSheet(
                      context,
                      _DepositHistory(
                          wish: wish,
                          repo: repo,
                          members: members,
                          isOwner: isOwner)),
                  child: const Text('Storico'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepositForm extends StatefulWidget {
  const _DepositForm(
      {required this.wish, required this.repo, required this.isOwner});
  final Item wish;
  final Repo repo;
  final bool isOwner;

  @override
  State<_DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<_DepositForm> {
  final _amount = TextEditingController();
  late bool _hidden = !widget.isOwner;
  bool _withdraw = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final a = parseEuro(_amount.text);
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (a == null || a <= 0 || me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scrivi quanto (es. 35)')));
      return;
    }
    final v = _withdraw ? -a : a;
    final ref = widget.repo.col('wishes').doc(widget.wish.id);
    final b = FirebaseFirestore.instance.batch();
    b.set(ref.collection('deposits').doc(), {
      'amount': v,
      'by': me,
      'hidden': _hidden,
      'at': FieldValue.serverTimestamp(),
    });
    b.update(ref, {'${_hidden ? 'gift' : 'saved'}.$me': FieldValue.increment(v)});
    b.commit();
    if (!_hidden) {
      Feed.log(widget.repo,
          icon: '🐷',
          text: _withdraw
              ? 'ha tolto ${eur(a)} da "${widget.wish.str('title')}"'
              : 'ha messo da parte ${eur(a)} per "${widget.wish.str('title')}"',
          tag: 'savings');
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_withdraw ? 'Togli dai risparmi' : 'Metti da parte',
            style: serif(28)),
        const SizedBox(height: 4),
        Text(widget.wish.str('title'),
            style: TextStyle(color: UColors.muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Aggiungo'),
            selected: !_withdraw,
            onSelected: (_) => setState(() => _withdraw = false),
          ),
          ChoiceChip(
            label: const Text('Tolgo'),
            selected: _withdraw,
            onSelected: (_) => setState(() => _withdraw = true),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDeco('Quanto (€)', hint: '35'),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final v in const [5, 10, 20, 50, 100])
            ActionChip(
              label: Text('$v €'),
              onPressed: () => setState(() => _amount.text = '$v'),
            ),
        ]),
        if (!widget.isOwner)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hidden,
            activeThumbColor: UColors.dark,
            title: const Text('🤫 Di nascosto'),
            subtitle: const Text(
                'Per un regalo a sorpresa: chi ha espresso il desiderio non lo vede'),
            onChanged: (v) => setState(() => _hidden = v),
          ),
        const SizedBox(height: 14),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}

class _DepositHistory extends StatelessWidget {
  const _DepositHistory(
      {required this.wish,
      required this.repo,
      required this.members,
      required this.isOwner});
  final Item wish;
  final Repo repo;
  final List<Item> members;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final ref = repo.col('wishes').doc(wish.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Storico', style: serif(28)),
        const SizedBox(height: 4),
        Text(wish.str('title'), style: TextStyle(color: UColors.muted)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.collection('deposits').orderBy('at', descending: true).snapshots(),
          builder: (context, snap) {
            final docs = (snap.data?.docs ?? [])
                .where((d) => !(isOwner && d.data()['hidden'] == true))
                .toList();
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Ancora niente.',
                    style: TextStyle(color: UColors.muted)),
              );
            }
            return Column(
              children: [
                for (final d in docs)
                  Builder(builder: (context) {
                    final x = d.data();
                    final a = _num(x['amount']);
                    final by = '${x['by'] ?? ''}';
                    final hidden = x['hidden'] == true;
                    final at = x['at'] is Timestamp
                        ? (x['at'] as Timestamp).toDate()
                        : null;
                    final name = by == me
                        ? 'Tu'
                        : (firstName(memberById(members, by)?.str('name'))
                                .isEmpty
                            ? 'Partner'
                            : firstName(memberById(members, by)?.str('name')));
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(hidden ? '🤫' : (a < 0 ? '↩️' : '🐷'),
                          style: const TextStyle(fontSize: 22)),
                      title: Text('$name · ${a < 0 ? 'tolti' : 'messi da parte'} ${eur(a.abs())}'),
                      subtitle: Text(at == null ? 'ora' : fmtDay(at),
                          style: TextStyle(color: UColors.muted)),
                      onLongPress: by != me
                          ? null
                          : () => itemMenu(context,
                              title: '${eur(a)} del ${at == null ? 'oggi' : fmtDay(at)}',
                              onDelete: () {
                                final b = FirebaseFirestore.instance.batch();
                                b.delete(d.reference);
                                b.update(ref, {
                                  '${hidden ? 'gift' : 'saved'}.$by':
                                      FieldValue.increment(-a)
                                });
                                b.commit();
                              }),
                    );
                  }),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text('Tieni premuto su un tuo movimento per eliminarlo.',
            style: TextStyle(color: UColors.muted, fontSize: 12.5)),
      ],
    );
  }
}
