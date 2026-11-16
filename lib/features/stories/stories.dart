import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/feed.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../calendar/calendar_page.dart';

/// Una "storia": conto alla rovescia verso una data o un ricordo.
class Story {
  Story.countdown(this.item, this.when)
      : memory = false;
  Story.memory(this.item, this.when) : memory = true;
  final Item item;
  final DateTime when;
  final bool memory;

  String get title => item.str('title');

  String get emoji {
    if (memory) return '📸';
    switch (item.str('type')) {
      case 'birthday':
        return '🎂';
      case 'anniversary':
        return '💞';
      case 'medical':
        return '🩺';
    }
    return '📅';
  }

  /// Etichetta sotto il cerchio.
  String get short {
    final today = dayOnly(DateTime.now());
    final d = when.difference(today).inDays;
    if (!memory) {
      if (d == 0) return 'Oggi!';
      if (d == 1) return 'Domani';
      return '-$d g';
    }
    return agoText(when);
  }
}

String agoText(DateTime when) {
  final today = dayOnly(DateTime.now());
  final d = today.difference(dayOnly(when)).inDays;
  if (d <= 0) return 'Oggi';
  if (d == 1) return 'Ieri';
  if (d < 31) return '$d giorni fa';
  final months = (today.year - when.year) * 12 + today.month - when.month;
  if (months < 12) return months <= 1 ? '1 mese fa' : '$months mesi fa';
  final years = months ~/ 12;
  return years == 1 ? '1 anno fa' : '$years anni fa';
}

List<Story> buildStories(List<Item> events, List<Item> memories) {
  final today = dayOnly(DateTime.now());
  final count = <Story>[];
  for (final e in events) {
    final n = nextOccurrence(e, today);
    if (n != null && n.difference(today).inDays <= 365) {
      count.add(Story.countdown(e, n));
    }
  }
  count.sort((a, b) => a.when.compareTo(b.when));
  final mem = <Story>[
    for (final m in memories)
      if (m.date('date') != null) Story.memory(m, m.date('date')!)
  ]..sort((a, b) => b.when.compareTo(a.when));
  return [...count.take(10), ...mem];
}

/// Riga di cerchi in Home, come le storie.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final events = ref.watch(eventsProvider).value ?? [];
    final memories = ref.watch(memoriesProvider).value ?? [];
    final stories = buildStories(events, memories);
    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Bubble(
            label: 'Aggiungi',
            ring: false,
            onTap: repo == null ? null : () => _addSheet(context, repo),
            child: Icon(Icons.add, color: UColors.ink, size: 28),
          ),
          for (var i = 0; i < stories.length; i++)
            _Bubble(
              label: stories[i].short,
              highlight: !stories[i].memory &&
                  stories[i].when.difference(dayOnly(DateTime.now())).inDays <=
                      7,
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) =>
                    StoryViewer(stories: stories, start: i),
                transitionsBuilder: (_, a, __, child) =>
                    FadeTransition(opacity: a, child: child),
              )),
              child: _thumb(stories[i]),
            ),
        ],
      ),
    );
  }

  Widget _thumb(Story s) {
    final b64 = s.item.str('photoB64');
    if (s.memory && b64.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(base64Decode(b64),
              width: 60, height: 60, fit: BoxFit.cover, gaplessPlayback: true),
        );
      } catch (_) {}
    }
    return Text(s.emoji, style: const TextStyle(fontSize: 28));
  }

  void _addSheet(BuildContext context, Repo repo) {
    showUSheet(
      context,
      Builder(
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Aggiungi una storia', style: serif(26)),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('⏳', style: TextStyle(fontSize: 26)),
              title: const Text('Conto alla rovescia'),
              subtitle: const Text('Una data importante che sta arrivando'),
              onTap: () {
                Navigator.pop(ctx);
                showEventSheet(context, repo);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('📸', style: TextStyle(fontSize: 26)),
              title: const Text('Ricordo'),
              subtitle: const Text('Una foto e due righe da rivedere'),
              onTap: () {
                Navigator.pop(ctx);
                showMemorySheet(context, repo);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.label,
      required this.child,
      this.onTap,
      this.ring = true,
      this.highlight = false});
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool ring;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ring
                      ? LinearGradient(
                          colors: highlight
                              ? [UColors.danger, UColors.accent]
                              : [UColors.rose, UColors.lilac],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  border: ring
                      ? null
                      : Border.all(color: UColors.muted.withAlpha(90)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: UColors.surface),
                  child: child,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                      color: highlight ? UColors.danger : UColors.muted)),
            ],
          ),
        ),
      );
}

/// Visualizzatore a schermo intero, con le barre che avanzano.
class StoryViewer extends ConsumerStatefulWidget {
  const StoryViewer({super.key, required this.stories, required this.start});
  final List<Story> stories;
  final int start;

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer>
    with SingleTickerProviderStateMixin {
  late int _i = widget.start;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    })
    ..forward();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _next() {
    if (_i < widget.stories.length - 1) {
      setState(() => _i++);
      _c.forward(from: 0);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
    _c.forward(from: 0);
  }

  static const _ink = Color(0xFF2A2430);

  String _countdown(DateTime when) {
    final now = DateTime.now();
    final d = when.difference(dayOnly(now)).inDays;
    if (d <= 0) return 'È oggi!';
    final left = when.difference(now);
    final h = left.inHours % 24;
    final m = left.inMinutes % 60;
    final s = left.inSeconds % 60;
    return '${left.inDays} g  ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stories[_i];
    final b64 = s.item.str('photoB64');
    Uint8List? photo;
    if (s.memory && b64.isNotEmpty) {
      try {
        photo = base64Decode(b64);
      } catch (_) {}
    }
    final onPhoto = photo != null;
    final fg = onPhoto ? Colors.white : _ink;
    final days = s.when.difference(dayOnly(DateTime.now())).inDays;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          d.globalPosition.dx < w / 3 ? _prev() : _next();
        },
        onLongPressStart: (_) => _c.stop(),
        onLongPressEnd: (_) => _c.forward(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFD9CC),
                      Color(0xFFF3D5EE),
                      Color(0xFFDCD0F5)
                    ],
                  ),
                ),
              ),
            if (onPhoto)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x88000000), Color(0x00000000), Color(0xCC000000)],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var k = 0; k < widget.stories.length; k++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: AnimatedBuilder(
                                animation: _c,
                                builder: (_, __) => LinearProgressIndicator(
                                  value: k < _i
                                      ? 1
                                      : (k == _i ? _c.value : 0),
                                  minHeight: 3,
                                  backgroundColor: fg.withAlpha(60),
                                  color: fg,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        const Spacer(),
                        if (s.memory)
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: fg),
                            onPressed: () {
                              final repo = ref.read(repoProvider);
                              if (repo == null) return;
                              deleteItem(context, repo, 'memories', s.item);
                              Navigator.of(context).maybePop();
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.close, color: fg),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: s.memory
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(agoText(s.when),
                                    style: TextStyle(
                                        color: fg.withAlpha(200),
                                        fontSize: 15,
                                        letterSpacing: 1)),
                                const SizedBox(height: 6),
                                Text(s.title,
                                    style: serif(40,
                                        style: FontStyle.italic, color: fg)),
                                const SizedBox(height: 6),
                                Text(
                                    DateFormat('d MMMM y', 'it_IT')
                                        .format(s.when),
                                    style: TextStyle(
                                        color: fg.withAlpha(200),
                                        fontSize: 15)),
                                if (s.item.str('text').isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(s.item.str('text'),
                                      style: TextStyle(
                                          color: fg, fontSize: 17, height: 1.35)),
                                ],
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.emoji,
                                    style: const TextStyle(fontSize: 54)),
                                const SizedBox(height: 10),
                                Text(s.title, style: serif(40, color: fg)),
                                const SizedBox(height: 8),
                                Text(
                                    capitalize(DateFormat('EEEE d MMMM y',
                                            'it_IT')
                                        .format(s.when)),
                                    style: TextStyle(
                                        color: fg.withAlpha(190),
                                        fontSize: 16)),
                                const SizedBox(height: 30),
                                Text(days <= 0 ? '🎉' : 'Mancano',
                                    style: TextStyle(
                                        color: fg.withAlpha(190),
                                        fontSize: 18)),
                                Text(
                                    days <= 0
                                        ? 'È oggi!'
                                        : (days == 1 ? '1 giorno' : '$days giorni'),
                                    style: serif(72,
                                        style: FontStyle.italic,
                                        color: fg)),
                                const SizedBox(height: 6),
                                if (days > 0)
                                  Text(_countdown(s.when),
                                      style: TextStyle(
                                          color: fg.withAlpha(200),
                                          fontSize: 18,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ])),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- ricordi

Future<void> showMemorySheet(BuildContext context, Repo repo) =>
    showUSheet(context, _MemoryForm(repo: repo));

Uint8List _shrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final d = img.bakeOrientation(decoded);
  var r = d.width > 1080 ? img.copyResize(d, width: 1080) : d;
  var out = img.encodeJpg(r, quality: 72);
  if (out.length > 550000) {
    r = img.copyResize(d, width: 780);
    out = img.encodeJpg(r, quality: 62);
  }
  return Uint8List.fromList(out);
}

class _MemoryForm extends StatefulWidget {
  const _MemoryForm({required this.repo});
  final Repo repo;

  @override
  State<_MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<_MemoryForm> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  DateTime _date = DateTime.now();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker()
        .pickImage(source: src, maxWidth: 2000, imageQuality: 90);
    if (x == null) return;
    setState(() => _busy = true);
    final bytes = await x.readAsBytes();
    final small = await compute(_shrink, bytes);
    if (!mounted) return;
    setState(() {
      _photo = small;
      _busy = false;
    });
  }

  void _save() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dai un titolo al ricordo')));
      return;
    }
    widget.repo.add('memories', {
      'title': t,
      'text': _text.text.trim(),
      'date': Timestamp.fromDate(dayOnly(_date)),
      if (_photo != null) 'photoB64': base64Encode(_photo!),
    });
    Feed.log(widget.repo,
        icon: '📸', text: 'ha aggiunto un ricordo: $t', tag: 'memories');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Nuovo ricordo', style: serif(28)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _busy ? null : () => _pick(ImageSource.gallery),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: UColors.bgMid,
              borderRadius: BorderRadius.circular(22),
              image: _photo == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(_photo!), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: _busy
                ? const CircularProgressIndicator()
                : (_photo == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: UColors.muted),
                          const SizedBox(height: 6),
                          Text('Scegli una foto (facoltativa)',
                              style: TextStyle(color: UColors.muted)),
                        ],
                      )
                    : null),
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Scatta'),
            ),
            if (_photo != null)
              TextButton(
                onPressed: () => setState(() => _photo = null),
                child: const Text('Togli foto'),
              ),
          ],
        ),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Titolo', hint: 'Es. Il primo viaggio'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Due righe (facoltative)'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.event, size: 18),
            label: Text(fmtDay(_date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
            style: pillStyle,
            onPressed: _busy ? null : _save,
            child: const Text('Salva ricordo')),
      ],
    );
  }
}
