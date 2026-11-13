import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
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

void toggleTask(Repo repo, Item t) {
  final done = !t.flag('done');
  repo.update('tasks', t.id, {
    'done': done,
    'doneAt': done ? Timestamp.now() : null,
  });
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
    this.compact = false,
  });
  final Item task;
  final List<Item> members;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = task.flag('done');
    final due = task.date('due');
    final overdue = !done &&
        due != null &&
        dayOnly(due).isBefore(dayOnly(DateTime.now()));
    final who = memberById(members, task.data['assignee'] as String?);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
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
                    task.str('title'),
                    style: TextStyle(
                      fontSize: 16.5,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? UColors.muted : UColors.ink,
                    ),
                  ),
                  if (!compact && task.str('note').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(task.str('note'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: UColors.muted, fontSize: 13.5)),
                    ),
                ],
              ),
            ),
            if (who != null && !compact)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: UAvatar(
                    name: who.str('name'), photo: who.str('photo'), size: 24),
              ),
            if (due != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  relDay(due),
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
                            _filter == e.key ? Colors.white : UColors.ink,
                        fontWeight: FontWeight.w600),
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    backgroundColor: Colors.white.withAlpha(200),
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
                          child: const Icon(Icons.delete_outline,
                              color: UColors.danger),
                        ),
                        confirmDismiss: (_) =>
                            confirm(context, 'Eliminare "${shown[i].str('title')}"?'),
                        onDismissed: (_) =>
                            repo?.remove('tasks', shown[i].id),
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
  String? _assignee;

  @override
  void initState() {
    super.initState();
    _due = widget.item?.date('due');
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

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final data = <String, dynamic>{
      'title': title,
      'note': _note.text.trim(),
      'due': _due == null ? null : Timestamp.fromDate(_due!),
      'assignee': _assignee,
    };
    if (widget.item == null) {
      widget.repo.add('tasks', {...data, 'done': false});
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
            if (_due != null)
              ActionChip(
                label: const Text('Senza scadenza'),
                onPressed: () => setState(() => _due = null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Di chi è', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Di entrambi'),
              selected: _assignee == null,
              onSelected: (_) => setState(() => _assignee = null),
            ),
            for (final m in widget.members)
              ChoiceChip(
                label: Text(firstName(m.str('name')).isEmpty
                    ? 'Partner'
                    : firstName(m.str('name'))),
                selected: _assignee == m.id,
                onSelected: (_) => setState(() => _assignee = m.id),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            if (widget.item != null)
              IconButton(
                onPressed: () {
                  widget.repo.remove('tasks', widget.item!.id);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline, color: UColors.danger),
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
