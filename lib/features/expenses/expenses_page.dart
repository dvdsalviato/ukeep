import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../tasks/tasks_page.dart';

/// Spese condivise.
/// expenses/{id}: title, amount (euro), paidBy (uid), otherPct (quanto deve
/// l'altro, 0-100), date, icon, kind ('expense' | 'settle').
final _eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
String eur(num v) => _eur.format(v);

double expenseAmount(Item e) => ((e.data['amount'] as num?) ?? 0).toDouble();

/// Saldo dal mio punto di vista: positivo = il partner mi deve dei soldi.
double expenseBalance(List<Item> expenses, String? me) {
  var b = 0.0;
  for (final e in expenses) {
    final owed = expenseAmount(e) * (((e.data['otherPct'] as num?) ?? 50) / 100);
    b += e.str('paidBy') == me ? owed : -owed;
  }
  return (b * 100).roundToDouble() / 100;
}

String balanceText(double b, String partner) {
  if (b.abs() < 0.01) return 'Siete pari 🎉';
  return b > 0 ? '$partner ti deve ${eur(b)}' : 'Devi ${eur(-b)} a $partner';
}

class ExpensesSection extends ConsumerWidget {
  const ExpensesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    if (repo == null) return const SizedBox.shrink();
    final members = ref.watch(membersProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser?.uid;
    final all = [...(ref.watch(expensesProvider).value ?? <Item>[])]
      ..sort((a, b) => (b.date('date') ?? DateTime(2000))
          .compareTo(a.date('date') ?? DateTime(2000)));
    final others = members.where((m) => m.id != me).toList();
    final partner = others.isEmpty
        ? 'il partner'
        : (firstName(others.first.str('name')).isEmpty
            ? 'il partner'
            : firstName(others.first.str('name')));
    final bal = expenseBalance(all, me);
    final now = DateTime.now();
    final month = all
        .where((e) =>
            e.str('kind') != 'settle' &&
            e.date('date') != null &&
            e.date('date')!.year == now.year &&
            e.date('date')!.month == now.month)
        .fold<double>(0, (s, e) => s + expenseAmount(e));

    // raggruppa per mese
    final groups = <String, List<Item>>{};
    for (final e in all) {
      final d = e.date('date') ?? now;
      final k = capitalize(DateFormat('MMMM y', 'it_IT').format(d));
      groups.putIfAbsent(k, () => []).add(e);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo', style: TextStyle(color: UColors.muted)),
                const SizedBox(height: 4),
                Text(balanceText(bal, partner),
                    style: serif(28,
                        color: bal.abs() < 0.01
                            ? UColors.ink
                            : (bal > 0 ? UColors.accent : UColors.danger))),
                const SizedBox(height: 6),
                Text('Spese di questo mese: ${eur(month)}',
                    style: TextStyle(color: UColors.muted)),
                if (bal.abs() >= 0.01 && others.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: pillStyle,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: Text(bal > 0
                              ? '$partner ti ha restituito ${eur(bal)}?'
                              : 'Hai restituito ${eur(-bal)} a $partner?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('No')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sì, saldato')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      repo.add('expenses', {
                        'title': 'Saldo',
                        'amount': bal.abs(),
                        'paidBy': bal > 0 ? others.first.id : me,
                        'otherPct': 100,
                        'kind': 'settle',
                        'icon': '🤝',
                        'date': Timestamp.now(),
                      });
                    },
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Segna come saldato'),
                  ),
                ],
              ],
            ),
          ),
          if (all.isEmpty) ...[
            const SizedBox(height: 14),
            const EmptyCard(
              emoji: '💸',
              title: 'Spese condivise',
              text:
                  'Segnate chi ha pagato cosa: Ukeep fa i conti e vi dice chi deve quanto a chi.',
            ),
          ],
          for (final g in groups.entries) ...[
            SectionTitle(g.key),
            UCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final e in g.value)
                    _ExpenseRow(
                      e: e,
                      me: me,
                      partner: partner,
                      onTap: () =>
                          showExpenseSheet(context, repo, members, item: e),
                      onLongPress: () => itemMenu(context,
                          title: e.str('title'),
                          onEdit: () => showExpenseSheet(
                              context, repo, members,
                              item: e),
                          onDelete: () =>
                              deleteItem(context, repo, 'expenses', e)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow(
      {required this.e,
      required this.me,
      required this.partner,
      required this.onTap,
      required this.onLongPress});
  final Item e;
  final String? me;
  final String partner;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = e.str('paidBy') == me;
    final pct = ((e.data['otherPct'] as num?) ?? 50).toInt();
    final settle = e.str('kind') == 'settle';
    final who = mine ? 'Pagato da te' : 'Pagato da $partner';
    final split = settle
        ? (mine ? 'Hai restituito a $partner' : '$partner ti ha restituito')
        : (pct == 50
            ? '$who · a metà'
            : (pct == 100
                ? '$who · tutto per ${mine ? partner : 'te'}'
                : (pct == 0 ? '$who · personale' : '$who · $pct% all\'altro')));
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Text(e.str('icon', '💸'), style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.str('title'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                      '${e.date('date') == null ? '' : '${fmtDay(e.date('date')!)} · '}$split',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: UColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Text(eur(expenseAmount(e)),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: settle ? UColors.muted : UColors.ink)),
          ],
        ),
      ),
    );
  }
}

Future<void> showExpenseSheet(
        BuildContext context, Repo repo, List<Item> members,
        {Item? item}) =>
    showUSheet(
        context, _ExpenseForm(repo: repo, members: members, item: item));

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.repo, required this.members, this.item});
  final Repo repo;
  final List<Item> members;
  final Item? item;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final _title = TextEditingController(text: widget.item?.str('title'));
  late final _amount = TextEditingController(
      text: widget.item == null
          ? ''
          : expenseAmount(widget.item!).toStringAsFixed(2).replaceAll('.', ','));
  final String? _me = FirebaseAuth.instance.currentUser?.uid;
  late String? _paidBy = widget.item?.str('paidBy') ?? _me;
  late int _pct = ((widget.item?.data['otherPct'] as num?) ?? 50).toInt();
  late DateTime _date = widget.item?.date('date') ?? DateTime.now();
  late String _icon = widget.item?.str('icon', '🛒') ?? '🛒';

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final amount =
        double.tryParse(_amount.text.trim().replaceAll('€', '').replaceAll(',', '.'));
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Scrivi cosa e quanto (es. Cena, 42,50)')));
      return;
    }
    final data = <String, dynamic>{
      'title': title,
      'amount': (amount * 100).roundToDouble() / 100,
      'paidBy': _paidBy,
      'otherPct': _pct,
      'icon': _icon,
      'date': Timestamp.fromDate(_date),
      'kind': widget.item?.str('kind', 'expense') ?? 'expense',
    };
    if (widget.item == null) {
      widget.repo.add('expenses', data);
      Push.instance.toPartner(
        title: '$_icon Nuova spesa: ${eur(amount)}',
        body: '${Push.instance.myName} ha segnato "$title"',
        tag: 'expenses',
      );
    } else {
      widget.repo.update('expenses', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const icons = ['🛒', '🍽️', '🏠', '💡', '⛽', '✈️', '🎉', '🎁', '💊', '📦'];
    final others = widget.members.where((m) => m.id != _me).toList();
    final partnerId = others.isEmpty ? null : others.first.id;
    final partner = others.isEmpty
        ? 'Partner'
        : (firstName(others.first.str('name')).isEmpty
            ? 'Partner'
            : firstName(others.first.str('name')));
    final payerIsMe = _paidBy == _me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuova spesa' : 'Modifica spesa',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Cosa', hint: 'Es. Spesa, cena, bolletta'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDeco('Quanto (€)', hint: '42,50'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in icons)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _icon == i
                        ? UColors.rose.withAlpha(100)
                        : UColors.bgMid,
                    borderRadius: BorderRadius.circular(14),
                    border: _icon == i
                        ? Border.all(color: UColors.dark, width: 1.4)
                        : null,
                  ),
                  child: Text(i, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Chi ha pagato',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Io'),
            selected: payerIsMe,
            onSelected: (_) => setState(() => _paidBy = _me),
          ),
          if (partnerId != null)
            ChoiceChip(
              label: Text(partner),
              selected: _paidBy == partnerId,
              onSelected: (_) => setState(() => _paidBy = partnerId),
            ),
        ]),
        const SizedBox(height: 16),
        const Text('Come si divide',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(
            label: const Text('A metà'),
            selected: _pct == 50,
            onSelected: (_) => setState(() => _pct = 50),
          ),
          ChoiceChip(
            label: Text(payerIsMe ? 'Tutto per $partner' : 'Tutto per me'),
            selected: _pct == 100,
            onSelected: (_) => setState(() => _pct = 100),
          ),
          ChoiceChip(
            label: const Text('Personale'),
            selected: _pct == 0,
            onSelected: (_) => setState(() => _pct = 0),
          ),
        ]),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _pct.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_pct%',
                onChanged: (v) => setState(() => _pct = v.round()),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                  payerIsMe ? '$partner paga il $_pct%' : 'Tu paghi il $_pct%',
                  style: TextStyle(color: UColors.muted, fontSize: 12.5)),
            ),
          ],
        ),
        ActionChip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text(fmtDay(_date)),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(now.year - 3),
              lastDate: DateTime(now.year + 1),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        const SizedBox(height: 18),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
