import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'theme.dart';
import 'ui.dart';

/// Cambia la foto profilo: scegli o scatta, poi la centri nel tondo.
/// L'immagine finale (320 px, JPEG) viene salvata nel documento utente
/// su Firestore, senza bisogno di altri servizi.
Future<void> changeProfilePhoto(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final choice = await showUSheet<String>(
    context,
    Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Foto profilo', style: serif(28)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli dalla galleria'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Scatta una foto'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: UColors.danger),
            title: const Text('Rimuovi foto',
                style: TextStyle(color: UColors.danger)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  if (choice == 'remove') {
    ref.set({'photoB64': FieldValue.delete()}, SetOptions(merge: true));
    return;
  }
  try {
    final x = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!context.mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropPage(bytes: bytes)));
    if (cropped == null) return;
    ref.set({'photoB64': base64Encode(cropped)}, SetOptions(merge: true));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Foto non caricata: $e')));
    }
  }
}

/// Anteprima per centrare la foto: trascina e pizzica per ingrandire.
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<PhotoCropPage> {
  final _boundaryKey = GlobalKey();
  final _controller = TransformationController();
  double? _w;
  double? _h;
  bool _centered = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _w = frame.image.width.toDouble();
      _h = frame.image.height.toDouble();
    });
  }

  Future<void> _done(double side) async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 320 / side);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final decoded = img.decodePng(data!.buffer.asUint8List());
      final jpg = img.encodeJpg(decoded!, quality: 82);
      if (mounted) Navigator.pop(context, Uint8List.fromList(jpg));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final side = math.min(MediaQuery.of(context).size.width - 48, 340.0);
    final w = _w;
    final h = _h;
    return Scaffold(
      appBar: AppBar(title: const Text('Centra la foto')),
      body: (w == null || h == null)
          ? const Center(child: CircularProgressIndicator())
          : Builder(builder: (context) {
              final k = side / math.min(w, h);
              final cw = w * k;
              final ch = h * k;
              if (!_centered) {
                _centered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _controller.value = Matrix4.translationValues(
                        -(cw - side) / 2, -(ch - side) / 2, 0);
                  }
                });
              }
              return Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset(context)),
                child: Column(
                  children: [
                    const Text(
                      'Trascina e pizzica per ingrandire.\nIl cerchio è la parte che si vedrà.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: UColors.muted, fontSize: 15),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: _boundaryKey,
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: ColoredBox(
                                color: Colors.white,
                                child: InteractiveViewer(
                                  transformationController: _controller,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 6,
                                  child: SizedBox(
                                    width: cw,
                                    height: ch,
                                    child: Image.memory(widget.bytes,
                                        fit: BoxFit.fill,
                                        gaplessPlayback: true),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                                size: Size(side, side),
                                painter: _CircleMask()),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: UColors.dark),
                              foregroundColor: UColors.dark,
                            ),
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: pillStyle,
                            onPressed: _saving ? null : () => _done(side),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Usa foto'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
    );
  }
}

class _CircleMask extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: r));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black54);
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
