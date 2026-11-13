import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final t = Theme.of(context).textTheme;
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
            Text('Ciao ${user.displayName ?? ''}', style: t.headlineMedium),
            const SizedBox(height: 8),
            const Text('Crea il vostro spazio condiviso oppure entra in '
                'quello del tuo partner con il codice invito.'),
            const SizedBox(height: 32),
            FilledButton(
              onPressed:
                  _busy ? null : () => _run(() => service.createCouple(user)),
              child: const Text('Crea il nostro spazio'),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codice invito',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => service.joinCouple(user, _code.text)),
              child: const Text('Entra con il codice'),
            ),
          ],
        ),
      ),
    );
  }
}
