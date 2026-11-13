import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/repo.dart';
import 'theme.dart';

/// Avviso "Eliminato · Annulla" con una linea del tempo che si esaurisce.
/// Si può trascinare a destra o a sinistra per toglierlo.
void showUndo(BuildContext context, String message, VoidCallback onUndo,
    {Duration duration = const Duration(seconds: 4)}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    duration: duration,
    dismissDirection: DismissDirection.horizontal,
    padding: EdgeInsets.zero,
    content: _UndoContent(
      message: message,
      duration: duration,
      onUndo: () {
        m.hideCurrentSnackBar();
        onUndo();
      },
    ),
  ));
}

class _UndoContent extends StatelessWidget {
  const _UndoContent(
      {required this.message, required this.duration, required this.onUndo});
  final String message;
  final Duration duration;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: UColors.onDark, fontSize: 15)),
                ),
                TextButton(
                  onPressed: onUndo,
                  child: Text('Annulla',
                      style: TextStyle(
                          color: UColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: duration,
            builder: (context, v, _) => ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: Colors.transparent,
                color: UColors.accent,
              ),
            ),
          ),
        ],
      );
}

/// Elimina un documento e offre "Annulla" (lo riscrive identico).
void deleteDocWithUndo(BuildContext context,
    DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data,
    {String? label}) {
  ref.delete();
  showUndo(
      context,
      label == null || label.isEmpty ? 'Eliminato' : 'Eliminato "$label"',
      () => ref.set(data));
}

/// Scorciatoia per gli elementi delle collezioni della coppia.
void deleteItem(BuildContext context, Repo repo, String col, Item it,
        {String? label}) =>
    deleteDocWithUndo(context, repo.col(col).doc(it.id), it.data,
        label: label ?? it.str('title', it.str('name')));
