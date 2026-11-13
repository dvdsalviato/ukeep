import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repo.dart';
import 'push.dart';
import 'theme.dart';
import 'ui.dart';

/// Diario delle novità: "Giulia ha aggiunto latte alla Spesa".
/// feed/{id}: by, icon, text (alla terza persona: "ha aggiunto …"), at.
/// Ogni voce può anche mandare la notifica al partner.
class Feed {
  Feed._();

  static Future<void> log(
    Repo? repo, {
    required String icon,
    required String text,
    String? textMe,
    bool push = true,
    String? pushTitle,
    String? tag,
    String? body,
  }) async {
    if (repo == null) return;
    repo.col('feed').add({
      'by': FirebaseAuth.instance.currentUser?.uid,
      'icon': icon,
      'text': text,
      if (textMe != null) 'textMe': textMe,
      'at': FieldValue.serverTimestamp(),
    });
    if (push) {
      Push.instance.toPartner(
        title: pushTitle ?? '$icon ${Push.instance.myName} $text',
        body: body ?? 'Apri Ukeep',
        tag: tag,
      );
    }
  }
}

final feedProvider = StreamProvider<List<Item>>((ref) {
  final repo = ref.watch(repoProvider);
  if (repo == null) return Stream.value(<Item>[]);
  return repo
      .col('feed')
      .orderBy('at', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => Item(d.id, d.data())).toList());
});

String _first(List<Item> members, String uid) {
  for (final m in members) {
    if (m.id == uid) {
      final n = m.str('name').trim();
      return n.isEmpty ? 'Il partner' : n.split(' ').first;
    }
  }
  return 'Il partner';
}

/// "Hai aggiunto…" per me, "Giulia ha aggiunto…" per il partner.
String feedSentence(Item f, List<Item> members, String? me) {
  final t = f.str('text');
  if (f.str('by') == me) {
    if (f.str('textMe').isNotEmpty) return f.str('textMe');
    return t.startsWith('ha ') ? 'Hai ${t.substring(3)}' : 'Tu: $t';
  }
  return '${_first(members, f.str('by'))} $t';
}

String feedWhen(DateTime? d) {
  if (d == null) return 'ora';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'ora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24 && sameDay(d, DateTime.now())) {
    return 'oggi ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 7) return relDay(d);
  return fmtDay(d);
}

class FeedRow extends StatelessWidget {
  const FeedRow(
      {super.key, required this.f, required this.members, required this.me});
  final Item f;
  final List<Item> members;
  final String? me;

  @override
  Widget build(BuildContext context) {
    Item? who;
    for (final m in members) {
      if (m.id == f.str('by')) who = m;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UAvatar.member(who, size: 34),
              Positioned(
                right: -6,
                bottom: -4,
                child: Text(f.str('icon'),
                    style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feedSentence(f, members, me),
                    style: const TextStyle(fontSize: 15, height: 1.25)),
                const SizedBox(height: 2),
                Text(feedWhen(f.date('at')),
                    style: TextStyle(color: UColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tutte le novità.
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Novità')),
      body: feed.isEmpty
          ? const EmptyHint(Icons.forum_outlined,
              'Qui vedrete tutto quello che fate in Ukeep, tu e il partner.')
          : ListView(
              padding:
                  EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset(context)),
              children: [
                UCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      for (final f in feed)
                        FeedRow(f: f, members: members, me: me),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
