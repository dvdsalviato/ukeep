import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../tasks/tasks_page.dart';

/// Sondaggi "Decidiamo insieme".
/// polls/{id}: q (domanda), options [testo], votes {uid: indice},
/// closed, result (indice scelto a caso in caso di pareggio).
List<String> pollOptions(Item p) =>
    ((p.data['options'] as List?) ?? []).map((e) => '$e').toList();

Map<String, int> pollVotes(Item p) {
  final v = p.data['votes'];
  if (v is! Map) return {};
  return {
    for (final e in v.entries)
      if (e.value is num) '${e.key}': (e.value as num).toInt()
  };
}

bool pollNeedsMyVote(Item p, String? me) =>
    !p.flag('closed') && me != null && !pollVotes(p).containsKey(me);

class PollsSection extends ConsumerWidget {
  const PollsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    if (repo == null) return const SizedBox.shrink();
    final members = ref.watch(membersProvider).value ?? [];
    final polls = [...(ref.watch(pollsProvider).value ?? <Item>[])]
      ..sort((a, b) {
        final ca = a.flag('closed') ? 1 : 0;
        final cb = b.flag('closed') ? 1 : 0;
        if (ca != cb) return ca - cb;
        return (b.date('createdAt') ?? DateTime(2100))
            .compareTo(a.date('createdAt') ?? DateTime(2100));
      });
    if (polls.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmptyCard(
            emoji: '🗳️',
            title: 'Decidiamo insieme',
            text:
                'Stasera sushi o pizza? Film o serie? Fate una domanda, votate in due e se siete in pareggio decide la sorte.',
          ),
          const SectionTitle('Idee veloci'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              templateChip('🍕', 'Cosa mangiamo stasera?', () {
                showPollSheet(context, repo,
                    question: 'Cosa mangiamo stasera?',
                    options: ['Pizza', 'Sushi', 'Cucino io']);
              }),
              templateChip('🎬', 'Cosa guardiamo?', () {
                showPollSheet(context, repo,
                    question: 'Cosa guardiamo?',
                    options: ['Un film', 'Una serie', 'Niente, usciamo']);
              }),
              templateChip('🌅', 'Weekend?', () {
                showPollSheet(context, repo,
                    question: 'Cosa facciamo nel weekend?',
                    options: ['Gita', 'Divano', 'Amici']);
              }),
            ]),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final p in polls)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PollCard(poll: p, repo: repo, members: members),
            ),
        ],
      ),
    );
  }
}

class PollCard extends StatelessWidget {
  const PollCard(
      {super.key,
      required this.poll,
      required this.repo,
      required this.members});
  final Item poll;
  final Repo repo;
  final List<Item> members;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final opts = pollOptions(poll);
    final votes = pollVotes(poll);
    final closed = poll.flag('closed');
    final mine = votes[me];
    final everyone = members.isNotEmpty &&
        members.every((m) => votes.containsKey(m.id));
    final showResults = closed || everyone || mine != null;
    final counts = List<int>.filled(opts.length, 0);
    for (final v in votes.values) {
      if (v >= 0 && v < counts.length) counts[v]++;
    }
    final result = poll.data['result'] as int?;
    String? verdict;
    if (everyone && votes.values.toSet().length == 1) {
      final i = votes.values.first;
      if (i < opts.length) verdict = 'Siete d\'accordo: ${opts[i]} 🎉';
    } else if (result != null && result < opts.length) {
      verdict = 'Ha deciso la sorte: ${opts[result]} 🪙';
    }

    return UCard(
      onLongPress: () => itemMenu(context,
          title: poll.str('q'),
          onEdit: closed
              ? null
              : () => repo.update('polls', poll.id, {'closed': true}),
          editLabel: 'Chiudi il sondaggio',
          onDelete: () =>
              deleteItem(context, repo, 'polls', poll, label: poll.str('q'))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🗳️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(poll.str('q'), style: serif(22))),
              if (closed)
                Text('chiuso',
                    style: TextStyle(color: UColors.muted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: closed || me == null
                    ? null
                    : () => repo.update('polls', poll.id, {'votes.$me': i}),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: mine == i
                            ? UColors.dark
                            : UColors.muted.withAlpha(60),
                        width: mine == i ? 1.6 : 1),
                  ),
                  child: Stack(
                    children: [
                      if (showResults && votes.isNotEmpty)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: counts[i] / max(1, members.length),
                            child: Container(
                              decoration: BoxDecoration(
                                color: UColors.rose.withAlpha(70),
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(opts[i],
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: mine == i
                                            ? FontWeight.w800
                                            : FontWeight.w500))),
                            if (showResults)
                              for (final m in members)
                                if (votes[m.id] == i)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: UAvatar.member(m, size: 22),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (verdict != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(verdict,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: UColors.accent)),
            )
          else if (everyone && !closed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final tied = <int>[];
                  final top = counts.reduce(max);
                  for (var i = 0; i < counts.length; i++) {
                    if (counts[i] == top) tied.add(i);
                  }
                  final pick = tied[Random().nextInt(tied.length)];
                  repo.update('polls', poll.id, {'result': pick, 'closed': true});
                },
                icon: const Text('🪙'),
                label: const Text('Pareggio: decida la sorte'),
              ),
            )
          else if (!everyone)
            Text(
                mine == null
                    ? 'Tocca la tua scelta'
                    : 'In attesa del voto di ${_waitingFor(members, votes)}',
                style: TextStyle(color: UColors.muted, fontSize: 13)),
        ],
      ),
    );
  }

  String _waitingFor(List<Item> members, Map<String, int> votes) {
    for (final m in members) {
      if (!votes.containsKey(m.id)) {
        final n = firstName(m.str('name'));
        return n.isEmpty ? 'il partner' : n;
      }
    }
    return 'il partner';
  }
}

Future<void> showPollSheet(BuildContext context, Repo repo,
        {String? question, List<String>? options}) =>
    showUSheet(context,
        _PollForm(repo: repo, question: question, options: options));

class _PollForm extends StatefulWidget {
  const _PollForm({required this.repo, this.question, this.options});
  final Repo repo;
  final String? question;
  final List<String>? options;

  @override
  State<_PollForm> createState() => _PollFormState();
}

class _PollFormState extends State<_PollForm> {
  late final _q = TextEditingController(text: widget.question);
  late final List<TextEditingController> _opts = [
    for (final o in (widget.options ?? ['', ''])) TextEditingController(text: o)
  ];

  @override
  void dispose() {
    _q.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final q = _q.text.trim();
    final opts =
        _opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (q.isEmpty || opts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Serve una domanda e almeno 2 risposte')));
      return;
    }
    widget.repo.add('polls', {
      'q': q,
      'options': opts,
      'votes': <String, int>{},
      'closed': false,
    });
    Feed.log(widget.repo,
        icon: '🗳️', text: 'chiede: "$q"', textMe: 'Hai chiesto: "$q"', tag: 'polls');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Nuovo sondaggio', style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _q,
          autofocus: widget.question == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Domanda', hint: 'Es. Dove andiamo a cena?'),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _opts[i],
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDeco('Risposta ${i + 1}'),
            ),
          ),
        if (_opts.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _opts.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi risposta'),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton(
            style: pillStyle, onPressed: _save, child: const Text('Chiedi')),
      ],
    );
  }
}
