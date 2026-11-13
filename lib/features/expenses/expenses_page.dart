import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feed.dart';
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

double _numv(dynamic v) => v is num ? v.toDouble() : 0;

/// Quota di [uid] in una mappa {uid: euro}; se manca è "il resto".
double? _part(Item e, String k, String? uid) {
  final m = e.data[k];
  if (m is! Map || m.isEmpty) return null;
  final a = expenseAmount(e);
  if (m.containsKey(uid)) return _numv(m[uid]);
  var others = 0.0;
  m.forEach((key, v) {
    if (key != uid) others += _numv(v);
  });
  return (a - others).clamp(0, a).toDouble();
}

/// Quanto ha pagato [uid].
double paidOf(Item e, String? uid) {
  final v = _part(e, 'paid', uid);
  if (v != null) return v;
  return e.str('paidBy') == uid ? expenseAmount(e) : 0;
}

/// Quanto della spesa è a carico di [uid].
double shareOf(Item e, String? uid) {
  final v = _part(e, 'owe', uid);
  if (v != null) return v;
  final p = ((e.data['otherPct'] as num?) ?? 50).toDouble();
  final a = expenseAmount(e);
  return e.str('paidBy') == uid ? a * (100 - p) / 100 : a * p / 100;
}

/// Positivo: il partner mi deve questi soldi per questa spesa.
double expenseDelta(Item e, String? me) => paidOf(e, me) - shareOf(e, me);

/// Saldo dal mio punto di vista: positivo = il partner mi deve dei soldi.
double expenseBalance(List<Item> expenses, String? me) {
  var b = 0.0;
  for (final e in expenses) {
    b += expenseDelta(e, me);
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
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: pillStyle,
                        onPressed: () => showRefundSheet(context, repo,
                            partnerId: others.first.id,
                            partner: partner,
                            balance: bal),
                        icon: const Text('🤝'),
                        label: const Text('Rimborso'),
                      ),
                      if (bal.abs() >= 0.01)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            foregroundColor: UColors.ink,
                            side: BorderSide(
                                color: UColors.muted.withAlpha(120)),
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                content: Text(bal > 0
                                    ? '$partner ti ha restituito tutto (${eur(bal)})?'
                                    : 'Hai restituito tutto (${eur(-bal)}) a $partner?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('No')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Sì, saldato')),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            addRefund(repo,
                                iGave: bal < 0,
                                amount: bal.abs(),
                                partnerId: others.first.id,
                                partner: partner);
                          },
                          child: const Text('Tutto saldato'),
                        ),
                    ],
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

/// Registra un rimborso. [iGave]: true se sono io a dare i soldi.
void addRefund(Repo repo,
    {required bool iGave,
    required double amount,
    required String partnerId,
    required String partner}) {
  final me = FirebaseAuth.instance.currentUser?.uid;
  final a = (amount * 100).roundToDouble() / 100;
  repo.add('expenses', {
    'title': 'Rimborso',
    'amount': a,
    'paidBy': iGave ? me : partnerId,
    'otherPct': 100,
    'kind': 'settle',
    'icon': '🤝',
    'date': Timestamp.now(),
  });
  Feed.log(repo,
      icon: '🤝',
      text: iGave
          ? 'ha dato ${eur(a)} a $partner'
          : 'ha ricevuto ${eur(a)} da $partner',
      textMe: iGave ? 'Hai dato ${eur(a)} a $partner' : '$partner ti ha dato ${eur(a)}',
      tag: 'expenses');
}

double? parseEuro(String raw) {
  var t = raw.replaceAll('€', '').replaceAll(' ', '').trim();
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

Future<void> showRefundSheet(BuildContext context, Repo repo,
        {required String partnerId,
        required String partner,
        required double balance}) =>
    showUSheet(
        context,
        _RefundForm(
            repo: repo,
            partnerId: partnerId,
            partner: partner,
            balance: balance));

class _RefundForm extends StatefulWidget {
  const _RefundForm(
      {required this.repo,
      required this.partnerId,
      required this.partner,
      required this.balance});
  final Repo repo;
  final String partnerId;
  final String partner;
  final double balance;

  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  late bool _iGave = widget.balance < 0;
  late final _amount = TextEditingController(
      text: widget.balance.abs() < 0.01
          ? ''
          : widget.balance.abs().toStringAsFixed(2).replaceAll('.', ','));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final a = parseEuro(_amount.text);
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scrivi quanto (es. 20)')));
      return;
    }
    addRefund(widget.repo,
        iGave: _iGave,
        amount: a,
        partnerId: widget.partnerId,
        partner: widget.partner);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Rimborso', style: serif(28)),
        const SizedBox(height: 4),
        Text(balanceText(b, widget.partner),
            style: TextStyle(color: UColors.muted)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: Text('${widget.partner} mi ha dato'),
            selected: !_iGave,
            onSelected: (_) => setState(() => _iGave = false),
          ),
          ChoiceChip(
            label: Text('Ho dato a ${widget.partner}'),
            selected: _iGave,
            onSelected: (_) => setState(() => _iGave = true),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDeco('Quanto (€)', hint: '20'),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final v in const [5, 10, 20, 50])
            ActionChip(
              label: Text('$v €'),
              onPressed: () => setState(() => _amount.text = '$v'),
            ),
          if (b.abs() >= 0.01)
            ActionChip(
              label: Text('Tutto (${eur(b.abs())})'),
              onPressed: () => setState(() => _amount.text =
                  b.abs().toStringAsFixed(2).replaceAll('.', ',')),
            ),
        ]),
        const SizedBox(height: 18),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Registra')),
      ],
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
    final settle = e.str('kind') == 'settle';
    final a = expenseAmount(e);
    final myPaid = paidOf(e, me);
    final d = expenseDelta(e, me);
    final who = myPaid >= a - 0.005
        ? 'Pagato da te'
        : (myPaid <= 0.005 ? 'Pagato da $partner' : 'Pagato da entrambi');
    final debt = d.abs() < 0.01
        ? 'nessun debito'
        : (d > 0 ? '$partner ti deve ${eur(d)}' : 'devi ${eur(-d)}');
    final split = settle
        ? (myPaid > 0 ? 'Hai dato a $partner' : '$partner ti ha dato')
        : '$who · $debt';
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
  late DateTime _date = widget.item?.date('date') ?? DateTime.now();
  late String _icon = widget.item?.str('icon', '🛒') ?? '🛒';
  final _back = TextEditingController();

  /// Percentuale pagata dal partner (0 = tutto io, 100 = tutto lui).
  late double _paidP = _initPct(paidOf);

  /// Percentuale della spesa a carico del partner.
  late double _oweP = _initPct(shareOf);

  double _initPct(double Function(Item, String?) f) {
    final it = widget.item;
    if (it == null) return f == paidOf ? 0 : 50;
    final a = expenseAmount(it);
    if (a <= 0) return 50;
    return ((a - f(it, _me)) / a * 100).clamp(0, 100).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _back.dispose();
    super.dispose();
  }

  double get _a => parseEuro(_amount.text) ?? 0;

  void _save() {
    final title = _title.text.trim();
    final amount = parseEuro(_amount.text);
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Scrivi cosa e quanto (es. Cena, 42,50)')));
      return;
    }
    double r(double v) => (v * 100).roundToDouble() / 100;
    final a = r(amount);
    final others = widget.members.where((m) => m.id != _me).toList();
    final pid = others.isEmpty ? null : others.first.id;
    final myPaid = r(a * (100 - _paidP) / 100);
    final myOwe = r(a * (100 - _oweP) / 100);
    final me = _me;
    final data = <String, dynamic>{
      'title': title,
      'amount': a,
      'paid': {
        if (me != null) me: myPaid,
        if (pid != null) pid: r(a - myPaid),
      },
      'owe': {
        if (me != null) me: myOwe,
        if (pid != null) pid: r(a - myOwe),
      },
      // compatibilità con la versione precedente
      'paidBy': _paidP <= 50 ? me : pid,
      'icon': _icon,
      'date': Timestamp.fromDate(_date),
      'kind': widget.item?.str('kind', 'expense') ?? 'expense',
    };
    if (widget.item == null) {
      widget.repo.add('expenses', data);
      Feed.log(widget.repo,
          icon: _icon,
          text: 'ha segnato una spesa: $title (${eur(a)})',
          tag: 'expenses');
      final back = parseEuro(_back.text);
      if (back != null && back > 0 && pid != null) {
        final partnerName = firstName(others.first.str('name'));
        addRefund(widget.repo,
            iGave: myPaid - myOwe < 0,
            amount: back,
            partnerId: pid,
            partner: partnerName.isEmpty ? 'il partner' : partnerName);
      }
    } else {
      widget.repo.update('expenses', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const icons = ['🛒', '🍽️', '🏠', '💡', '⛽', '✈️', '🎉', '🎁', '💊', '📦'];
    final others = widget.members.where((m) => m.id != _me).toList();
    final partner = others.isEmpty
        ? 'Partner'
        : (firstName(others.first.str('name')).isEmpty
            ? 'Partner'
            : firstName(others.first.str('name')));
    final a = _a;
    final myPaid = a * (100 - _paidP) / 100;
    final myOwe = a * (100 - _oweP) / 100;
    final d = myPaid - myOwe;
    final verdict = a <= 0
        ? 'Scrivi l\'importo per vedere chi deve a chi'
        : (d.abs() < 0.01
            ? 'Nessuno deve niente'
            : (d > 0 ? '$partner ti deve ${eur(d)}' : 'Devi ${eur(-d)} a $partner'));

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
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDeco('Quanto in tutto (€)', hint: '42,50'),
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
        const SizedBox(height: 18),
        _SplitPicker(
          title: 'Chi ha pagato',
          partner: partner,
          amount: a,
          value: _paidP,
          middle: 'Metà a testa',
          onChanged: (v) => setState(() => _paidP = v),
        ),
        const SizedBox(height: 14),
        _SplitPicker(
          title: 'Di chi è la spesa',
          subtitle: 'Quanto tocca a ognuno alla fine',
          partner: partner,
          amount: a,
          value: _oweP,
          middle: 'A metà',
          leftLabel: 'Tutta mia',
          rightLabel: 'Tutta di $partner',
          onChanged: (v) => setState(() => _oweP = v),
          extra: [
            ActionChip(
              label: const Text('Nessun rimborso'),
              onPressed: () => setState(() => _oweP = _paidP),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: d.abs() < 0.01 || a <= 0
                ? UColors.bgMid
                : (d > 0 ? UColors.accent : UColors.danger).withAlpha(30),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('👉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(verdict,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: d.abs() < 0.01 || a <= 0
                            ? UColors.ink
                            : (d > 0 ? UColors.accent : UColors.danger))),
              ),
            ],
          ),
        ),
        if (widget.item == null && others.isNotEmpty && d.abs() >= 0.01) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _back,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDeco(
                d > 0
                    ? '$partner ti ha già dato (€, facoltativo)'
                    : 'Hai già dato a $partner (€, facoltativo)',
                hint: 'Es. 20'),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.event, size: 18),
            label: Text(fmtDay(_date)),
            onPressed: () async {
              final now = DateTime.now();
              final dd = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 1),
              );
              if (dd != null) setState(() => _date = dd);
            },
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}

/// Cursore Io ←→ Partner, con la metà al centro e la possibilità di
/// scrivere la cifra in euro.
class _SplitPicker extends StatefulWidget {
  const _SplitPicker({
    required this.title,
    required this.partner,
    required this.amount,
    required this.value,
    required this.onChanged,
    required this.middle,
    this.subtitle,
    this.leftLabel = 'Io',
    this.rightLabel,
    this.extra = const [],
  });
  final String title;
  final String? subtitle;
  final String partner;
  final double amount;

  /// Percentuale "del partner" (0 = tutto mio, 100 = tutto suo).
  final double value;
  final ValueChanged<double> onChanged;
  final String middle;
  final String leftLabel;
  final String? rightLabel;
  final List<Widget> extra;

  @override
  State<_SplitPicker> createState() => _SplitPickerState();
}

class _SplitPickerState extends State<_SplitPicker> {
  bool _euro = false;
  final _mine = TextEditingController();

  @override
  void dispose() {
    _mine.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final a = widget.amount;
    final p = widget.value;
    final mine = a * (100 - p) / 100;
    final his = a - mine;
    final right = widget.rightLabel ?? widget.partner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: false, label: Text('%')),
                ButtonSegment(value: true, label: Text('€')),
              ],
              selected: {_euro},
              onSelectionChanged: (s) => setState(() {
                _euro = s.first;
                if (_euro) _mine.text = a > 0 ? _fmt(mine) : '';
              }),
            ),
          ],
        ),
        if (widget.subtitle != null)
          Text(widget.subtitle!,
              style: TextStyle(color: UColors.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        if (!_euro) ...[
          Slider(
            value: p.clamp(0, 100).toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: p.round() == 50
                ? widget.middle
                : 'Tu ${100 - p.round()}% · ${widget.partner} ${p.round()}%',
            onChanged: widget.onChanged,
          ),
          Row(
            children: [
              Text(widget.leftLabel,
                  style: TextStyle(
                      fontWeight: p <= 0 ? FontWeight.w800 : FontWeight.w500,
                      color: UColors.muted,
                      fontSize: 12.5)),
              const Spacer(),
              Text(widget.middle,
                  style: TextStyle(
                      fontWeight: p.round() == 50
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: UColors.muted,
                      fontSize: 12.5)),
              const Spacer(),
              Text(right,
                  style: TextStyle(
                      fontWeight: p >= 100 ? FontWeight.w800 : FontWeight.w500,
                      color: UColors.muted,
                      fontSize: 12.5)),
            ],
          ),
        ] else
          TextField(
            controller: _mine,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDeco('La tua parte (€)', hint: 'Es. 20'),
            onChanged: (t) {
              final v = parseEuro(t);
              if (v == null || a <= 0) return;
              final m = v.clamp(0, a).toDouble();
              widget.onChanged((a - m) / a * 100);
            },
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (a > 0)
              Text('Tu ${eur(mine)} · ${widget.partner} ${eur(his)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
            ...widget.extra,
          ],
        ),
      ],
    );
  }
}
