import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';

import 'theme.dart';

/// Segmento selezionato nella scheda "Liste" (0 liste, 1 desideri, 2 progetti).
/// Serve alla Home per aprire direttamente la sezione giusta.
final ValueNotifier<int> listsSegment = ValueNotifier<int>(0);

class GradientBg extends StatelessWidget {
  const GradientBg({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UColors.bgTop, UColors.bgMid, UColors.bgBottom],
          ),
        ),
        child: child,
      );
}

class UCard extends StatelessWidget {
  const UCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.onLongPress,
    this.color,
    this.margin = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? UColors.card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: serif(40)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!,
                        style: TextStyle(
                            color: UColors.muted, fontSize: 15)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Row(
          children: [
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: UColors.rose),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: UColors.muted, fontSize: 15)),
          ],
        ),
      );
}

class UAvatar extends StatelessWidget {
  const UAvatar({super.key, this.name, this.photo, this.b64, this.size = 40});
  final String? name;
  final String? photo;
  final String? b64;
  final double size;

  factory UAvatar.member(Item? m, {double size = 40}) => UAvatar(
        name: m?.str('name'),
        photo: m?.str('photo'),
        b64: m?.str('photoB64'),
        size: size,
      );

  ImageProvider? _image() {
    if (b64 != null && b64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(b64!));
      } catch (_) {}
    }
    if (photo != null && photo!.isNotEmpty) return NetworkImage(photo!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    final img = _image();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: UColors.rose.withAlpha(120),
      backgroundImage: img,
      child: img == null
          ? Text(initial,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: size * .4,
                  color: UColors.ink))
          : null,
    );
  }
}

ButtonStyle get pillStyle => FilledButton.styleFrom(
  backgroundColor: UColors.dark,
  foregroundColor: UColors.onDark,
  shape: const StadiumBorder(),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

Widget pillFab({
  required VoidCallback onPressed,
  required String label,
  IconData icon = Icons.add,
}) =>
    FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: UColors.dark,
      foregroundColor: UColors.onDark,
      elevation: 2,
      shape: const StadiumBorder(),
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );

Future<T?> showUSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
    backgroundColor: UColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final bottom = (mq.viewInsets.bottom > mq.viewPadding.bottom
              ? mq.viewInsets.bottom
              : mq.viewPadding.bottom) +
          24;
      return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: UColors.muted.withAlpha(90),
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            child,
          ],
        ),
      ),
    );
    },
  );
}

InputDecoration fieldDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: UColors.bgMid.withAlpha(160),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
    );

Future<bool> confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Elimina',
                style: TextStyle(color: UColors.danger))),
      ],
    ),
  );
  return r ?? false;
}

// ---------------------------------------------------------------- date utils

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String fmtDay(DateTime d) => DateFormat('d MMM', 'it_IT').format(d);

/// "Oggi", "Domani", "Ieri", "Tra 3 giorni" oppure "20 ott".
String relDay(DateTime d, {bool far = false}) {
  final diff = dayOnly(d).difference(dayOnly(DateTime.now())).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Domani';
  if (diff == -1) return 'Ieri';
  if (far && diff > 1) return 'Tra $diff giorni';
  return fmtDay(d);
}

/// Spazio da lasciare in fondo per non finire sotto i tasti di sistema.
double bottomInset(BuildContext context) =>
    MediaQuery.of(context).viewPadding.bottom;

/// "Insieme da 5 anni, 2 mesi e 3 giorni" in base alla data di inizio.
String togetherText(DateTime since, {DateTime? now}) {
  final n = dayOnly(now ?? DateTime.now());
  final s = dayOnly(since);
  var y = n.year - s.year;
  var m = n.month - s.month;
  var d = n.day - s.day;
  if (d < 0) {
    m -= 1;
    d += DateTime(n.year, n.month, 0).day;
  }
  if (m < 0) {
    y -= 1;
    m += 12;
  }
  final parts = <String>[
    if (y > 0) '$y ${y == 1 ? 'anno' : 'anni'}',
    if (m > 0) '$m ${m == 1 ? 'mese' : 'mesi'}',
    if (d > 0) '$d ${d == 1 ? 'giorno' : 'giorni'}',
  ];
  if (parts.isEmpty) return 'Insieme da oggi';
  if (parts.length == 1) return 'Insieme da ${parts[0]}';
  if (parts.length == 2) return 'Insieme da ${parts[0]} e ${parts[1]}';
  return 'Insieme da ${parts[0]}, ${parts[1]} e ${parts[2]}';
}

/// Schermata vuota con un po' di carattere.
class EmptyCard extends StatelessWidget {
  const EmptyCard(
      {super.key,
      required this.emoji,
      required this.title,
      required this.text});
  final String emoji;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: UCard(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [UColors.bgTop, UColors.bgBottom],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: serif(26)),
                const SizedBox(height: 8),
                Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: UColors.muted, fontSize: 15)),
              ],
            ),
          ),
        ),
      );
}

/// Pillola di scelta rapida (modelli di liste e progetti).
Widget templateChip(String emoji, String label, VoidCallback onTap) =>
    ActionChip(
      avatar: Text(emoji, style: const TextStyle(fontSize: 18)),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: UColors.card,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );

/// Menu contestuale (pressione lunga): Apri / Modifica / Elimina.
/// Dopo l'eliminazione compare "Annulla".
Future<void> itemMenu(
  BuildContext context, {
  required String title,
  VoidCallback? onOpen,
  String openLabel = 'Apri',
  VoidCallback? onEdit,
  String editLabel = 'Modifica',
  VoidCallback? onDelete,
}) async {
  HapticFeedback.mediumImpact();
  final action = await showUSheet<String>(
    context,
    Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: serif(24)),
          const SizedBox(height: 10),
          if (onOpen != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: Text(openLabel),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
          if (onEdit != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: Text(editLabel),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          if (onDelete != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: UColors.danger),
              title: Text('Elimina',
                  style: TextStyle(color: UColors.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'open':
      onOpen?.call();
    case 'edit':
      onEdit?.call();
    case 'delete':
      onDelete?.call();
  }
}

/// Finestrella per rinominare un testo. Restituisce il nuovo testo o null.
Future<String?> askText(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: UColors.surface,
      title: Text(title, style: serif(24)),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: fieldDeco('Testo'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Salva')),
      ],
    ),
  );
}
