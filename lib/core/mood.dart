import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repo.dart';
import 'push.dart';
import 'theme.dart';

/// Umore del giorno: da triste a felice, arrabbiato, assonnato… e una cacca.
const moods = <List<String>>[
  ['😢', 'Triste'],
  ['😄', 'Felice'],
  ['😠', 'Arrabbiato'],
  ['😴', 'Assonnato'],
  ['💩', 'Una cacca'],
];

String moodLabel(String e) {
  for (final m in moods) {
    if (m[0] == e) return m[1];
  }
  return '';
}

String moodDayKey([DateTime? now]) =>
    DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

/// L'emoji di oggi di un membro, se l'ha scelta.
String? todayMood(Item? member) {
  final m = member?.data['mood'];
  if (m is Map && m['day'] == moodDayKey()) return m['e'] as String?;
  return null;
}

Item? _find(List<Item> members, String uid) {
  for (final m in members) {
    if (m.id == uid) return m;
  }
  return null;
}

/// La prima volta del giorno (dopo le 5:00) chiede come ti senti.
Future<void> maybeAskMood(
    BuildContext context, List<Item> members, String uid) async {
  final now = DateTime.now();
  if (now.hour < 5) return;
  if (todayMood(_find(members, uid)) != null) return;
  final key = moodDayKey(now);
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getString('moodAsked') == key) return;
    await p.setString('moodAsked', key);
  } catch (_) {}
  if (!context.mounted) return;
  await showMoodPicker(context, uid);
}

Future<void> showMoodPicker(BuildContext context, String uid) async {
  final e = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Come ti senti oggi?',
          textAlign: TextAlign.center, style: serif(26)),
      content: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 10,
        children: [
          for (final m in moods)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pop(ctx, m[0]),
              child: SizedBox(
                width: 68,
                child: Column(
                  children: [
                    Text(m[0], style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 4),
                    Text(m[1],
                        textAlign: TextAlign.center,
                        style: TextStyle(color: UColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dopo')),
      ],
    ),
  );
  if (e == null) return;
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'mood': {
      'e': e,
      'day': moodDayKey(),
      'at': FieldValue.serverTimestamp(),
    }
  }, SetOptions(merge: true));
  Push.instance.toPartner(
    title: '${Push.instance.myName} oggi si sente $e',
    body: moodLabel(e),
    tag: 'mood',
  );
}

/// Abbraccio: lo salva (così si vede in Home) e lo manda al partner.
Future<void> sendHug(BuildContext context, Repo repo) async {
  final m = ScaffoldMessenger.maybeOf(context);
  repo.add('hugs', {'at': FieldValue.serverTimestamp()});
  final ok = await Push.instance.toPartner(
    title: '🤗 ${Push.instance.myName} ti pensa',
    body: 'Ti ha mandato un abbraccio',
    tag: 'hug',
  );
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Abbraccio inviato a ${Push.instance.partnerName} 🤗'
          : 'Abbraccio salvato: ${Push.instance.partnerName} lo vedrà aprendo Ukeep')));
}
