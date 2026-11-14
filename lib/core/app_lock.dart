import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'ui.dart';

/// Blocco con impronta (o con il PIN del telefono). Facoltativo: si attiva
/// e si toglie dal Profilo. Vale solo su questo telefono.
class LockCtl {
  LockCtl._();
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static final _auth = LocalAuthentication();

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool('appLock') ?? false;
    } catch (_) {}
  }

  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Sblocca Ukeep',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// Attiva/disattiva (chiede l'impronta per conferma).
  static Future<bool> set(bool on) async {
    if (!await available()) return false;
    if (!await authenticate()) return false;
    enabled.value = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('appLock', on);
    } catch (_) {}
    return true;
  }
}

/// Copre l'app quando è bloccata. Si riblocca se resta in background più di
/// un minuto.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.child});
  final Widget child;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  static bool _startLocked = true;
  bool _locked = false;
  bool _authing = false;
  DateTime? _away;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // al primo avvio dell'app (non quando si cambia tema)
    if (LockCtl.enabled.value && _startLocked) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
    _startLocked = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authing) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _away ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _away;
      _away = null;
      if (LockCtl.enabled.value &&
          away != null &&
          DateTime.now().difference(away).inSeconds > 60) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    final ok = await LockCtl.authenticate();
    _authing = false;
    _away = null;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              child: GradientBg(
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logo.png', width: 96, height: 96),
                        const SizedBox(height: 20),
                        Text('Ukeep è bloccata', style: serif(30)),
                        const SizedBox(height: 8),
                        Text('Usa l\'impronta per entrare',
                            style: TextStyle(color: UColors.muted)),
                        const SizedBox(height: 26),
                        FilledButton.icon(
                          style: pillStyle,
                          onPressed: _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Sblocca'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
