import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/repo.dart';
import 'theme.dart';
import 'ui.dart';

/// Sale casuale per il PIN.
String newSalt() {
  final r = Random.secure();
  return base64UrlEncode(List.generate(9, (_) => r.nextInt(256)));
}

String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

/// Tastierino a 6 cifre con i pallini.
class PinEntry extends StatefulWidget {
  const PinEntry({super.key, required this.onFilled, this.message});
  final void Function(String pin) onFilled;
  final String? message;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
    if (_pin.length == 6) {
      final p = _pin;
      Future.delayed(const Duration(milliseconds: 140), () {
        if (mounted) widget.onFilled(p);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon}) {
    return SizedBox(
      width: 76,
      height: 60,
      child: label.isEmpty && icon == null
          ? null
          : InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: UColors.muted)
                    : Text(label,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w500)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> c) =>
        Row(mainAxisAlignment: MainAxisAlignment.center, children: c);
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? UColors.dark
                        : UColors.muted.withAlpha(60),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 28,
            child: Center(
              child: Text(widget.message ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: UColors.danger, fontSize: 13.5)),
            ),
          ),
          row([for (final d in ['1', '2', '3']) _key(d, onTap: () => _tap(d))]),
          row([for (final d in ['4', '5', '6']) _key(d, onTap: () => _tap(d))]),
          row([for (final d in ['7', '8', '9']) _key(d, onTap: () => _tap(d))]),
          row([
            _key(''),
            _key('0', onTap: () => _tap('0')),
            _key('', icon: Icons.backspace_outlined, onTap: _back),
          ]),
        ],
      ),
    );
  }
}

/// Chiede il PIN e lo confronta con quello salvato. true se corretto.
Future<bool> askPin(BuildContext context,
    {required String title, required String hash, required String salt}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _VerifyPin(title: title, hash: hash, salt: salt),
  );
  return ok == true;
}

class _VerifyPin extends StatefulWidget {
  const _VerifyPin(
      {required this.title, required this.hash, required this.salt});
  final String title;
  final String hash;
  final String salt;

  @override
  State<_VerifyPin> createState() => _VerifyPinState();
}

class _VerifyPinState extends State<_VerifyPin> {
  int _round = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.title, textAlign: TextAlign.center, style: serif(24)),
      content: PinEntry(
        key: ValueKey(_round),
        message: _error,
        onFilled: (p) {
          if (hashPin(p, widget.salt) == widget.hash) {
            Navigator.pop(context, true);
          } else {
            setState(() {
              _error = 'PIN errato, riprova';
              _round++;
            });
          }
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla')),
      ],
    );
  }
}

/// Fa scegliere un PIN di 6 numeri (due volte). Restituisce il PIN o null.
Future<String?> choosePin(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _ChoosePin());

class _ChoosePin extends StatefulWidget {
  const _ChoosePin();

  @override
  State<_ChoosePin> createState() => _ChoosePinState();
}

class _ChoosePinState extends State<_ChoosePin> {
  int _round = 0;
  String? _first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(_first == null ? 'Scegli un PIN' : 'Ripeti il PIN',
          textAlign: TextAlign.center, style: serif(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _first == null
                ? '6 numeri. Non si può recuperare: ricordalo o annotalo.'
                : 'Scrivilo di nuovo per conferma.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: UColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 14),
          PinEntry(
            key: ValueKey(_round),
            message: _error,
            onFilled: (p) {
              if (_first == null) {
                setState(() {
                  _first = p;
                  _error = null;
                  _round++;
                });
              } else if (_first == p) {
                Navigator.pop(context, p);
              } else {
                setState(() {
                  _first = null;
                  _error = 'I PIN non coincidono, ricomincia';
                  _round++;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla')),
      ],
    );
  }
}

bool isLocked(Item i) => i.flag('locked');

String? myUid() => FirebaseAuth.instance.currentUser?.uid;

/// Il creatore vede il proprio titolo, l'altro no.
bool isMine(Item i) => i.str('by') == myUid();

/// Campi da salvare per rendere segreto (o no) un elemento.
Map<String, dynamic> secretFields(String? pin) => pin == null
    ? {
        'locked': FieldValue.delete(),
        'salt': FieldValue.delete(),
        'pinHash': FieldValue.delete(),
      }
    : () {
        final s = newSalt();
        return {'locked': true, 'salt': s, 'pinHash': hashPin(pin, s)};
      }();

/// Chiede il PIN di un elemento segreto. true se si può aprire.
Future<bool> unlockItem(BuildContext context, Item i, String title) =>
    askPin(context,
        title: title, hash: i.str('pinHash'), salt: i.str('salt'));

/// Interruttore "Segreta con PIN" per i form.
/// [value]: stato attuale. Quando si attiva chiede subito il PIN.
class SecretSwitch extends StatelessWidget {
  const SecretSwitch(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.what});
  final bool value;
  final String what;
  final void Function(bool on, String? pin) onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: UColors.bgMid.withAlpha(160),
            borderRadius: BorderRadius.circular(18)),
        child: SwitchListTile(
          value: value,
          activeThumbColor: UColors.dark,
          title: const Text('🔒 Segreta con PIN'),
          subtitle: Text(
              value
                  ? 'Il partner vede solo "$what segreta" e non può aprirla'
                  : 'Nascondila al partner con un PIN di 6 numeri',
              style: const TextStyle(fontSize: 12.5)),
          onChanged: (v) async {
            if (v) {
              final pin = await choosePin(context);
              if (pin != null) onChanged(true, pin);
            } else {
              onChanged(false, null);
            }
          },
        ),
      );
}

/// Card di un elemento segreto.
class LockedCard extends StatelessWidget {
  const LockedCard(
      {super.key,
      required this.item,
      required this.titleKey,
      required this.what,
      required this.onOpen,
      required this.onDelete});
  final Item item;
  final String titleKey;
  final String what;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mine = isMine(item);
    return UCard(
      onTap: mine ? onOpen : null,
      onLongPress: mine ? onDelete : null,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: UColors.bgMid),
            child: const Text('🔒', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mine ? item.str(titleKey) : '$what segreta',
                    style: serif(22)),
                const SizedBox(height: 3),
                Text(
                    mine
                        ? 'Tocca e inserisci il PIN · tieni premuto per eliminare'
                        : 'Solo chi l\'ha creata può aprirla',
                    style: const TextStyle(
                        color: UColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
