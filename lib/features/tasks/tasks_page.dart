import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/attach.dart';
import '../../core/feed.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';

String firstName(String? full) =>
    (full ?? '').trim().isEmpty ? '' : full!.trim().split(' ').first;

Item? memberById(List<Item> members, String? uid) {
  if (uid == null) return null;
  for (final m in members) {
    if (m.id == uid) return m;
  }
  return null;
}

/// Ripetizioni delle attività.
const repeatLabels = <String, String>{
  '': 'Mai',
  'd': 'Ogni giorno',
  'w': 'Ogni settimana',
  '2w': 'Ogni 2 settimane',
  'm': 'Ogni mese',
  'y': 'Ogni anno',
};

DateTime nextRepeat(DateTime from, String r) {
  final d = dayOnly(from);
  switch (r) {
    case 'd':
      return d.add(const Duration(days: 1));
    case 'w':
      return d.add(const Duration(days: 7));
    case '2w':
      return d.add(const Duration(days: 14));
    case 'm':
      final last = DateTime(d.year, d.month + 2, 0).day;
      return DateTime(d.year, d.month + 1, d.day > last ? last : d.day);
    case 'y':
      final last = DateTime(d.year + 1, d.month + 1, 0).day;
      return DateTime(d.year + 1, d.month, d.day > last ? last : d.day);
  }
  return d;
}

/// Spunta un'attività. Se si ripete: salva lo storico e sposta la scadenza
/// alla prossima volta.
Future<void> toggleTask(Repo repo, Item t) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final done = !t.flag('done');
  final r = t.str('repeat');
  if (done && r.isNotEmpty) {
    final today = dayOnly(DateTime.now());
    var next = nextRepeat(t.date('due') ?? today, r);
    while (!next.isAfter(today)) {
      next = nextRepeat(next, r);
    }
    Feed.log(repo,
        icon: '🎉', text: 'ha completato "${t.str('title')}"', tag: 'done');
    await Future.wait([
      repo.add('tasks', {
        'title': t.str('title'),
        'note': t.str('note'),
        'assignee': t.data['assignee'],
        'due': t.data['due'],
        'time': t.str('time'),
        'done': true,
        'doneAt': Timestamp.now(),
        'doneBy': uid,
        'fromRepeat': t.id,
      }),
      repo.update('tasks', t.id, {'due': Timestamp.fromDate(next)}),
    ]);
    return;
  }
  if (done) {
    Feed.log(repo,
        icon: '🎉', text: 'ha completato "${t.str('title')}"', tag: 'done');
  }
  await repo.update('tasks', t.id, {
    'done': done,
    'doneAt': done ? Timestamp.now() : null,
    'doneBy': done ? uid : null,
  });
}

/// Scaduta: con orario dopo quell'ora, senza orario dal giorno dopo.
bool taskOverdue(Item t) {
  final d = t.date('due');
  if (d == null || t.flag('done')) return false;
  final base = dayOnly(d);
  final time = t.str('time');
  if (time.contains(':')) {
    final p = time.split(':');
    final at = DateTime(base.year, base.month, base.day,
        int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
    return at.isBefore(DateTime.now());
  }
  return base.isBefore(dayOnly(DateTime.now()));
}

int compareOpen(Item a, Item b) {
  final da = a.date('due');
  final db = b.date('due');
  if (da != null && db != null) return da.compareTo(db);
  if (da != null) return -1;
  if (db != null) return 1;
  final ca = a.date('createdAt');
  final cb = b.date('createdAt');
  if (ca != null && cb != null) return ca.compareTo(cb);
  return 0;
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.members,
    required this.onToggle,
    this.onTap,
    this.onLongPress,
    this.compact = false,
  });
  final Item task;
  final List<Item> members;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = task.flag('done');
    final due = task.date('due');
    final overdue = taskOverdue(task);
    final assignee = task.data['assignee'] as String?;
    final who = memberById(members, assignee);
    final meUid = FirebaseAuth.instance.currentUser?.uid;
    final forLabel = assignee == null
        ? 'Per entrambi'
        : (assignee == meUid
            ? 'Per me'
            : 'Per ${firstName(who?.str('name')).isEmpty ? 'il partner' : firstName(who?.str('name'))}');
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: overdue ? UColors.danger.withAlpha(22) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 10, horizontal: overdue ? 8 : 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? UColors.accent : Colors.transparent,
                  border: Border.all(
                      color: done ? UColors.accent : UColors.muted.withAlpha(160),
                      width: 1.6),
                ),
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.str('photoId').isEmpty
                        ? task.str('title')
                        : '${task.str('title')} 📎',
                    style: TextStyle(
                      fontSize: 16.5,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? UColors.muted : UColors.ink,
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                          [
                            if (done && task.str('doneBy').isNotEmpty)
                              task.str('doneBy') == meUid
                                  ? 'Fatto da te'
                                  : 'Fatto da ${firstName(memberById(members, task.str('doneBy'))?.str('name')).isEmpty ? 'il partner' : firstName(memberById(members, task.str('doneBy'))?.str('name'))}'
                            else
                              forLabel,
                            if (task.str('repeat').isNotEmpty)
                              '🔁 ${repeatLabels[task.str('repeat')] ?? ''}',
                            if (task.str('note').isNotEmpty) task.str('note'),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: UColors.muted, fontSize: 13.5)),
                    ),
                ],
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: assignee == null
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final m in members.take(2))
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: UAvatar.member(m, size: 24),
                          ),
                      ])
                    : UAvatar.member(who, size: 24),
              ),
            if (due != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  task.str('time').isEmpty
                      ? relDay(due)
                      : '${relDay(due)} ${task.str('time')}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: overdue ? UColors.danger : UColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  int _filter = 0; // 0 tutte, 1 mie, 2 fatte

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final all = ref.watch(tasksProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser?.uid;

    final open = all.where((t) => !t.flag('done')).toList()..sort(compareOpen);
    final done = all.where((t) => t.flag('done')).toList()
      ..sort((a, b) => (b.date('doneAt') ?? DateTime(2000))
          .compareTo(a.date('doneAt') ?? DateTime(2000)));

    List<Item> shown;
    if (_filter == 1) {
      shown = open
          .where((t) =>
              t.data['assignee'] == null || t.data['assignee'] == me)
          .toList();
    } else if (_filter == 2) {
      shown = done;
    } else {
      shown = open;
    }

    return Scaffold(
      floatingActionButton: repo == null
          ? null
          : pillFab(
              label: 'Nuova attività',
              onPressed: () => showTaskSheet(context, repo, members)),
      body: ListView(
        controller: tabScroll[1],
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          PageHeader(
              title: 'Attività',
              subtitle: open.isEmpty
                  ? 'Tutto fatto, bravi!'
                  : '${open.length} da fare insieme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final e in const {
                  0: 'Da fare',
                  1: 'Le mie',
                  2: 'Fatte',
                }.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                    selectedColor: UColors.dark,
                    labelStyle: TextStyle(
                        color:
                            _filter == e.key ? UColors.onDark : UColors.ink,
                        fontWeight: FontWeight.w600),
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    backgroundColor: UColors.card,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            EmptyHint(
                _filter == 2 ? Icons.hourglass_empty : Icons.celebration_outlined,
                _filter == 2
                    ? 'Ancora nessuna attività completata.'
                    : 'Nessuna attività. Aggiungine una con il tasto in basso.')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      Dismissible(
                        key: ValueKey(shown[i].id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.delete_outline,
                              color: UColors.danger),
                        ),
                        onDismissed: (_) {
                          if (repo != null) {
                            deleteItem(context, repo, 'tasks', shown[i]);
                          }
                        },
                        child: TaskRow(
                          task: shown[i],
                          members: members,
                          onToggle: () {
                            if (repo != null) toggleTask(repo, shown[i]);
                          },
                          onTap: repo == null
                              ? null
                              : () => showTaskSheet(context, repo, members,
                                  item: shown[i]),
                          onLongPress: repo == null
                              ? null
                              : () => itemMenu(context,
                                  title: shown[i].str('title'),
                                  onEdit: () => showTaskSheet(
                                      context, repo, members,
                                      item: shown[i]),
                                  onDelete: () => deleteItem(
                                      context, repo, 'tasks', shown[i])),
                        ),
                      ),
                      if (i < shown.length - 1)
                        Divider(height: 1, color: UColors.muted.withAlpha(40)),
                    ],
                  ],
                ),
              ),
            ),
          if (_filter != 2 && done.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _filter = 2),
                  child: Text('${done.length} completate'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showTaskSheet(BuildContext context, Repo repo, List<Item> members,
    {Item? item}) {
  return showUSheet(context, _TaskForm(repo: repo, members: members, item: item));
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.repo, required this.members, this.item});
  final Repo repo;
  final List<Item> members;
  final Item? item;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.str('title'));
  late final TextEditingController _note =
      TextEditingController(text: widget.item?.str('note'));
  DateTime? _due;
  String _time = '';
  String _repeat = '';
  String? _assignee;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _due = widget.item?.date('due');
    _time = widget.item?.str('time') ?? '';
    _repeat = widget.item?.str('repeat') ?? '';
    final ph = widget.item?.str('photoId') ?? '';
    _photo = ph.isEmpty ? null : ph;
    _assignee = widget.item?.data['assignee'] as String?;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _pickTime() async {
    var initial = const TimeOfDay(hour: 18, minute: 0);
    if (_time.contains(':')) {
      final p = _time.split(':');
      initial = TimeOfDay(
          hour: int.tryParse(p[0]) ?? 18, minute: int.tryParse(p[1]) ?? 0);
    }
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setState(() {
        _time =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        _due ??= dayOnly(DateTime.now());
      });
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_repeat.isNotEmpty) _due ??= dayOnly(DateTime.now());
    final data = <String, dynamic>{
      'title': title,
      'note': _note.text.trim(),
      'due': _due == null ? null : Timestamp.fromDate(_due!),
      'time': _due == null ? '' : _time,
      'assignee': _assignee,
      'repeat': _repeat,
      'photoId': _photo,
    };
    if (widget.item == null) {
      widget.repo.add('tasks', {...data, 'done': false});
      final me = FirebaseAuth.instance.currentUser?.uid;
      Feed.log(
        widget.repo,
        icon: '✅',
        text: _assignee == null
            ? 'ha aggiunto un\'attività per voi: "$title"'
            : (_assignee == me
                ? 'ha aggiunto un\'attività: "$title"'
                : 'ha aggiunto un\'attività per ${Push.instance.partnerName}: "$title"'),
        push: _assignee != me,
        pushTitle: _assignee == null
            ? '✅ Nuova attività per voi'
            : '✅ ${Push.instance.myName} ti ha dato un\'attività',
        body: title,
        tag: 'tasks',
      );
    } else {
      widget.repo.update('tasks', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuova attività' : 'Modifica attività',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Cosa c\'è da fare?'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Nota (facoltativa)'),
        ),
        const SizedBox(height: 12),
        AttachmentField(
          repo: widget.repo,
          id: _photo,
          label: 'Allega una foto',
          onChanged: (v) => setState(() => _photo = v),
        ),
        const SizedBox(height: 16),
        const Text('Quando', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Oggi'),
              selected: _due != null && sameDay(_due!, today),
              onSelected: (_) => setState(() => _due = today),
            ),
            ChoiceChip(
              label: const Text('Domani'),
              selected: _due != null &&
                  sameDay(_due!, today.add(const Duration(days: 1))),
              onSelected: (_) =>
                  setState(() => _due = today.add(const Duration(days: 1))),
            ),
            ActionChip(
              avatar: const Icon(Icons.event, size: 18),
              label: Text(_due == null ? 'Scegli data' : fmtDay(_due!)),
              onPressed: _pickDate,
            ),
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(_time.isEmpty ? 'Aggiungi ora' : _time),
              onPressed: _pickTime,
            ),
            if (_time.isNotEmpty)
              ActionChip(
                label: const Text('Senza ora'),
                onPressed: () => setState(() => _time = ''),
              ),
            if (_due != null)
              ActionChip(
                label: const Text('Senza scadenza'),
                onPressed: () => setState(() {
                  _due = null;
                  _time = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Si ripete', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in repeatLabels.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _repeat == e.key,
                onSelected: (_) => setState(() {
                  _repeat = e.key;
                  if (e.key.isNotEmpty) _due ??= dayOnly(DateTime.now());
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Per chi è',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final meUid = FirebaseAuth.instance.currentUser?.uid;
          final others = widget.members.where((m) => m.id != meUid).toList();
          final partnerName = others.isEmpty
              ? null
              : (firstName(others.first.str('name')).isEmpty
                  ? 'il partner'
                  : firstName(others.first.str('name')));
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Per me'),
                selected: _assignee == meUid && meUid != null,
                onSelected: (_) => setState(() => _assignee = meUid),
              ),
              if (others.isNotEmpty)
                ChoiceChip(
                  label: Text('Per $partnerName'),
                  selected: _assignee == others.first.id,
                  onSelected: (_) =>
                      setState(() => _assignee = others.first.id),
                ),
              ChoiceChip(
                label: const Text('Per entrambi'),
                selected: _assignee == null,
                onSelected: (_) => setState(() => _assignee = null),
              ),
            ],
          );
        }),
        const SizedBox(height: 22),
        Row(
          children: [
            if (widget.item != null)
              IconButton(
                onPressed: () {
                  deleteItem(context, widget.repo, 'tasks', widget.item!);
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
