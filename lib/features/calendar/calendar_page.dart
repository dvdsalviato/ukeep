import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/secret.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';

IconData eventIcon(String type) {
  switch (type) {
    case 'birthday':
      return Icons.cake_outlined;
    case 'anniversary':
      return Icons.favorite_border;
    case 'medical':
      return Icons.error_outline;
    default:
      return Icons.event_outlined;
  }
}

/// Prossima data (>= from) in cui cade l'evento, oppure null se è passato.
DateTime? nextOccurrence(Item e, DateTime from) {
  final raw = e.date('date');
  if (raw == null) return null;
  final base = dayOnly(raw);
  final f = dayOnly(from);
  if (e.flag('yearly')) {
    var c = DateTime(f.year, base.month, base.day);
    if (c.isBefore(f)) c = DateTime(f.year + 1, base.month, base.day);
    return c;
  }
  return base.isBefore(f) ? null : base;
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final events = ref.watch(eventsProvider).value ?? [];
    final tasks = ref
            .watch(tasksProvider)
            .value
            ?.where((t) => !t.flag('done') && t.date('due') != null)
            .toList() ??
        [];
    final projects = ref
            .watch(projectsProvider)
            .value
            ?.where((p) =>
                p.str('status') != 'done' &&
                p.date('target') != null &&
                (!isLocked(p) || isMine(p)))
            .toList() ??
        [];
    final today = dayOnly(DateTime.now());

    List<Item> eventsOn(DateTime d) =>
        events.where((e) => nextOccurrence(e, d) == d).toList();
    List<Item> tasksOn(DateTime d) =>
        tasks.where((t) => sameDay(t.date('due')!, d)).toList();
    List<Item> projectsOn(DateTime d) =>
        projects.where((p) => sameDay(p.date('target')!, d)).toList();

    // --- griglia mese
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - 1;
    final daysIn = DateUtils.getDaysInMonth(_month.year, _month.month);
    final rows = ((lead + daysIn) / 7).ceil();

    // --- date speciali e prossimi eventi
    final specials = <MapEntry<DateTime, Item>>[];
    final plans = <MapEntry<DateTime, Item>>[];
    for (final e in events) {
      final n = nextOccurrence(e, today);
      if (n == null) continue;
      (e.flag('special') ? specials : plans).add(MapEntry(n, e));
    }
    specials.sort((a, b) => a.key.compareTo(b.key));
    plans.sort((a, b) => a.key.compareTo(b.key));

    final dayEvents = eventsOn(_selected);
    final dayTasks = tasksOn(_selected);
    final dayProjects = projectsOn(_selected);
    final dayEmpty =
        dayEvents.isEmpty && dayTasks.isEmpty && dayProjects.isEmpty;

    return Scaffold(
      floatingActionButton: repo == null
          ? null
          : pillFab(
              label: 'Nuovo evento',
              onPressed: () => showEventSheet(context, repo, date: _selected)),
      body: ListView(
        controller: tabScroll[3],
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const PageHeader(
              title: 'Calendario',
              subtitle: 'I vostri progetti, eventi e date importanti'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: Text(
                          capitalize(
                              DateFormat('MMMM y', 'it_IT').format(_month)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                          onPressed: () => _shift(1),
                          icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final d in const [
                        'lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'
                      ])
                        Expanded(
                          child: Center(
                            child: Text(d,
                                style: TextStyle(
                                    color: UColors.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          Expanded(
                            child: _cell(
                              r * 7 + c - lead + 1,
                              daysIn,
                              today,
                              eventsOn,
                              tasksOn,
                              projectsOn,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // agenda del giorno scelto
          SectionTitle(capitalize(
              DateFormat('EEEE d MMMM', 'it_IT').format(_selected))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              child: dayEmpty
                  ? Text('Niente in programma per questo giorno.',
                      style: TextStyle(color: UColors.muted))
                  : Column(
                      children: [
                        for (final e in dayEvents)
                          _AgendaRow(
                            icon: eventIcon(e.str('type')),
                            color: UColors.danger,
                            title: e.str('title'),
                            sub: e.str('time'),
                            onTap: repo == null
                                ? null
                                : () => showEventSheet(context, repo, item: e),
                            onLongPress: repo == null
                                ? null
                                : () => itemMenu(context,
                                    title: e.str('title'),
                                    onEdit: () => showEventSheet(
                                        context, repo,
                                        item: e),
                                    onDelete: () =>
                                        deleteItem(context, repo, 'events', e)),
                          ),
                        for (final t in dayTasks)
                          _AgendaRow(
                            icon: Icons.check_circle_outline,
                            color: UColors.accent,
                            title: t.str('title'),
                            sub: 'Attività',
                          ),
                        for (final p in dayProjects)
                          _AgendaRow(
                            icon: Icons.flag_outlined,
                            color: UColors.lilac,
                            title: p.str('title'),
                            sub: 'Scadenza progetto',
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cake_outlined),
                      const SizedBox(width: 10),
                      const Text('Date che non si dimenticano',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('${specials.length}',
                          style: TextStyle(color: UColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final s in specials)
                    InkWell(
                      onTap: repo == null
                          ? null
                          : () => showEventSheet(context, repo, item: s.value),
                      onLongPress: repo == null
                          ? null
                          : () => itemMenu(context,
                              title: s.value.str('title'),
                              onEdit: () =>
                                  showEventSheet(context, repo, item: s.value),
                              onDelete: () =>
                                  deleteItem(context, repo, 'events', s.value)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(eventIcon(s.value.str('type')),
                                color: UColors.danger),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.value.str('title'),
                                      style: const TextStyle(fontSize: 16.5)),
                                  Text(fmtDay(s.key),
                                      style: TextStyle(
                                          color: UColors.muted)),
                                ],
                              ),
                            ),
                            Text(relDay(s.key, far: true),
                                style: TextStyle(
                                    color: UColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: repo == null
                        ? null
                        : () => showEventSheet(context, repo,
                            date: _selected, type: 'birthday'),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi una data',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    style: TextButton.styleFrom(foregroundColor: UColors.ink),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Cosa avete in programma'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              child: plans.isEmpty
                  ? Text('Ancora nessun evento in programma.',
                      style: TextStyle(color: UColors.muted))
                  : Column(
                      children: [
                        for (final p in plans.take(8))
                          _AgendaRow(
                            icon: eventIcon(p.value.str('type')),
                            color: UColors.accent,
                            title: p.value.str('title'),
                            sub: [
                              fmtDay(p.key),
                              if (p.value.str('time').isNotEmpty)
                                p.value.str('time'),
                            ].join(' · '),
                            trailing: relDay(p.key, far: true),
                            onTap: repo == null
                                ? null
                                : () => showEventSheet(context, repo,
                                    item: p.value),
                            onLongPress: repo == null
                                ? null
                                : () => itemMenu(context,
                                    title: p.value.str('title'),
                                    onEdit: () => showEventSheet(
                                        context, repo,
                                        item: p.value),
                                    onDelete: () =>
                                        deleteItem(context, repo, 'events', p.value)),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    int dayNum,
    int daysIn,
    DateTime today,
    List<Item> Function(DateTime) eventsOn,
    List<Item> Function(DateTime) tasksOn,
    List<Item> Function(DateTime) projectsOn,
  ) {
    if (dayNum < 1 || dayNum > daysIn) return const SizedBox(height: 50);
    final d = DateTime(_month.year, _month.month, dayNum);
    final isSel = sameDay(d, _selected);
    final isToday = sameDay(d, today);
    final ev = eventsOn(d);
    final hasSpecial = ev.any((e) => e.flag('special'));
    final hasEvent = ev.any((e) => !e.flag('special'));
    final hasTask = tasksOn(d).isNotEmpty;
    final hasProject = projectsOn(d).isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = d),
      child: SizedBox(
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? UColors.dark : null,
                border: (!isSel && isToday)
                    ? Border.all(color: UColors.dark, width: 1.4)
                    : null,
              ),
              child: Text('$dayNum',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSel || isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSel ? UColors.onDark : UColors.ink)),
            ),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasSpecial) _dot(UColors.danger),
                  if (hasEvent) _dot(UColors.accent),
                  if (hasTask) _dot(UColors.rose),
                  if (hasProject) _dot(UColors.lilac),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.icon,
    required this.color,
    required this.title,
    this.sub,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? sub;
  final String? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16.5)),
                    if (sub != null && sub!.isNotEmpty)
                      Text(sub!,
                          style: TextStyle(color: UColors.muted)),
                  ],
                ),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5)),
            ],
          ),
        ),
      );
}

Future<void> showEventSheet(BuildContext context, Repo repo,
    {Item? item, DateTime? date, String type = 'event'}) {
  return showUSheet(
      context, _EventForm(repo: repo, item: item, date: date, type: type));
}

class _EventForm extends StatefulWidget {
  const _EventForm(
      {required this.repo, this.item, this.date, this.type = 'event'});
  final Repo repo;
  final Item? item;
  final DateTime? date;
  final String type;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.str('title'));
  late DateTime _date =
      widget.item?.date('date') ?? widget.date ?? DateTime.now();
  late String _type = widget.item?.str('type', widget.type) ?? widget.type;
  late String _time = widget.item?.str('time') ?? '';
  late bool _yearly = widget.item != null
      ? widget.item!.flag('yearly')
      : (widget.type == 'birthday' || widget.type == 'anniversary');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
    if (t != null) {
      setState(() => _time =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final data = <String, dynamic>{
      'title': title,
      'date': Timestamp.fromDate(dayOnly(_date)),
      'time': _time,
      'type': _type,
      'special': _type != 'event',
      'yearly': _yearly,
    };
    if (widget.item == null) {
      widget.repo.add('events', data);
    } else {
      widget.repo.update('events', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const types = {
      'event': 'Evento',
      'birthday': 'Compleanno',
      'anniversary': 'Anniversario',
      'medical': 'Visita',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuovo evento' : 'Modifica evento',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Titolo', hint: 'Es. Cena da Chiara'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final e in types.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _type == e.key,
                onSelected: (_) => setState(() {
                  _type = e.key;
                  if (widget.item == null) {
                    _yearly = e.key == 'birthday' || e.key == 'anniversary';
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(DateFormat('d MMM y', 'it_IT').format(_date)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                onLongPress: () => setState(() => _time = ''),
                icon: const Icon(Icons.schedule),
                label: Text(_time.isEmpty ? 'Ora' : _time),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ripeti ogni anno'),
          value: _yearly,
          activeColor: UColors.dark,
          onChanged: (v) => setState(() => _yearly = v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.item != null)
              IconButton(
                onPressed: () {
                  deleteItem(context, widget.repo, 'events', widget.item!);
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete_outline, color: UColors.danger),
              ),
            Expanded(
              child: FilledButton(
                style: pillStyle,
                onPressed: _save,
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
