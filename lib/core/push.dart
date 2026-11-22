import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:home_widget/home_widget.dart';

import '../data/repo.dart';
import 'notifications.dart';
import 'widget_sync.dart';

/// Notifiche push al telefono del partner (abbraccio, "X ha aggiunto…").
///
/// Ogni telefono salva il proprio token in users/{uid}.fcmToken.
/// Per inviare serve la chiave di un account di servizio Google con il solo
/// permesso di mandare notifiche: viene messa nell'app durante la build
/// (assets/fcm_sa.json, dal secret FCM_SA_B64). Se manca, le push sono spente
/// e tutto il resto funziona lo stesso.
class Push {
  Push._();
  static final Push instance = Push._();

  final _db = FirebaseFirestore.instance;
  String? _uid;
  List<Item> _members = [];
  Map<String, dynamic>? _sa;
  AutoRefreshingAuthClient? _client;
  bool _inited = false;

  /// L'utente vuole ricevere gli avvisi dal partner.
  final ValueNotifier<bool> receive = ValueNotifier<bool>(true);

  bool get configured => _sa != null;

  /// Perché l'ultima notifica al partner non è partita (per la prova).
  String lastError = '';

  /// Manda una notifica di prova e spiega com'è andata.
  Future<String> testPartner() async {
    final ok = await toPartner(
        title: '🔔 Prova da $myName',
        body: 'Se la vedi, le notifiche tra voi funzionano',
        tag: 'test');
    if (ok) {
      return 'Partita! Se $partnerName non la riceve con l\'app chiusa, '
          'sul suo telefono va tolto il risparmio batteria per Ukeep.';
    }
    switch (lastError) {
      case 'no_partner':
        return 'Il partner non è ancora entrato nel vostro spazio.';
      case 'off':
        return '$partnerName ha spento gli avvisi dal partner.';
      case 'no_token':
        return '$partnerName deve aprire Ukeep (versione nuova) almeno una volta.';
      case 'web':
        return 'Dalla versione web le notifiche non partono: prova dall\'app.';
      case 'no_key':
        return 'Manca la chiave per le notifiche nella build (secret FCM_SA_B64).';
      case 'unregistered':
        return 'Il telefono di $partnerName va riaperto: deve aprire Ukeep una volta.';
      case 'forbidden':
        return 'Google rifiuta l\'invio: controlla che l\'API "Firebase Cloud '
            'Messaging" sia attiva e che la chiave abbia il ruolo giusto.';
    }
    return 'Non partita: $lastError';
  }

  Item? get _me {
    for (final m in _members) {
      if (m.id == _uid) return m;
    }
    return null;
  }

  Item? get partner {
    for (final m in _members) {
      if (m.id != _uid) return m;
    }
    return null;
  }

  String _first(Item? m, String fallback) {
    final n = (m?.str('name') ?? '').trim();
    return n.isEmpty ? fallback : n.split(' ').first;
  }

  String get myName => _first(_me, 'Il partner');
  String get partnerName => _first(partner, 'il partner');

  void setMembers(List<Item> members, String? uid, {String? coupleId}) {
    _members = members;
    _uid = uid;
    final me = _me;
    if (me != null) receive.value = me.data['pushOff'] != true;
    final p = partner;
    WidgetSync.saveIdentity(
      coupleId: coupleId,
      myUid: uid,
      myName: myName,
      partnerUid: p?.id,
      partnerName: partnerName,
      partnerToken: p?.str('fcmToken') ?? '',
      partnerOff: p?.data['pushOff'] == true,
    );
  }

  Future<void> _loadKey() async {
    if (_sa != null) return;
    try {
      final raw = await rootBundle.loadString('assets/fcm_sa.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['client_email'] != null && j['private_key'] != null) _sa = j;
    } catch (_) {
      _sa = null;
    }
  }

  /// Per il widget (app chiusa): ricostruisce chi siamo dai dati salvati.
  Future<void> initForWidget() async {
    await _loadKey();
    final myUid = await HomeWidget.getWidgetData<String>('myUid') ?? '';
    final pUid = await HomeWidget.getWidgetData<String>('partnerUid') ?? '';
    final myN = await HomeWidget.getWidgetData<String>('myName') ?? '';
    final pN = await HomeWidget.getWidgetData<String>('partnerName') ?? '';
    final tok = await HomeWidget.getWidgetData<String>('partnerToken') ?? '';
    final off = await HomeWidget.getWidgetData<bool>('partnerOff') ?? false;
    _uid = myUid;
    _members = [
      Item(myUid, {'name': myN}),
      if (pUid.isNotEmpty)
        Item(pUid, {'name': pN, 'fcmToken': tok, 'pushOff': off}),
    ];
  }

  Future<void> init(String uid) async {
    _uid = uid;
    // sul web niente push: l'app web non riceve notifiche
    if (_inited || kIsWeb) return;
    _inited = true;
    await _loadKey();
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      if (token != null) await _saveToken(token);
      fm.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          NotifService.instance.showPartner(n.title ?? 'Ukeep', n.body ?? '');
        }
        if (m.data['type'] == 'hug') {
          WidgetSync.setHug('recv', from: m.data['from']);
        }
      });
    } catch (e) {
      debugPrint('Push init: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> setReceive(bool on) async {
    receive.value = on;
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'pushOff': !on}, SetOptions(merge: true));
  }

  Future<AutoRefreshingAuthClient?> _auth() async {
    if (_client != null) return _client;
    final sa = _sa;
    if (sa == null) return null;
    final creds = ServiceAccountCredentials.fromJson(sa);
    _client = await clientViaServiceAccount(
        creds, ['https://www.googleapis.com/auth/firebase.messaging']);
    return _client;
  }

  /// Manda una notifica al partner. Restituisce true se è partita.
  /// [tag]: notifiche con lo stesso tag si sostituiscono (niente pioggia).
  Future<bool> toPartner(
      {required String title,
      required String body,
      String? tag,
      Map<String, String>? data}) async {
    try {
      final p = partner;
      if (p == null) {
        lastError = 'no_partner';
        return false;
      }
      if (p.data['pushOff'] == true) {
        lastError = 'off';
        return false;
      }
      final token = p.str('fcmToken');
      if (token.isEmpty) {
        lastError = 'no_token';
        return false;
      }
      if (kIsWeb) {
        lastError = 'web';
        return false;
      }
      final client = await _auth();
      final sa = _sa;
      if (client == null || sa == null) {
        lastError = 'no_key';
        return false;
      }
      final project = sa['project_id'] as String;
      final res = await client.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$project/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            if (data != null) 'data': data,
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id': 'ukeep_partner',
                'icon': 'ic_stat',
                'color': '#B9743C',
                if (tag != null) 'tag': tag,
              },
            },
          },
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('Push ${res.statusCode}: ${res.body}');
        lastError = res.body.contains('UNREGISTERED') || res.statusCode == 404
            ? 'unregistered'
            : (res.statusCode == 403
                ? 'forbidden'
                : 'errore ${res.statusCode}');
      } else {
        lastError = '';
      }
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Push: $e');
      lastError = '$e';
      return false;
    }
  }
}

/// Notifiche push arrivate con l'app chiusa: aggiorna il widget "Ti penso".
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage m) async {
  if (m.data['type'] == 'hug') {
    await WidgetSync.setHug('recv', from: m.data['from']);
  }
}
