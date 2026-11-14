import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/repo.dart';
import '../features/tasks/tasks_page.dart';
import 'push.dart';
import 'theme.dart';
import 'ui.dart';

class NotifSettings {
  const NotifSettings({
    this.enabled = true,
    this.morning = 8 * 60,
    this.fallback = 9 * 60,
    this.lead = 15,
    this.eveningOn = true,
    this.evening = 22 * 60,
  });
  final bool enabled;

  /// Minuti dalla mezzanotte: riepilogo del mattino.
  final int morning;

  /// Minuti dalla mezzanotte: ora usata per le attività senza orario.
  final int fallback;

  /// Minuti di anticipo del promemoria per le attività con orario.
  final int lead;

  /// Riepilogo della sera.
  final bool eveningOn;
  final int evening;

  NotifSettings copyWith({
    bool? enabled,
    int? morning,
    int? fallback,
    int? lead,
    bool? eveningOn,
    int? evening,
  }) =>
      NotifSettings(
        enabled: enabled ?? this.enabled,
        morning: morning ?? this.morning,
        fallback: fallback ?? this.fallback,
        lead: lead ?? this.lead,
        eveningOn: eveningOn ?? this.eveningOn,
        evening: evening ?? this.evening,
      );
}

String fmtMinutes(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

final _eurFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

const _redC = Color(0xFFD32F2F);
const _accentC = Color(0xFFB9743C);

/// Pulsanti "✔ Fatto" e "Rimanda 1 ora" sulle notifiche delle attività.
final _taskActions = <AndroidNotificationAction>[
  AndroidNotificationAction('done', '✔ Fatto', cancelNotification: true),
  AndroidNotificationAction('snooze', '⏰ Rimanda 1 ora',
      cancelNotification: true),
];

/// Arriva qui quando si tocca un pulsante della notifica con l'app chiusa.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) {
  handleNotifAction(r);
}

/// Esegue "Fatto" / "Rimanda" (funziona anche con l'app chiusa).
Future<void> handleNotifAction(NotificationResponse r) async {
  final action = r.actionId;
  final payload = r.payload;
  if (action == null || action.isEmpty || payload == null) return;
  final parts = payload.split('|');
  if (parts.length < 3 || parts[0] != 'task') return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final repo = Repo(parts[1]);
    final snap = await repo.col('tasks').doc(parts[2]).get();
    final data = snap.data();
    if (data == null) return;
    final t = Item(snap.id, data);
    final plugin = FlutterLocalNotificationsPlugin();
    if (action == 'done') {
      if (!t.flag('done')) await toggleTask(repo, t);
    } else if (action == 'snooze') {
      final at = DateTime.now().add(const Duration(hours: 1));
      final hhmm =
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
      await repo.update('tasks', t.id, {
        'due': Timestamp.fromDate(dayOnly(at)),
        'time': hhmm,
      });
      await plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat')));
      await plugin.zonedSchedule(
        (t.id.hashCode & 0xFFFFF) * 10,
        '⏰ Da fare ora: ${t.str('title')}',
        'Rimandata di un\'ora',
        tz.TZDateTime.from(at, tz.UTC),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ukeep_tasks',
            'Promemoria attività',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat',
            color: _accentC,
            actions: _taskActions,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  } catch (e) {
    debugPrint('Azione notifica: $e');
  }
}

/// Notifiche locali: si programmano sul telefono a partire dalle attività
/// assegnate a te (o a entrambi), dalle spese che si ripetono e dal
/// riepilogo della sera. Si ricalcolano a ogni modifica e quando l'app
/// torna in primo piano.
class NotifService {
  NotifService._();
  static final NotifService instance = NotifService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final settings = ValueNotifier<NotifSettings>(const NotifSettings());
  bool _ready = false;
  String _lastSig = '';
  List<Item> _tasks = [];
  List<Item> _expenses = [];
  String? _uid;
  String? _coupleId;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat')),
      onDidReceiveNotificationResponse: handleNotifAction,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final prefs = await SharedPreferences.getInstance();
    settings.value = NotifSettings(
      enabled: prefs.getBool('n_enabled') ?? true,
      morning: prefs.getInt('n_morning') ?? 8 * 60,
      fallback: prefs.getInt('n_fallback') ?? 9 * 60,
      lead: prefs.getInt('n_lead') ?? 15,
      eveningOn: prefs.getBool('n_evening_on') ?? true,
      evening: prefs.getInt('n_evening') ?? 22 * 60,
    );
    _ready = true;
    try {
      await _partnerChannel();
    } catch (_) {}
    await requestPermission();
  }

  void setCouple(String? coupleId) => _coupleId = coupleId;

  void setExpenses(List<Item> expenses) {
    _expenses = expenses;
    sync(_tasks, _uid);
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
    await prefs.setBool('n_evening_on', s.eveningOn);
    await prefs.setInt('n_evening', s.evening);
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
      {bool ongoing = false,
      bool quiet = false,
      bool red = false,
      bool actions = false}) {
    final channel = ongoing
        ? (quiet ? 'ukeep_overdue_quiet' : 'ukeep_overdue')
        : 'ukeep_tasks';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        ongoing ? 'Attività scadute' : 'Promemoria attività',
        channelDescription: ongoing
            ? 'Resta in alto finché l\'attività non è fatta'
            : 'Promemoria e riepiloghi',
        importance: quiet ? Importance.low : Importance.high,
        priority: quiet ? Priority.low : Priority.high,
        ongoing: ongoing,
        autoCancel: !ongoing,
        onlyAlertOnce: true,
        color: red ? _redC : _accentC,
        icon: 'ic_stat',
        actions: actions ? _taskActions : null,
      ),
    );
  }

  int _id(String taskId, int kind) =>
      (taskId.hashCode & 0xFFFFF) * 10 + kind; // < 10.5 milioni

  String? _payload(Item t) =>
      _coupleId == null ? null : 'task|$_coupleId|${t.id}';

  Future<void> _at(int id, DateTime when, String title, String body,
      NotificationDetails d,
      {String? payload}) async {
    final at = tz.TZDateTime.from(when, tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, at, d,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await _plugin.zonedSchedule(id, title, body, at, d,
            payload: payload,
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

  /// Toglie le notifiche delle attività (non quelle arrivate dal partner).
  Future<void> _clearOwn() async {
    final pend = await _plugin.pendingNotificationRequests();
    for (final p in pend) {
      await _plugin.cancel(p.id);
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final act =
        await android?.getActiveNotifications() ?? <ActiveNotification>[];
    for (final a in act) {
      if (a.channelId == 'ukeep_partner') continue;
      final int? id = a.id;
      if (id == null) continue;
      await _plugin.cancel(id, tag: a.tag);
    }
  }

  /// Mostra subito una notifica arrivata dal partner (app aperta).
  Future<void> showPartner(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('ukeep_partner', 'Dal partner',
            channelDescription: 'Abbracci e novità dal partner',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat',
            color: _accentC),
      ),
    );
  }

  /// Crea il canale per le notifiche del partner (serve anche alle push).
  Future<void> _partnerChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'ukeep_partner',
      'Dal partner',
      description: 'Abbracci e novità dal partner',
      importance: Importance.high,
    ));
  }

  double _amount(Item e) => ((e.data['amount'] as num?) ?? 0).toDouble();

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
    final doneToday = tasks
        .where((t) =>
            t.flag('done') &&
            t.date('doneAt') != null &&
            sameDay(t.date('doneAt')!, today))
        .length;
    final spentToday = _expenses
        .where((e) =>
            e.str('kind') != 'settle' &&
            e.date('date') != null &&
            sameDay(e.date('date')!, today))
        .fold<double>(0, (a, e) => a + _amount(e));
    final sigParts = mine
        .map((t) =>
            '${t.id}|${t.str('title')}|${t.date('due')?.millisecondsSinceEpoch}|${t.str('time')}')
        .toList()
      ..sort();
    final expSig = _expenses
        .where((e) => e.str('repeat').isNotEmpty)
        .map((e) => '${e.id}|${e.date('next')?.millisecondsSinceEpoch}')
        .toList()
      ..sort();
    final sig =
        '${s.enabled}${s.morning}${s.fallback}${s.lead}${s.eveningOn}${s.evening}#$_coupleId#${today.millisecondsSinceEpoch}#$doneToday#${spentToday.round()}#${sigParts.join(';')}#${expSig.join(';')}';
    if (!force && sig == _lastSig) return;
    _lastSig = sig;

    try {
      await _clearOwn();
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
              'Tocca per aprire Ukeep',
              _details(ongoing: true, red: true, actions: true),
              payload: _payload(t));
          // promemoria prima, solo se c'è un orario preciso
          if (t.str('time').contains(':')) {
            final rem = due.subtract(Duration(minutes: s.lead));
            if (rem.isAfter(now)) {
              await _at(_id(t.id, 1), rem, 'Tra ${s.lead} minuti',
                  t.str('title'), _details(actions: true),
                  payload: _payload(t));
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
              _details(ongoing: true, quiet: true, red: true, actions: true),
              payload: _payload(t));
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
        final at = DateTime(
            day.year, day.month, day.day, s.morning ~/ 60, s.morning % 60);
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
                i == 0
                    ? 'Oggi: ${t.str('title')}'
                    : 'In programma: ${t.str('title')}',
                t.str('time').isEmpty ? 'Per oggi' : 'Alle ${t.str('time')}',
                _details(actions: true),
                payload: _payload(t));
          }
        } else {
          await _at(900000000 + i, at, 'Hai ${list.length} attività oggi',
              'Guarda le attività del giorno', _details());
        }
      }

      // --- spese che si ripetono: avviso il giorno in cui si aggiungono
      for (final e in _expenses) {
        if (e.str('repeat').isEmpty) continue;
        final next = e.date('next');
        if (next == null) continue;
        final d = dayOnly(next);
        if (d.difference(today).inDays > 7) continue;
        var at = DateTime(
            d.year, d.month, d.day, s.morning ~/ 60, s.morning % 60);
        if (!at.isAfter(now)) {
          if (!sameDay(d, today)) continue;
          at = now.add(const Duration(minutes: 1));
        }
        await _at(
            903000000 + (e.id.hashCode & 0xFFFF),
            at,
            '${e.str('icon', '💸')} Oggi: ${e.str('title')} (${_eurFmt.format(_amount(e))})',
            'Spesa che si ripete: la trovi già nelle spese',
            _details());
      }

      // --- riepilogo della sera
      if (s.eveningOn) {
        for (var i = 0; i < 7; i++) {
          final day = today.add(Duration(days: i));
          final at = DateTime(
              day.year, day.month, day.day, s.evening ~/ 60, s.evening % 60);
          if (!at.isAfter(now)) continue;
          final tomorrow = day.add(const Duration(days: 1));
          final nextDay = mine.where((t) {
            final d = t.date('due');
            return d != null && sameDay(d, tomorrow);
          }).length;
          final parts = <String>[
            if (i == 0) 'Fatte oggi: $doneToday',
            nextDay == 0
                ? 'Domani niente in programma'
                : 'Domani: $nextDay da fare',
            if (i == 0 && overdue.isNotEmpty) 'Scadute: ${overdue.length}',
            if (i == 0 && spentToday > 0)
              'Spese di oggi: ${_eurFmt.format(spentToday)}',
          ];
          await _at(
              900002000 + i,
              at,
              i == 0 && doneToday > 0
                  ? '🌙 Bella giornata: $doneToday cose fatte'
                  : '🌙 Com\'è andata oggi?',
              parts.join(' · '),
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
            activeThumbColor: UColors.dark,
            onChanged: (v) => svc.update(s.copyWith(enabled: v)),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: Push.instance.receive,
            builder: (context, on, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avvisi dal partner'),
              subtitle: Text(Push.instance.configured
                  ? 'Abbracci, post-it, cose aggiunte alle liste'
                  : 'Da attivare: manca la chiave per le notifiche'),
              value: on,
              activeThumbColor: UColors.dark,
              onChanged: (v) => Push.instance.setReceive(v),
            ),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.nightlight_outlined),
              title: const Text('Riepilogo della sera'),
              subtitle: const Text(
                  'Cosa avete fatto, cosa c\'è domani, le spese del giorno'),
              value: s.eveningOn,
              activeThumbColor: UColors.dark,
              onChanged: (v) => svc.update(s.copyWith(eveningOn: v)),
            ),
            if (s.eveningOn)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40),
                title: const Text('Orario del riepilogo serale'),
                trailing: Text(fmtMinutes(s.evening),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                onTap: () => _pick(context, s.evening,
                    (m) => svc.update(s.copyWith(evening: m))),
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
              'Dalle notifiche delle attività puoi toccare "✔ Fatto" o '
              '"Rimanda 1 ora" senza aprire l\'app. Le scadute restano in '
              'alto, in rosso, finché non le spunti.',
              style: TextStyle(
                  color: UColors.muted.withAlpha(230), fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(color: UColors.dark),
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
