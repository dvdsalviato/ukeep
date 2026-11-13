import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../calendar/calendar_page.dart';
import '../tasks/tasks_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onGoTo});
  final void Function(int) onGoTo;

  int _streak(Set<DateTime> doneDays) {
    final today = dayOnly(DateTime.now());
    var d = doneDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var n = 0;
    while (doneDays.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  String _together(DateTime since) {
    final days = dayOnly(DateTime.now()).difference(dayOnly(since)).inDays;
    if (days >= 365) {
      final y = days ~/ 365;
      return 'Insieme da $y ${y == 1 ? 'anno' : 'anni'}';
    }
    if (days >= 30) {
      final m = days ~/ 30;
      return 'Insieme da $m ${m == 1 ? 'mese' : 'mesi'}';
    }
    return 'Insieme da $days ${days == 1 ? 'giorno' : 'giorni'}';
  }

  Future<void> _pickSince(BuildContext context, Repo repo) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1980),
      lastDate: now,
      helpText: 'Da quando state insieme?',
    );
    if (d != null) repo.setSince(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final members = ref.watch(membersProvider).value ?? [];
    final couple = ref.watch(coupleDocProvider).value;
    final tasks = ref.watch(tasksProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];
    final wishes = ref.watch(wishesProvider).value ?? [];
    final lists = ref.watch(listsProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser;

    // --- persone
    final sorted = [...members]..sort((a, b) {
        if (a.id == me?.uid) return -1;
        if (b.id == me?.uid) return 1;
        return 0;
      });
    final names = sorted
        .map((m) => firstName(m.str('name')))
        .where((n) => n.isNotEmpty)
        .toList();
    DateTime? since;
    final rawSince = couple?['since'];
    if (rawSince is Timestamp) since = rawSince.toDate();

    // --- serie
    final open = tasks.where((t) => !t.flag('done')).toList()..sort(compareOpen);
    final doneDays = <DateTime>{
      for (final t in tasks)
        if (t.flag('done') && t.date('doneAt') != null)
          dayOnly(t.date('doneAt')!),
    };
    final streak = _streak(doneDays);
    final today = dayOnly(DateTime.now());
    final doneToday = doneDays.contains(today);

    // --- prossime date
    final upcoming = <MapEntry<DateTime, Item>>[];
    for (final e in events) {
      final n = nextOccurrence(e, today);
      if (n != null) upcoming.add(MapEntry(n, e));
    }
    upcoming.sort((a, b) => a.key.compareTo(b.key));

    final dateLabel = capitalize(DateFormat('EEEE d MMMM', 'it_IT').format(today));

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Text(dateLabel,
              style: const TextStyle(color: UColors.muted, fontSize: 15)),
        ),
        const SizedBox(height: 18),
        // avatar con cuore
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < sorted.length && i < 2; i++)
              Transform.translate(
                offset: Offset(i == 0 ? 8 : -8, 0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: UAvatar(
                      name: sorted[i].str('name'),
                      photo: sorted[i].str('photo'),
                      size: 76),
                ),
              ),
            if (sorted.length < 2)
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: UColors.bgMid,
                    child: Icon(Icons.person_add_alt_1,
                        color: UColors.rose.withAlpha(220)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Ciao, ', style: serif(36)),
              TextSpan(
                text: names.isEmpty ? 'voi' : names.join(' & '),
                style: serif(36, style: FontStyle.italic, color: UColors.accent),
              ),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
            onTap: repo == null ? null : () => _pickSince(context, repo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                since != null
                    ? '${_together(since)}  ›'
                    : 'Imposta da quando state insieme  ›',
                style: const TextStyle(color: UColors.muted, fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ultimi 7 giorni
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--)
                _DayDot(
                  day: today.subtract(Duration(days: i)),
                  isToday: i == 0,
                  active: doneDays
                      .contains(today.subtract(Duration(days: i))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text.rich(TextSpan(
            style: const TextStyle(color: UColors.muted, fontSize: 16),
            children: [
              const TextSpan(text: 'Serie di '),
              TextSpan(
                  text: '$streak',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: UColors.ink)),
              TextSpan(
                  text: doneToday
                      ? ' — per oggi è fatta'
                      : ' — completate un\'attività oggi'),
            ],
          )),
        ),
        const SizedBox(height: 18),
        // statistiche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _Stat(
                    value: since == null
                        ? '—'
                        : '${today.difference(dayOnly(since)).inDays}',
                    label: 'giorni insieme',
                    onTap: repo == null ? null : () => _pickSince(context, repo)),
                _vline(),
                _Stat(
                    value: '$streak',
                    label: 'serie',
                    onTap: () => onGoTo(1)),
                _vline(),
                _Stat(
                    value: '${open.length}',
                    label: 'da fare',
                    onTap: () => onGoTo(1)),
              ],
            ),
          ),
        ),
        const SectionTitle('Momenti insieme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: UCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => onGoTo(1),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: UColors.ink),
                      const SizedBox(width: 10),
                      const Text('Attività da fare',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('${open.length} da fare',
                          style: const TextStyle(color: UColors.muted)),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: UColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (open.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Niente in sospeso. Godetevi la giornata!',
                        style: TextStyle(color: UColors.muted)),
                  ),
                for (final t in open.take(3))
                  TaskRow(
                    task: t,
                    members: members,
                    compact: true,
                    onToggle: () {
                      if (repo != null) toggleTask(repo, t);
                    },
                  ),
                if (open.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('e ${open.length - 3} in più',
                        style: const TextStyle(color: UColors.muted)),
                  ),
              ],
            ),
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              onTap: () => onGoTo(3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.cake_outlined, color: UColors.ink),
                    SizedBox(width: 10),
                    Text('Prossime date',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  for (final u in upcoming.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(eventIcon(u.value.str('type')),
                              color: UColors.danger, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(u.value.str('title'),
                                style: const TextStyle(fontSize: 16)),
                          ),
                          Text(relDay(u.key, far: true),
                              style: const TextStyle(
                                  color: UColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SectionTitle('Nuovo per voi'),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Promo(
                title: 'Desideri',
                subtitle: wishes.isEmpty
                    ? 'Quello che ognuno vuole, così i regali fanno centro'
                    : '${wishes.length} nella vostra lista',
                icon: Icons.star_border,
                colors: const [Color(0xFFFFD9CC), Color(0xFFF3D5EE)],
                onTap: () {
                  listsSegment.value = 1;
                  onGoTo(2);
                },
              ),
              _Promo(
                title: 'Liste',
                subtitle: lists.isEmpty
                    ? 'Spesa, viaggi, idee: tutto condiviso'
                    : '${lists.length} liste condivise',
                icon: Icons.list_alt,
                colors: const [Color(0xFFF3D5EE), Color(0xFFDCD0F5)],
                onTap: () {
                  listsSegment.value = 0;
                  onGoTo(2);
                },
              ),
              _Promo(
                title: 'Progetti',
                subtitle: projects.isEmpty
                    ? 'Le cose grandi, un passo alla volta'
                    : '${projects.where((p) => p.str('status') != 'done').length} in corso',
                icon: Icons.flag_outlined,
                colors: const [Color(0xFFFFE6C9), Color(0xFFFFD9CC)],
                onTap: () {
                  listsSegment.value = 2;
                  onGoTo(2);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vline() => Container(
      width: 1, height: 44, color: UColors.muted.withAlpha(50));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('$label ›',
                  style:
                      const TextStyle(color: UColors.muted, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _DayDot extends StatelessWidget {
  const _DayDot(
      {required this.day, required this.isToday, required this.active});
  final DateTime day;
  final bool isToday;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final label = isToday
        ? 'Oggi'
        : capitalize(DateFormat('E', 'it_IT').format(day).replaceAll('.', ''));
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? UColors.rose
                : (isToday
                    ? UColors.rose.withAlpha(90)
                    : UColors.muted.withAlpha(45)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? UColors.ink : UColors.muted)),
      ],
    );
  }
}

class _Promo extends StatelessWidget {
  const _Promo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('NUOVO PER VOI',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                            color: UColors.ink.withAlpha(150))),
                    const Spacer(),
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withAlpha(200),
                        child: Icon(icon, size: 20, color: UColors.ink)),
                  ],
                ),
                const Spacer(),
                Text(title, style: serif(28)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: UColors.ink.withAlpha(170), fontSize: 14)),
              ],
            ),
          ),
        ),
      );
}
