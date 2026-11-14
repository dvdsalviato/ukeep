import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../features/tasks/tasks_page.dart';
import 'feed.dart';
import 'push.dart';

/// Widget sulla schermata Home del telefono:
/// - UkeepWidget: attività di oggi, si spuntano toccandole;
/// - UkeepHugWidget: "Ti penso" (manda l'abbraccio) / "Giulia ti pensa".
class WidgetSync {
  WidgetSync._();
  static String _last = '';
  static String _lastId = '';

  static String _dueLabel(Item t) {
    final d = t.date('due');
    if (d == null) return t.str('title');
    final today = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final time = t.str('time');
    String when;
    if (diff < 0) {
      when = '⚠️ scaduta';
    } else if (diff == 0) {
      when = time.isEmpty ? 'oggi' : 'oggi $time';
    } else if (diff == 1) {
      when = time.isEmpty ? 'domani' : 'domani $time';
    } else {
      when = DateFormat('d MMM', 'it_IT').format(d);
    }
    return '${t.str('title')}  ·  $when';
  }

  /// Attività da fare (mie o di entrambi), le più urgenti prima.
  static Future<void> update({
    required String? coupleId,
    required List<Item> today,
    required String next,
  }) async {
    final list = today
        .take(8)
        .map((t) => {'id': t.id, 't': _dueLabel(t)})
        .toList();
    final count = today.isEmpty
        ? 'Attività · tutto fatto 🎉'
        : 'Attività · ${today.length} da fare';
    final json = jsonEncode(list);
    final sig = '$coupleId|$count|$json|$next';
    if (sig == _last) return;
    _last = sig;
    try {
      if (coupleId != null) {
        await HomeWidget.saveWidgetData<String>('coupleId', coupleId);
      }
      await HomeWidget.saveWidgetData<String>('count', count);
      await HomeWidget.saveWidgetData<String>('tasks_json', json);
      await HomeWidget.saveWidgetData<String>('next', next);
      await HomeWidget.updateWidget(androidName: 'UkeepWidget');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }

  static String _lastLists = '';
  static String _lastItems = '';

  /// Elenco delle liste (non segrete) tra cui il widget "Lista" può scegliere.
  /// Restituisce l'id della lista mostrata.
  static Future<String?> updateLists(List<Item> lists) async {
    final all = [
      for (final l in lists)
        if (!l.flag('locked'))
          {'id': l.id, 'name': l.str('name'), 'icon': l.str('icon', '📝')}
    ];
    try {
      final json = jsonEncode(all);
      if (json != _lastLists) {
        _lastLists = json;
        await HomeWidget.saveWidgetData<String>('wl_all', json);
      }
      var cur = await HomeWidget.getWidgetData<String>('wl_id');
      if (all.isEmpty) {
        await HomeWidget.saveWidgetData<String>('wl_title', 'Nessuna lista');
        await HomeWidget.saveWidgetData<String>('wl_items', '[]');
        await HomeWidget.updateWidget(androidName: 'UkeepListWidget');
        return null;
      }
      if (cur == null || !all.any((l) => l['id'] == cur)) {
        cur = all.first['id'];
        await HomeWidget.saveWidgetData<String>('wl_id', cur);
      }
      return cur;
    } catch (e) {
      debugPrint('Widget liste: $e');
      return null;
    }
  }

  /// Voci da prendere della lista mostrata nel widget.
  static Future<void> updateListItems(
      String listId, String title, List<Item> items) async {
    final open = items
        .where((i) => !i.flag('d'))
        .take(8)
        .map((i) {
          final q = ((i.data['q'] as num?) ?? 1).toInt();
          return {
            'id': i.id,
            't': q > 1 ? '${i.str('t')}  ×$q' : i.str('t'),
          };
        })
        .toList();
    final more = items.where((i) => !i.flag('d')).length - open.length;
    final json = jsonEncode(open);
    final sig = '$listId|$title|$json|$more';
    if (sig == _lastItems) return;
    _lastItems = sig;
    try {
      await HomeWidget.saveWidgetData<String>('wl_id', listId);
      await HomeWidget.saveWidgetData<String>('wl_title', title);
      await HomeWidget.saveWidgetData<String>('wl_items', json);
      await HomeWidget.saveWidgetData<String>(
          'wl_more', more > 0 ? 'e altre $more…' : '');
      await HomeWidget.updateWidget(androidName: 'UkeepListWidget');
    } catch (e) {
      debugPrint('Widget lista: $e');
    }
  }

  /// Chi sono io e chi è il partner (serve al widget "Ti penso").
  static Future<void> saveIdentity({
    required String? coupleId,
    required String? myUid,
    required String myName,
    required String? partnerUid,
    required String partnerName,
    required String partnerToken,
    required bool partnerOff,
  }) async {
    final sig =
        '$coupleId|$myUid|$myName|$partnerUid|$partnerName|$partnerToken|$partnerOff';
    if (sig == _lastId) return;
    _lastId = sig;
    try {
      if (coupleId != null) {
        await HomeWidget.saveWidgetData<String>('coupleId', coupleId);
      }
      await HomeWidget.saveWidgetData<String>('myUid', myUid ?? '');
      await HomeWidget.saveWidgetData<String>('myName', myName);
      await HomeWidget.saveWidgetData<String>('partnerUid', partnerUid ?? '');
      await HomeWidget.saveWidgetData<String>('partnerName', partnerName);
      await HomeWidget.saveWidgetData<String>('partnerToken', partnerToken);
      await HomeWidget.saveWidgetData<bool>('partnerOff', partnerOff);
      await HomeWidget.saveWidgetData<String>(
          'hug_label', 'Pensa a $partnerName');
      await HomeWidget.updateWidget(androidName: 'UkeepHugWidget');
    } catch (e) {
      debugPrint('Widget: $e');
    }
  }

  /// Stato del widget "Ti penso": idle, sent, recv.
  static Future<void> setHug(String state, {String? from}) async {
    try {
      final now = DateFormat('HH:mm').format(DateTime.now());
      await HomeWidget.saveWidgetData<String>('hug_state', state);
      if (state == 'recv') {
        await HomeWidget.saveWidgetData<String>(
            'hug_recv', '${from ?? 'Il partner'} ti pensa');
        await HomeWidget.saveWidgetData<String>(
            'hug_short', from ?? 'Ti pensa');
        await HomeWidget.saveWidgetData<String>('hug_time', 'alle $now');
      } else if (state == 'sent') {
        await HomeWidget.saveWidgetData<String>('hug_time', 'Inviato alle $now 💌');
      } else {
        await HomeWidget.saveWidgetData<String>('hug_time', '');
      }
      await HomeWidget.updateWidget(androidName: 'UkeepHugWidget');
    } catch (e) {
      debugPrint('Widget hug: $e');
    }
  }
}

Future<void> _bootFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  }
}

/// Manda l'abbraccio dal widget (app chiusa).
Future<bool> _hugFromWidget() async {
  final couple = await HomeWidget.getWidgetData<String>('coupleId');
  if (couple == null || couple.isEmpty) return false;
  await _bootFirebase();
  final repo = Repo(couple);
  await Push.instance.initForWidget();
  repo.add('hugs', {'at': FieldValue.serverTimestamp()});
  Feed.log(repo, icon: '🤗', text: 'ha mandato un abbraccio', push: false);
  return Push.instance.toPartner(
    title: '🤗 ${Push.instance.myName} ti pensa',
    body: 'Ti ha mandato un abbraccio',
    tag: 'hug',
    data: {'type': 'hug', 'from': Push.instance.myName},
  );
}

/// Arriva qui quando si tocca qualcosa nei widget.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  try {
    switch (uri.host) {
      case 'done':
        final id = uri.queryParameters['id'];
        if (id == null) return;
        // subito via dal widget, poi salvo
        final raw = await HomeWidget.getWidgetData<String>('tasks_json') ?? '[]';
        final list = (jsonDecode(raw) as List)
            .where((e) => (e as Map)['id'] != id)
            .toList();
        await HomeWidget.saveWidgetData<String>('tasks_json', jsonEncode(list));
        await HomeWidget.saveWidgetData<String>(
            'count',
            list.isEmpty
                ? 'Tutto fatto 🎉'
                : (list.length == 1
                    ? '1 cosa da fare oggi'
                    : '${list.length} cose da fare oggi'));
        await HomeWidget.updateWidget(androidName: 'UkeepWidget');
        final couple = await HomeWidget.getWidgetData<String>('coupleId');
        if (couple == null) return;
        await _bootFirebase();
        final repo = Repo(couple);
        final snap = await repo.col('tasks').doc(id).get();
        final data = snap.data();
        if (data != null && data['done'] != true) {
          await toggleTask(repo, Item(snap.id, data));
        }
        break;
      case 'litem':
        final l = uri.queryParameters['l'];
        final id = uri.queryParameters['id'];
        if (l == null || id == null) return;
        final raw =
            await HomeWidget.getWidgetData<String>('wl_items') ?? '[]';
        final list = (jsonDecode(raw) as List)
            .where((e) => (e as Map)['id'] != id)
            .toList();
        await HomeWidget.saveWidgetData<String>('wl_items', jsonEncode(list));
        await HomeWidget.updateWidget(androidName: 'UkeepListWidget');
        final couple = await HomeWidget.getWidgetData<String>('coupleId');
        if (couple == null) return;
        await _bootFirebase();
        await Repo(couple)
            .col('lists')
            .doc(l)
            .collection('items')
            .doc(id)
            .update({
          'd': true,
          'doneBy': FirebaseAuth.instance.currentUser?.uid,
          'doneAt': Timestamp.now(),
        });
        break;
      case 'nextlist':
        final raw = await HomeWidget.getWidgetData<String>('wl_all') ?? '[]';
        final all = (jsonDecode(raw) as List).cast<Map>();
        if (all.isEmpty) return;
        final cur = await HomeWidget.getWidgetData<String>('wl_id');
        var i = all.indexWhere((e) => e['id'] == cur);
        i = (i + 1) % all.length;
        final next = all[i];
        final id = '${next['id']}';
        final title = '${next['icon'] ?? '📝'} ${next['name'] ?? ''}';
        await HomeWidget.saveWidgetData<String>('wl_id', id);
        await HomeWidget.saveWidgetData<String>('wl_title', title);
        await HomeWidget.saveWidgetData<String>('wl_items', '[]');
        await HomeWidget.saveWidgetData<String>('wl_more', 'Carico…');
        await HomeWidget.updateWidget(androidName: 'UkeepListWidget');
        final couple = await HomeWidget.getWidgetData<String>('coupleId');
        if (couple == null) return;
        await _bootFirebase();
        final snap = await Repo(couple)
            .col('lists')
            .doc(id)
            .collection('items')
            .get();
        final items = snap.docs.map((d) => Item(d.id, d.data())).toList()
          ..sort((a, b) => ((a.data['o'] as num?) ?? 0)
              .compareTo((b.data['o'] as num?) ?? 0));
        WidgetSync._lastItems = '';
        await WidgetSync.updateListItems(id, title, items);
        break;
      case 'hug':
      case 'hugback':
        await WidgetSync.setHug('sent');
        await _hugFromWidget();
        break;
      case 'hugclear':
        await WidgetSync.setHug('idle');
        break;
    }
  } catch (e) {
    debugPrint('Widget callback: $e');
  }
}
