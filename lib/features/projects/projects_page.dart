import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secret.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';

class ProjectsSection extends ConsumerWidget {
  const ProjectsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final projects = ref.watch(projectsProvider).value ?? [];
    if (projects.isEmpty) {
      const templates = [
        ['✈️', 'Vacanza'],
        ['🏠', 'Casa'],
        ['🎉', 'Festa a sorpresa'],
        ['💍', 'Grande giorno'],
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmptyCard(
            emoji: '🎯',
            title: 'Il primo progetto',
            text:
                'Una vacanza, un trasloco, una festa: spezzatelo in piccoli passi e spuntateli insieme.',
          ),
          const SectionTitle('Parti da un modello'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in templates)
                  templateChip(t[0], t[1], () {
                    repo?.add('projects', {
                      'title': t[1],
                      'icon': t[0],
                      'desc': '',
                      'status': 'active',
                      'steps': [],
                    });
                  }),
              ],
            ),
          ),
        ],
      );
    }
    final sorted = [...projects]..sort((a, b) {
        final ad = a.str('status') == 'done' ? 1 : 0;
        final bd = b.str('status') == 'done' ? 1 : 0;
        if (ad != bd) return ad - bd;
        return (a.date('createdAt') ?? DateTime(2100))
            .compareTo(b.date('createdAt') ?? DateTime(2100));
      });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final p in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: isLocked(p)
                  ? LockedCard(
                      item: p,
                      titleKey: 'title',
                      what: 'Progetto',
                      onOpen: () async {
                        if (await unlockItem(context, p, p.str('title'))) {
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailPage(projectId: p.id)));
                        }
                      },
                      onDelete: () async {
                        if (await confirm(context,
                            'Eliminare il progetto segreto "${p.str('title')}"?')) {
                          ref.read(repoProvider)?.remove('projects', p.id);
                        }
                      },
                    )
                  : UCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProjectDetailPage(projectId: p.id))),
                child: Builder(builder: (context) {
                  final steps = p.steps('steps');
                  final done = steps.where((s) => s['d'] == true).length;
                  final isDone = p.str('status') == 'done';
                  final target = p.date('target');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(p.str('icon', '🎯'),
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(p.str('title'),
                                style: serif(22).copyWith(
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null)),
                          ),
                          if (isDone)
                            const Icon(Icons.check_circle,
                                color: UColors.accent),
                        ],
                      ),
                      if (p.str('desc').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(p.str('desc'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: UColors.muted)),
                      ],
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: steps.isEmpty
                              ? (isDone ? 1 : 0)
                              : done / steps.length,
                          minHeight: 8,
                          backgroundColor: UColors.bgMid,
                          color: UColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                              steps.isEmpty
                                  ? 'Nessun passo'
                                  : '$done di ${steps.length} passi',
                              style: const TextStyle(
                                  color: UColors.muted, fontSize: 13.5)),
                          const Spacer(),
                          if (target != null)
                            Text('Entro ${fmtDay(target)}',
                                style: const TextStyle(
                                    color: UColors.muted, fontSize: 13.5)),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showProjectSheet(BuildContext context, Repo repo, {Item? item}) =>
    showUSheet(context, _ProjectForm(repo: repo, item: item));

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({required this.repo, this.item});
  final Repo repo;
  final Item? item;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.str('title'));
  late final TextEditingController _desc =
      TextEditingController(text: widget.item?.str('desc'));
  late String _icon = widget.item?.str('icon', '🎯') ?? '🎯';
  DateTime? _target;
  late bool _secret = widget.item?.flag('locked') ?? false;
  String? _newPin;

  @override
  void initState() {
    super.initState();
    _target = widget.item?.date('target');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _target ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _target = d);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final data = <String, dynamic>{
      'title': title,
      'desc': _desc.text.trim(),
      'icon': _icon,
      'target': _target == null ? null : Timestamp.fromDate(_target!),
      if (_secret && _newPin != null) ...secretFields(_newPin),
      if (!_secret && (widget.item?.flag('locked') ?? false))
        ...secretFields(null),
    };
    if (widget.item == null) {
      widget.repo.add('projects', {...data, 'status': 'active', 'steps': []});
    } else {
      widget.repo.update('projects', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const icons = ['🎯', '✈️', '🏠', '🔨', '💍', '🚗', '🌱', '🎉', '💼', '🐶'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuovo progetto' : 'Modifica progetto',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Nome del progetto', hint: 'Es. Vacanza in Grecia'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Descrizione (facoltativa)'),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label:
                    Text(_target == null ? 'Scadenza (facoltativa)' : fmtDay(_target!)),
              ),
            ),
            if (_target != null)
              IconButton(
                  onPressed: () => setState(() => _target = null),
                  icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 14),
        SecretSwitch(
          value: _secret,
          what: 'Progetto',
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

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _setSteps(Repo repo, List<Map<String, dynamic>> steps) =>
      repo.update('projects', widget.projectId, {'steps': steps});

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final projects = ref.watch(projectsProvider).value ?? [];
    Item? found;
    for (final p in projects) {
      if (p.id == widget.projectId) found = p;
    }
    if (found == null || repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final Item p = found;
    final steps = p.steps('steps');
    final isDone = p.str('status') == 'done';
    final target = p.date('target');

    void add() {
      final t = _input.text.trim();
      if (t.isEmpty) return;
      _setSteps(repo, [
        ...steps,
        {'t': t, 'd': false}
      ]);
      _input.clear();
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                showProjectSheet(context, repo, item: p);
              } else if (v == 'delete') {
                if (await confirm(context, 'Eliminare "${p.str('title')}"?')) {
                  repo.remove('projects', p.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifica')),
              PopupMenuItem(value: 'delete', child: Text('Elimina progetto')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 40 + bottomInset(context)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.str('icon', '🎯'), style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(p.str('title'), style: serif(36)),
                if (p.str('desc').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(p.str('desc'),
                      style:
                          const TextStyle(color: UColors.muted, fontSize: 16)),
                ],
                if (target != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.event, size: 18, color: UColors.muted),
                    const SizedBox(width: 6),
                    Text('Entro ${fmtDay(target)}',
                        style: const TextStyle(color: UColors.muted)),
                  ]),
                ],
              ],
            ),
          ),
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
                        hintText: 'Aggiungi un passo…',
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
          if (steps.isEmpty)
            const EmptyHint(Icons.route_outlined,
                'Spezzate il progetto in piccoli passi: li spunterete uno a uno.')
          else
            UCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Dismissible(
                      key: ValueKey('${p.id}-$i-${steps[i]['t']}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12),
                        child: const Icon(Icons.delete_outline,
                            color: UColors.danger),
                      ),
                      onDismissed: (_) {
                        final next = [...steps]..removeAt(i);
                        _setSteps(repo, next);
                      },
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: UColors.accent,
                        value: steps[i]['d'] == true,
                        onChanged: (v) {
                          final next = [...steps];
                          next[i] = {...next[i], 'd': v == true};
                          _setSteps(repo, next);
                        },
                        title: Text(
                          '${steps[i]['t']}',
                          style: TextStyle(
                            fontSize: 16.5,
                            decoration: steps[i]['d'] == true
                                ? TextDecoration.lineThrough
                                : null,
                            color: steps[i]['d'] == true
                                ? UColors.muted
                                : UColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: UColors.dark),
              foregroundColor: UColors.dark,
            ),
            onPressed: () => repo.update(
                'projects', p.id, {'status': isDone ? 'active' : 'done'}),
            icon: Icon(isDone ? Icons.undo : Icons.check),
            label: Text(isDone ? 'Riapri il progetto' : 'Segna come completato'),
          ),
        ],
      ),
    );
  }
}
