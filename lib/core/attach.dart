import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../data/repo.dart';
import 'theme.dart';
import 'ui.dart';

/// Foto allegate (scontrini, ecc.).
/// Stanno in un documento a parte (attachments/{id}.b64) così le liste
/// restano leggere: la foto si scarica solo quando la guardi.

Uint8List shrinkImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final d = img.bakeOrientation(decoded);
  var r = d.width > 1280 ? img.copyResize(d, width: 1280) : d;
  var out = img.encodeJpg(r, quality: 70);
  if (out.length > 650000) {
    r = img.copyResize(d, width: 900);
    out = img.encodeJpg(r, quality: 60);
  }
  return Uint8List.fromList(out);
}

/// Fa scegliere una foto (galleria o fotocamera) e la salva.
/// Restituisce l'id dell'allegato, oppure null.
Future<String?> pickAttachment(BuildContext context, Repo repo) async {
  final src = await showUSheet<ImageSource>(
    context,
    Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Allega una foto', style: serif(26)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Scatta una foto'),
            subtitle: const Text('Es. lo scontrino'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli dalla galleria'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final x = await ImagePicker()
      .pickImage(source: src, maxWidth: 2400, imageQuality: 92);
  if (x == null) return null;
  final small = await compute(shrinkImage, await x.readAsBytes());
  final doc = repo.col('attachments').doc();
  await doc.set({'b64': base64Encode(small)});
  return doc.id;
}

final Map<String, Uint8List> _cache = {};

Future<Uint8List?> loadAttachment(Repo repo, String id) async {
  final c = _cache[id];
  if (c != null) return c;
  try {
    final s = await repo.col('attachments').doc(id).get();
    final b = s.data()?['b64'];
    if (b is! String) return null;
    final bytes = base64Decode(b);
    _cache[id] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Miniatura dell'allegato: si tocca per vederlo a schermo intero.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb(
      {super.key,
      required this.repo,
      required this.id,
      this.size = 64,
      this.onRemove});
  final Repo repo;
  final String id;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: loadAttachment(repo, id),
      builder: (context, snap) {
        final b = snap.data;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: b == null ? null : () => openAttachment(context, b),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: size,
                  height: size,
                  color: UColors.bgMid,
                  alignment: Alignment.center,
                  child: b == null
                      ? (snap.connectionState == ConnectionState.done
                          ? Icon(Icons.broken_image_outlined,
                              color: UColors.muted)
                          : const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)))
                      : Image.memory(b,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          gaplessPlayback: true),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: -8,
                top: -8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: UColors.dark, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 14, color: UColors.onDark),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

void openAttachment(BuildContext context, Uint8List bytes) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.memory(bytes),
        ),
      ),
    ),
  ));
}

/// Riga "📎 Allega foto" + miniatura, per i form.
class AttachmentField extends StatefulWidget {
  const AttachmentField(
      {super.key,
      required this.repo,
      required this.id,
      required this.onChanged,
      this.label = 'Allega foto (es. scontrino)'});
  final Repo repo;
  final String? id;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  State<AttachmentField> createState() => _AttachmentFieldState();
}

class _AttachmentFieldState extends State<AttachmentField> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (id != null) {
      return Row(
        children: [
          AttachmentThumb(
              repo: widget.repo, id: id, onRemove: () => widget.onChanged(null)),
          const SizedBox(width: 14),
          Expanded(
            child: Text('📎 Foto allegata: toccala per ingrandire',
                style: TextStyle(color: UColors.muted, fontSize: 13)),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.attach_file, size: 18),
        label: Text(_busy ? 'Carico la foto…' : widget.label),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final newId = await pickAttachment(context, widget.repo);
                if (!mounted) return;
                setState(() => _busy = false);
                if (newId != null) widget.onChanged(newId);
              },
      ),
    );
  }
}
