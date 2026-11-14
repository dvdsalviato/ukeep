import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed.dart';
import '../../core/push.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../tasks/tasks_page.dart';

/// Post-it "appiccicati" in Home.
/// notes/{id}: text, by, color (indice), read, at, readAt.
const postItColors = <List<Color>>[
  [Color(0xFFFFF3A6), Color(0xFFFFE780)], // giallo
  [Color(0xFFFFD6E0), Color(0xFFFFC2D1)], // rosa
  [Color(0xFFCDEBFF), Color(0xFFB5E0FF)], // azzurro
  [Color(0xFFD5F5C8), Color(0xFFBFEDAE)], // verde
];

const _noteInk = Color(0xFF3A3326);

final notesProvider = StreamProvider<List<Item>>((ref) {
  final repo = ref.watch(repoProvider);
  if (repo == null) return Stream.value(<Item>[]);
  return repo
      .col('notes')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map((d) => Item(d.id, d.data())).toList()
        ..sort((a, b) => (a.date('at') ?? DateTime(2100))
            .compareTo(b.date('at') ?? DateTime(2100))));
});

/// Scrivi un post-it per il partner.
Future<void> writePostIt(BuildContext context, Repo repo,
    {String? replyTo}) async {
  final text = TextEditingController();
  var color = Random().nextInt(postItColors.length);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -0.03,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: postItColors[color],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(2, 8))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📌', style: TextStyle(fontSize: 22)),
                    if (replyTo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Risposta a: "$replyTo"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: _noteInk.withAlpha(140), fontSize: 12)),
                      ),
                    TextField(
                      controller: text,
                      autofocus: true,
                      maxLength: 140,
                      maxLines: 4,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                          fontFamily: 'cursive',
                          fontSize: 26,
                          color: _noteInk,
                          height: 1.2),
                      cursorColor: _noteInk,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Scrivi qualcosa…',
                        hintStyle: TextStyle(
                            fontFamily: 'cursive',
                            fontSize: 26,
                            color: _noteInk.withAlpha(110)),
                        counterStyle:
                            TextStyle(color: _noteInk.withAlpha(120)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < postItColors.length; i++)
                  GestureDetector(
                    onTap: () => setS(() => color = i),
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: postItColors[i][0],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color == i
                                ? Colors.white
                                : Colors.white.withAlpha(90),
                            width: color == i ? 3 : 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _noteInk,
                      shape: const StadiumBorder()),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Text('📌'),
                  label: const Text('Attacca'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  final t = text.text.trim();
  text.dispose();
  if (ok != true || t.isEmpty) return;
  repo.add('notes', {
    'text': t,
    'color': color,
    'read': false,
    'at': FieldValue.serverTimestamp(),
  });
  Feed.log(repo,
      icon: '📝',
      text: 'ha lasciato un post-it: "$t"',
      pushTitle: '📝 ${Push.instance.myName} ti ha lasciato un post-it',
      body: t,
      tag: 'note');
}

/// Il post-it appiccicato in mezzo alla Home (solo quelli per me, non letti).
class StuckPostIt extends ConsumerWidget {
  const StuckPostIt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final repo = ref.watch(repoProvider);
    final members = ref.watch(membersProvider).value ?? [];
    final notes = (ref.watch(notesProvider).value ?? [])
        .where((n) => n.str('by') != me)
        .toList();
    if (notes.isEmpty || repo == null) return const SizedBox.shrink();
    final n = notes.first;
    final colors = postItColors[
        ((n.data['color'] as num?) ?? 0).toInt() % postItColors.length];
    final from = firstName(memberById(members, n.str('by'))?.str('name'));
    final at = n.date('at');

    void peel() {
      repo.update('notes', n.id,
          {'read': true, 'readAt': FieldValue.serverTimestamp()});
      Feed.log(repo,
          icon: '👍',
          text: 'ha staccato il post-it',
          textMe: 'Hai staccato il post-it di ${from.isEmpty ? 'il partner' : from}',
          pushTitle: '👍 ${Push.instance.myName} ha letto il tuo post-it',
          body: n.str('text'),
          tag: 'note');
    }

    return Dismissible(
      key: ValueKey(n.id),
      onDismissed: (_) => peel(),
      child: Transform.rotate(
        angle: (n.id.hashCode % 7 - 3) / 100,
        child: Container(
          width: 270,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 18,
                  offset: Offset(3, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('📌', style: TextStyle(fontSize: 22)),
                  const Spacer(),
                  if (notes.length > 1)
                    Text('+${notes.length - 1}',
                        style: TextStyle(
                            color: _noteInk.withAlpha(150),
                            fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Text(n.str('text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'cursive',
                      fontSize: 28,
                      color: _noteInk,
                      height: 1.15)),
              const SizedBox(height: 8),
              Text(
                  '— ${from.isEmpty ? 'il partner' : from}${at == null ? '' : ', ${feedWhen(at)}'}',
                  style:
                      TextStyle(color: _noteInk.withAlpha(150), fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _noteInk),
                    onPressed: () {
                      peel();
                      writePostIt(context, repo, replyTo: n.str('text'));
                    },
                    child: const Text('Rispondi'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _noteInk),
                    onPressed: peel,
                    child: const Text('Staccalo ✓'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
