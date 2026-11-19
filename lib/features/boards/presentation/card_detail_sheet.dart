import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/k_image.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../contacts/domain/contact.dart';
import '../../contacts/presentation/contact_form.dart';
import '../../contacts/presentation/contact_sheet.dart';
import '../application/boards_providers.dart';
import '../domain/board.dart';
import '../domain/card_item.dart';
import 'add_card_sheet.dart';

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> showCardDetailSheet(BuildContext context, {required Board board, required CardItem card}) {
  if (card.kind == CardKind.note) {
    return showKSheet<void>(context, builder: (_) => NoteForm(board: board, card: card));
  }
  return showKSheet<void>(context, expand: true, builder: (_) => CardDetailSheet(board: board, cardId: card.id));
}

/// Long-press menu: move, open, delete.
Future<void> showCardQuickActions(BuildContext context, WidgetRef ref, {required Board board, required CardItem card}) async {
  final s = S.of(context);
  final content = ref.read(boardContentProvider(board.id)).valueOrNull;
  final action = await showKSheet<String>(
    context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.url != null)
            ListTile(leading: const Icon(Icons.open_in_new_rounded), title: Text(s.openLink), onTap: () => Navigator.pop(ctx, 'open')),
          if (content != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.sm, KSpacing.lg, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text(s.moveTo, style: Theme.of(ctx).textTheme.labelMedium)),
            ),
            for (final section in content.sections)
              if (section.id != card.sectionId)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: Text(section.name),
                  onTap: () => Navigator.pop(ctx, 'move:${section.id}'),
                ),
            if (card.sectionId != null)
              ListTile(leading: const Icon(Icons.inbox_outlined), title: Text(s.unsorted), onTap: () => Navigator.pop(ctx, 'move:')),
          ],
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: KColors.err),
            title: Text(s.delete, style: const TextStyle(color: KColors.err)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final notifier = ref.read(boardContentProvider(board.id).notifier);
  try {
    if (action == 'open') {
      await openExternal(card.url!);
    } else if (action == 'delete') {
      await notifier.deleteCard(card);
      if (context.mounted) showSnack(context, s.cardDeleted);
    } else if (action.startsWith('move:')) {
      final target = action.substring(5);
      await notifier.moveCard(card, target.isEmpty ? null : target);
    }
  } catch (e) {
    if (context.mounted) handleError(context, e);
  }
}

class CardDetailSheet extends ConsumerStatefulWidget {
  const CardDetailSheet({super.key, required this.board, required this.cardId});
  final Board board;
  final String cardId;

  @override
  ConsumerState<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends ConsumerState<CardDetailSheet> {
  final _note = TextEditingController();
  bool _noteDirty = false;
  bool _initialised = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  BoardContentNotifier get _notifier => ref.read(boardContentProvider(widget.board.id).notifier);

  Future<void> _saveNote(CardItem card) async {
    final text = _note.text.trim();
    try {
      await _notifier.updateCard(card.copyWith(body: text), {'body': text.isEmpty ? null : text});
      if (mounted) setState(() => _noteDirty = false);
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  Future<void> _pickVendor(CardItem card) async {
    final s = S.of(context);
    final contacts = await ref.read(contactsProvider.future);
    if (!mounted) return;
    final picked = await showKSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: Text(s.newContact),
                onTap: () => Navigator.pop(ctx, '__new__'),
              ),
              for (final c in contacts)
                ListTile(
                  leading: InitialsAvatar(initials: c.initials, seed: c.id, size: 36),
                  title: Text(c.name),
                  subtitle: c.profession == null ? null : Text(c.profession!),
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    String? contactId = picked;
    if (picked == '__new__') {
      await showContactFormSheet(context, boardId: widget.board.id, askBoard: false);
      final refreshed = await ref.read(contactsProvider.future);
      if (refreshed.isEmpty) return;
      final newest = [...refreshed]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      contactId = newest.first.id;
    } else {
      await ref.read(contactsProvider.notifier).linkToBoard(picked, widget.board.id);
    }
    try {
      await _notifier.updateCard(card.copyWith(contactId: contactId), {'contact_id': contactId});
      ref.invalidate(contactDetailProvider(contactId));
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final content = ref.watch(boardContentProvider(widget.board.id)).valueOrNull;
    CardItem? card;
    for (final c in content?.cards ?? const <CardItem>[]) {
      if (c.id == widget.cardId) card = c;
    }
    if (card == null) return const SizedBox(height: 200);
    final current = card;
    if (!_initialised) {
      _note.text = current.body ?? '';
      _initialised = true;
    }
    final contacts = ref.watch(contactsProvider).valueOrNull ?? const <Contact>[];
    Contact? found;
    for (final c in contacts) {
      if (c.id == current.contactId) found = c;
    }
    final linked = found;

    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xxl),
      children: [
        if (current.hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.all(KRadius.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: AspectRatio(
                aspectRatio: current.aspectRatio ?? (current.kind == CardKind.link ? 1.2 : 0.8),
                child: KImage(path: current.imagePath, url: current.imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
        const SizedBox(height: KSpacing.lg),
        if (current.kind == CardKind.link) ...[
          Row(
            children: [
              SourceBadge(source: current.linkSource, size: 22),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: Text(current.domain ?? '', style: t.labelMedium)),
            ],
          ),
          if ((current.title ?? '').isNotEmpty) ...[
            const SizedBox(height: KSpacing.sm),
            Text(current.title!, style: t.displaySmall),
          ],
          const SizedBox(height: KSpacing.md),
          FilledButton.icon(
            onPressed: () => openExternal(current.url!),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(s.openLink),
          ),
          const SizedBox(height: KSpacing.lg),
        ],
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _noteDirty = true),
          decoration: InputDecoration(hintText: s.addNoteOptional),
        ),
        if (_noteDirty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _saveNote(current), child: Text(s.save)),
          ),
        const SizedBox(height: KSpacing.lg),
        Text(s.addVendor, style: t.titleSmall),
        const SizedBox(height: KSpacing.sm),
        Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.sm,
          children: [
            if (linked != null) ...[
              ActionChip(
                avatar: InitialsAvatar(initials: linked.initials, seed: linked.id, size: 22),
                label: Text(linked.name),
                onPressed: () => showContactSheet(context, linked.id),
              ),
              ActionChip(
                avatar: const Icon(Icons.link_off_rounded, size: 16),
                label: Text(s.unlinkVendor),
                onPressed: () => _notifier.updateCard(current.copyWith(clearContact: true), {'contact_id': null}),
              ),
            ] else
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: Text(s.linkVendor),
                onPressed: () => _pickVendor(current),
              ),
          ],
        ),
        if (content != null && content.sections.isNotEmpty) ...[
          const SizedBox(height: KSpacing.lg),
          Text(s.moveTo, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final section in content.sections)
                ChoiceChip(
                  label: Text(section.name),
                  selected: section.id == current.sectionId,
                  onSelected: (_) => _notifier.moveCard(current, section.id),
                ),
              ChoiceChip(
                label: Text(s.unsorted),
                selected: current.sectionId == null,
                onSelected: (_) => _notifier.moveCard(current, null),
              ),
            ],
          ),
        ],
        const SizedBox(height: KSpacing.xl),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: KColors.err),
          onPressed: () async {
            final ok = await confirmAction(context, title: s.confirmDeleteTitle, body: s.cardDeleted, confirmLabel: s.delete);
            if (!ok || !context.mounted) return;
            final notifier = _notifier;
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            try {
              await notifier.deleteCard(current);
              messenger.showSnackBar(SnackBar(content: Text(s.cardDeleted)));
            } catch (_) {
              messenger.showSnackBar(SnackBar(content: Text(s.errGeneric)));
            }
          },
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(s.delete),
        ),
      ],
    );
  }
}
