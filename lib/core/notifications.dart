import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/repo.dart';
import 'theme.dart';
import 'ui.dart';

class NotifSettings {
  const NotifSettings({
    this.enabled = true,
    this.morning = 8 * 60,
    this.fallback = 9 * 60,
    this.lead = 15,
  });
  final bool enabled;

  /// Minuti dalla mezzanotte: riepilogo del mattino.
  final int morning;

  /// Minuti dalla mezzanotte: ora usata per le attività senza orario.
  final int fallback;

  /// Minuti di anticipo del promemoria per le attività con orario.
  final int lead;

  NotifSettings copyWith(
          {bool? enabled, int? morning, int? fallback, int? lead}) =>
      NotifSettings(
        enabled: enabled ?? this.enabled,
        morning: morning ?? this.morning,
        fallback: fallback ?? this.fallback,
        lead: lead ?? this.lead,
      );
}

String fmtMinutes(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Notifiche locali: si programmano sul telefono a partire dalle attività
/// assegnate a te (o a entrambi). Si ricalcolano a ogni modifica e quando
/// l'app torna in primo piano.
class NotifService {
  NotifService._();
  static final NotifService instance = NotifService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final settings = ValueNotifier<NotifSettings>(const NotifSettings());
  bool _ready = false;
  String _lastSig = '';
  List<Item> _tasks = [];
  String? _uid;

  static const _red = Color(0xFFD32F2F);
  static const _accent = Color(0xFFB9743C);

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat')));
    final prefs = await SharedPreferences.getInstance();
    settings.value = NotifSettings(
      enabled: prefs.getBool('n_enabled') ?? true,
      morning: prefs.getInt('n_morning') ?? 8 * 60,
      fallback: prefs.getInt('n_fallback') ?? 9 * 60,
      lead: prefs.getInt('n_lead') ?? 15,
    );
    _ready = true;
    if (settings.value.enabled) await requestPermission();
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> update(NotifSettings s) async {
    settings.value = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('n_enabled', s.enabled);
    await prefs.setInt('n_morning', s.morning);
    await prefs.setInt('n_fallback', s.fallback);
    await prefs.setInt('n_lead', s.lead);
    if (s.enabled) await requestPermission();
    await sync(_tasks, _uid, force: true);
  }

  /// Quando scade l'attività (se non c'è l'ora, usa l'ora di default).
  DateTime? dueAt(Item t) {
    final d = t.date('due');
    if (d == null) return null;
    final base = dayOnly(d);
    var mins = settings.value.fallback;
    final time = t.str('time');
    if (time.contains(':')) {
      final p = time.split(':');
      mins = (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }
    return DateTime(base.year, base.month, base.day, mins ~/ 60, mins % 60);
  }

  NotificationDetails _details(
      {bool ongoing = false, bool quiet = false, bool red = false}) {
    final channel = ongoing
        ? (quiet ? 'ukeep_overdue_quiet' : 'ukeep_overdue')
        : 'ukeep_tasks';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        ongoing ? 'Attività scadute' : 'Promemoria attività',
        channelDescription: ongoing
            ? 'Resta in alto finché l\'attività non è fatta'
            : 'Promemoria e riepilogo del mattino',
        importance: quiet ? Importance.low : Importance.high,
        priority: quiet ? Priority.low : Priority.high,
        ongoing: ongoing,
        autoCancel: !ongoing,
        onlyAlertOnce: true,
        color: red ? _red : _accent,
        icon: 'ic_stat',
      ),
    );
  }

  int _id(String taskId, int kind) =>
      (taskId.hashCode & 0xFFFFF) * 10 + kind; // < 10.5 milioni

  Future<void> _at(int id, DateTime when, String title, String body,
      NotificationDetails d) async {
    final at = tz.TZDateTime.from(when, tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, at, d,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await _plugin.zonedSchedule(id, title, body, at, d,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  Future<void> test() async {
    await _plugin.show(
        900000100,
        'Notifiche attive 🎉',
        'Ukeep ti avviserà delle attività.',
        _details());
  }

  Future<void> sync(List<Item> tasks, String? uid, {bool force = false}) async {
    _tasks = tasks;
    _uid = uid;
    if (!_ready || uid == null) return;
    final s = settings.value;
    final mine = tasks.where((t) {
      if (t.flag('done')) return false;
      final a = t.data['assignee'] as String?;
      return a == null || a == uid;
    }).toList();
    final now = DateTime.now();
    final today = dayOnly(now);
    final sigParts = mine
        .map((t) =>
            '${t.id}|${t.str('title')}|${t.date('due')?.millisecondsSinceEpoch}|${t.str('time')}')
        .toList()
      ..sort();
    final sig =
        '${s.enabled}${s.morning}${s.fallback}${s.lead}#${today.millisecondsSinceEpoch}#${sigParts.join(';')}';
    if (!force && sig == _lastSig) return;
    _lastSig = sig;

    try {
      await _plugin.cancelAll();
      if (!s.enabled) return;

      // --- scadute: restano in alto finché non vengono fatte
      final overdue = <Item>[];
      for (final t in mine) {
        final due = dueAt(t);
        if (due == null) continue;
        if (!due.isAfter(now)) {
          overdue.add(t);
        } else {
          // scatta (e resta) al momento della scadenza
          await _at(_id(t.id, 0), due, '⏰ Da fare ora: ${t.str('title')}',
              'Tocca per aprire Ukeep', _details(ongoing: true, red: true));
          // promemoria prima, solo se c'è un orario preciso
          if (t.str('time').contains(':')) {
            final rem = due.subtract(Duration(minutes: s.lead));
            if (rem.isAfter(now)) {
              await _at(_id(t.id, 1), rem, 'Tra ${s.lead} minuti',
                  t.str('title'), _details());
            }
          }
        }
      }
      overdue.sort((a, b) => dueAt(a)!.compareTo(dueAt(b)!));
      if (overdue.length <= 3) {
        for (final t in overdue) {
          await _plugin.show(
              _id(t.id, 0),
              '⏰ Scaduta: ${t.str('title')}',
              'Era per ${fmtDay(dueAt(t)!)}${t.str('time').isEmpty ? '' : ' alle ${t.str('time')}'}',
              _details(ongoing: true, quiet: true, red: true));
        }
      } else {
        await _plugin.show(
            900001000,
            '⏰ ${overdue.length} attività scadute',
            overdue.take(3).map((t) => t.str('title')).join(' · '),
            _details(ongoing: true, quiet: true, red: true));
      }

      // --- riepilogo del mattino per i prossimi 7 giorni
      for (var i = 0; i < 7; i++) {
        final day = today.add(Duration(days: i));
        final at =
            DateTime(day.year, day.month, day.day, s.morning ~/ 60, s.morning % 60);
        if (!at.isAfter(now)) continue;
        final list = mine.where((t) {
          final d = t.date('due');
          return d != null && sameDay(d, day);
        }).toList();
        if (list.isEmpty) continue;
        if (list.length <= 3) {
          for (final t in list) {
            await _at(
                _id(t.id, 2),
                at,
                i == 0 ? 'Oggi: ${t.str('title')}' : 'In programma: ${t.str('title')}',
                t.str('time').isEmpty ? 'Per oggi' : 'Alle ${t.str('time')}',
                _details());
          }
        } else {
          await _at(
              900000000 + i,
              at,
              'Hai ${list.length} attività oggi',
              'Guarda le attività del giorno',
              _details());
        }
      }
    } catch (e) {
      debugPrint('Notifiche: $e');
    }
  }
}

/// Impostazioni notifiche (la campanella).
Future<void> showNotifSheet(BuildContext context) =>
    showUSheet(context, const _NotifSheet());

class _NotifSheet extends StatelessWidget {
  const _NotifSheet();

  Future<void> _pick(BuildContext context, int current,
      void Function(int) onPicked) async {
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t != null) onPicked(t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotifService.instance;
    return ValueListenableBuilder<NotifSettings>(
      valueListenable: svc.settings,
      builder: (context, s, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Notifiche', style: serif(28)),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avvisami delle attività'),
            subtitle: const Text('Solo quelle tue o di entrambi'),
            value: s.enabled,
            activeColor: UColors.dark,
            onChanged: (v) => svc.update(s.copyWith(enabled: v)),
          ),
          if (s.enabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Riepilogo del mattino'),
              subtitle: const Text(
                  'Fino a 3 attività una per una, oltre: una sola notifica'),
              trailing: Text(fmtMinutes(s.morning),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              onTap: () => _pick(context, s.morning,
                  (m) => svc.update(s.copyWith(morning: m))),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Attività senza orario'),
              subtitle: const Text('Scadono a quest\'ora del giorno scelto'),
              trailing: Text(fmtMinutes(s.fallback),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              onTap: () => _pick(context, s.fallback,
                  (m) => svc.update(s.copyWith(fallback: m))),
            ),
            const SizedBox(height: 8),
            const Text('Promemoria prima dell\'orario',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [5, 10, 15, 30, 60])
                  ChoiceChip(
                    label: Text(m == 60 ? '1 ora' : '$m min'),
                    selected: s.lead == m,
                    onSelected: (_) => svc.update(s.copyWith(lead: m)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Le attività scadute restano in alto, in rosso, finché non le '
              'spunti. Le notifiche si aggiornano quando apri Ukeep.',
              style: TextStyle(color: UColors.muted.withAlpha(230), fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: UColors.dark),
                foregroundColor: UColors.dark,
              ),
              onPressed: svc.test,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Prova una notifica'),
            ),
          ],
        ],
      ),
    );
  }
}
