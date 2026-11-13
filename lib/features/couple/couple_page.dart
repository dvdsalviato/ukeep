import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/providers.dart';

class CouplePage extends ConsumerStatefulWidget {
  const CouplePage({super.key});

  @override
  ConsumerState<CouplePage> createState() => _CouplePageState();
}

class _CouplePageState extends ConsumerState<CouplePage> {
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final service = ref.read(coupleServiceProvider);
    final first = (user.displayName ?? '').split(' ').first;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Esci'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Image.asset('assets/logo.png', width: 110)),
            const SizedBox(height: 12),
            Text('Ciao${first.isEmpty ? '' : ', $first'}',
                textAlign: TextAlign.center, style: serif(38)),
            const SizedBox(height: 10),
            const Text(
              'Crea il vostro spazio condiviso oppure entra in quello '
              'del tuo partner con il codice invito.',
              textAlign: TextAlign.center,
              style: TextStyle(color: UColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 28),
            UCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nuovo spazio', style: serif(24)),
                  const SizedBox(height: 6),
                  const Text('Lo crei tu e poi inviti il partner.',
                      style: TextStyle(color: UColors.muted)),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: pillStyle,
                    onPressed: _busy
                        ? null
                        : () => _run(() => service.createCouple(user)),
                    child: const Text('Crea il nostro spazio'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            UCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Ho un codice', style: serif(24)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: fieldDeco('Codice invito'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: UColors.dark),
                      foregroundColor: UColors.dark,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => service.joinCouple(user, _code.text)),
                    child: const Text('Entra con il codice'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
