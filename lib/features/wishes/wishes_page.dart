import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/undo.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../tasks/tasks_page.dart';

class WishesSection extends ConsumerStatefulWidget {
  const WishesSection({super.key});

  @override
  ConsumerState<WishesSection> createState() => _WishesSectionState();
}

class _WishesSectionState extends ConsumerState<WishesSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final wishes = ref.watch(wishesProvider).value ?? [];
    final members = ref.watch(membersProvider).value ?? [];
    final me = FirebaseAuth.instance.currentUser?.uid;
    Item? partner;
    for (final m in members) {
      if (m.id != me) partner = m;
    }
    final partnerName =
        partner == null ? 'Partner' : (firstName(partner.str('name')).isEmpty ? 'Partner' : firstName(partner.str('name')));

    final viewingPartner = _tab == 1 && partner != null;
    final owner = viewingPartner ? partner!.id : me;
    final shown = wishes.where((w) => w.str('owner') == owner).toList()
      ..sort((a, b) => (b.date('createdAt') ?? DateTime(2100))
          .compareTo(a.date('createdAt') ?? DateTime(2100)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('I miei desideri'),
                selected: !viewingPartner,
                onSelected: (_) => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              if (partner != null)
                ChoiceChip(
                  label: Text('Di $partnerName'),
                  selected: viewingPartner,
                  onSelected: (_) => setState(() => _tab = 1),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              viewingPartner
                  ? 'Spunta quello che hai già preso: solo tu vedi la spunta.'
                  : 'Quello che vorresti ricevere: così i regali fanno centro.',
              style: TextStyle(color: UColors.muted),
            ),
          ),
        ),
        if (shown.isEmpty)
          EmptyCard(
            emoji: '🎁',
            title: viewingPartner ? 'Ancora niente' : 'Cosa vorresti?',
            text: viewingPartner
                ? '$partnerName non ha ancora aggiunto desideri.'
                : 'Aggiungi quello che ti piacerebbe ricevere: il partner lo vedrà e i regali faranno centro.',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final w in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: UCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      onTap: (repo == null || viewingPartner)
                          ? null
                          : () => showWishSheet(context, repo, item: w),
                      onLongPress: (repo == null || viewingPartner)
                          ? null
                          : () => itemMenu(context,
                              title: w.str('title'),
                              onEdit: () =>
                                  showWishSheet(context, repo, item: w),
                              onDelete: () => deleteItem(context, repo, 'wishes', w)),
                      child: Row(
                        children: [
                          if (viewingPartner)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => repo?.update('wishes', w.id,
                                    {'gifted': !w.flag('gifted')}),
                                child: Icon(
                                  w.flag('gifted')
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: w.flag('gifted')
                                      ? UColors.accent
                                      : UColors.muted,
                                  size: 28,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.str('title'),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    decoration:
                                        (viewingPartner && w.flag('gifted'))
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                ),
                                if (w.str('note').isNotEmpty)
                                  Text(w.str('note'),
                                      style: TextStyle(
                                          color: UColors.muted)),
                                if (w.str('link').isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: w.str('link')));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Link copiato')));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(w.str('link'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: UColors.lilac,
                                              decoration:
                                                  TextDecoration.underline)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (w.str('price').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(w.str('price'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: UColors.accent)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showWishSheet(BuildContext context, Repo repo, {Item? item}) =>
    showUSheet(context, _WishForm(repo: repo, item: item));

class _WishForm extends StatefulWidget {
  const _WishForm({required this.repo, this.item});
  final Repo repo;
  final Item? item;

  @override
  State<_WishForm> createState() => _WishFormState();
}

class _WishFormState extends State<_WishForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item?.str('title'));
  late final TextEditingController _price =
      TextEditingController(text: widget.item?.str('price'));
  late final TextEditingController _link =
      TextEditingController(text: widget.item?.str('link'));
  late final TextEditingController _note =
      TextEditingController(text: widget.item?.str('note'));

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final data = <String, dynamic>{
      'title': title,
      'price': _price.text.trim(),
      'link': _link.text.trim(),
      'note': _note.text.trim(),
    };
    if (widget.item == null) {
      widget.repo.add('wishes', {
        ...data,
        'owner': FirebaseAuth.instance.currentUser?.uid,
        'gifted': false,
      });
    } else {
      widget.repo.update('wishes', widget.item!.id, data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'Nuovo desiderio' : 'Modifica desiderio',
            style: serif(28)),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.item == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Cosa desideri?'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _price, decoration: fieldDeco('Prezzo (facoltativo)', hint: 'Es. 49 €')),
        const SizedBox(height: 12),
        TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: fieldDeco('Link (facoltativo)')),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: fieldDeco('Nota (taglia, colore…)'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (widget.item != null)
              IconButton(
                onPressed: () {
                  deleteItem(context, widget.repo, 'wishes', widget.item!);
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete_outline, color: UColors.danger),
              ),
            Expanded(
              child: FilledButton(
                  style: pillStyle,
                  onPressed: _save,
                  child: const Text('Salva')),
            ),
          ],
        ),
      ],
    );
  }
}
