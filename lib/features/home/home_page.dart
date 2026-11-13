import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/mood.dart';
import '../../core/notifications.dart';
import '../../core/photo.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../calendar/calendar_page.dart';
import '../expenses/expenses_page.dart';
import '../polls/polls_page.dart';
import '../search/search_page.dart';
import '../stories/stories.dart';
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

  Future<void> _pickSince(BuildContext context, Repo repo,
      DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? now,
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
    final expenses = ref.watch(expensesProvider).value ?? [];
    final polls = ref.watch(pollsProvider).value ?? [];
    final lastHug = ref.watch(lastHugProvider).value;
    final me = FirebaseAuth.instance.currentUser;
    final partnerItems = members.where((m) => m.id != me?.uid).toList();
    final partnerName = partnerItems.isEmpty
        ? 'il partner'
        : (firstName(partnerItems.first.str('name')).isEmpty
            ? 'il partner'
            : firstName(partnerItems.first.str('name')));
    final toVote =
        polls.where((p) => pollNeedsMyVote(p, me?.uid)).take(2).toList();
    final hugAt = lastHug?.date('at');
    final hugFromPartner = lastHug != null &&
        lastHug.str('by') != me?.uid &&
        hugAt != null &&
        DateTime.now().difference(hugAt).inHours < 24;

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
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(dateLabel,
                    style:
                        TextStyle(color: UColors.muted, fontSize: 15)),
              ),
              IconButton(
                tooltip: 'Cerca',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchPage())),
                style: IconButton.styleFrom(backgroundColor: UColors.card),
                icon: Icon(Icons.search, color: UColors.ink),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: isDark ? 'Tema chiaro' : 'Tema scuro',
                onPressed: ThemeCtl.toggle,
                style: IconButton.styleFrom(backgroundColor: UColors.card),
                icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: UColors.ink),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<NotifSettings>(
                valueListenable: NotifService.instance.settings,
                builder: (context, s, _) => IconButton(
                  tooltip: 'Notifiche',
                  onPressed: () => showNotifSheet(context),
                  style: IconButton.styleFrom(backgroundColor: UColors.card),
                  icon: Icon(
                      s.enabled
                          ? Icons.notifications_none
                          : Icons.notifications_off_outlined,
                      color: UColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // avatar con cuore
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < sorted.length && i < 2; i++)
              Transform.translate(
                offset: Offset(i == 0 ? 8 : -8, 0),
                child: GestureDetector(
                  onTap: sorted[i].id == me?.uid
                      ? () => changeProfilePhoto(context)
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: UColors.surface, shape: BoxShape.circle),
                        child: UAvatar.member(sorted[i], size: 76),
                      ),
                      Positioned(
                        right: i == 0 ? null : -4,
                        left: i == 0 ? -4 : null,
                        bottom: -4,
                        child: GestureDetector(
                          onTap: sorted[i].id == me?.uid
                              ? () => showMoodPicker(context, me!.uid)
                              : null,
                          child: Builder(builder: (_) {
                            final mood = todayMood(sorted[i]);
                            if (mood == null && sorted[i].id != me?.uid) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: UColors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 6)
                                  ]),
                              child: Text(mood ?? '🙂',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: mood == null
                                          ? UColors.muted.withAlpha(120)
                                          : null)),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (sorted.length < 2)
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: UColors.surface, shape: BoxShape.circle),
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
            onTap: repo == null ? null : () => _pickSince(context, repo, since),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                since != null
                    ? '${togetherText(since)}  ›'
                    : 'Imposta da quando state insieme  ›',
                style: TextStyle(color: UColors.muted, fontSize: 16),
              ),
            ),
          ),
        ),
        if (repo != null && partnerItems.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: UColors.card,
                foregroundColor: UColors.ink,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => sendHug(context, repo),
              icon: const Text('🤗', style: TextStyle(fontSize: 18)),
              label: Text('Manda un abbraccio a $partnerName'),
            ),
          ),
          if (hugFromPartner)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                    '$partnerName ti ha mandato un abbraccio alle ${DateFormat('HH:mm').format(hugAt!)} 💛',
                    style: TextStyle(color: UColors.accent, fontSize: 14)),
              ),
            ),
        ],
        const SizedBox(height: 16),
        const StoriesRow(),
        const SizedBox(height: 14),
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
            style: TextStyle(color: UColors.muted, fontSize: 16),
            children: [
              const TextSpan(text: 'Serie di '),
              TextSpan(
                  text: '$streak',
                  style: TextStyle(
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
                    onTap: repo == null ? null : () => _pickSince(context, repo, since)),
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
                      Icon(Icons.check_circle_outline,
                          color: UColors.ink),
                      const SizedBox(width: 10),
                      const Text('Attività da fare',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('${open.length} da fare',
                          style: TextStyle(color: UColors.muted)),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: UColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (open.isEmpty)
                  Padding(
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
                        style: TextStyle(color: UColors.muted)),
                  ),
              ],
            ),
          ),
        ),
        if (repo != null)
          for (final p in toVote) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PollCard(poll: p, repo: repo, members: members),
            ),
          ],
        if (expenses.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              onTap: () {
                listsSegment.value = 3;
                onGoTo(2);
              },
              child: Row(
                children: [
                  const Text('💸', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        balanceText(
                            expenseBalance(expenses, me?.uid), partnerName),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.chevron_right, color: UColors.muted),
                ],
              ),
            ),
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UCard(
              onTap: () => onGoTo(3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
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
                              style: TextStyle(
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
              _Promo(
                title: 'Spese',
                subtitle: expenses.isEmpty
                    ? 'Chi ha pagato cosa, e chi deve a chi'
                    : balanceText(expenseBalance(expenses, me?.uid), partnerName),
                icon: Icons.euro,
                colors: const [Color(0xFFDCD0F5), Color(0xFFFFE6C9)],
                onTap: () {
                  listsSegment.value = 3;
                  onGoTo(2);
                },
              ),
              _Promo(
                title: 'Sondaggi',
                subtitle: 'Sushi o pizza? Votate e decidete insieme',
                icon: Icons.how_to_vote_outlined,
                colors: const [Color(0xFFFFD9CC), Color(0xFFDCD0F5)],
                onTap: () {
                  listsSegment.value = 4;
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
                      TextStyle(color: UColors.muted, fontSize: 14)),
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

const _pInk = Color(0xFF2A2430);

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
                            color: _pInk.withAlpha(150))),
                    const Spacer(),
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withAlpha(200),
                        child: Icon(icon, size: 20, color: _pInk)),
                  ],
                ),
                const Spacer(),
                Text(title, style: serif(28, color: _pInk)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _pInk.withAlpha(170), fontSize: 14)),
              ],
            ),
          ),
        ),
      );
}
