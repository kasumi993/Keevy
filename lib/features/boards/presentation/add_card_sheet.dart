import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/link_detector.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../contacts/presentation/contact_form.dart';
import '../../share_intake/share_importer.dart';
import '../application/boards_providers.dart';
import '../data/cards_repository.dart';
import '../domain/board.dart';
import '../domain/card_item.dart';

Future<void> showAddCardSheet(BuildContext context, {required Board board, String? sectionId}) async {
  final s = S.of(context);
  final choice = await showKSheet<String>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpacing.lg, 0, KSpacing.lg, KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: KSpacing.sm, bottom: KSpacing.md),
              child: Text(s.add, style: Theme.of(ctx).textTheme.displaySmall),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: KSpacing.md,
              crossAxisSpacing: KSpacing.md,
              childAspectRatio: 1.45,
              children: [
                _AddOption(emoji: '🖼️', title: s.addPhoto, subtitle: s.addPhotoDesc, onTap: () => Navigator.pop(ctx, 'photo')),
                _AddOption(emoji: '🔗', title: s.addLink, subtitle: s.addLinkDesc, onTap: () => Navigator.pop(ctx, 'link')),
                _AddOption(emoji: '📝', title: s.addNote, subtitle: s.addNoteDesc, onTap: () => Navigator.pop(ctx, 'note')),
                _AddOption(emoji: '📇', title: s.addVendor, subtitle: s.addVendorDesc, onTap: () => Navigator.pop(ctx, 'vendor')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'photo':
      await _addPhotos(context, board, sectionId);
    case 'link':
      await showKSheet<void>(context, builder: (_) => _LinkForm(board: board, sectionId: sectionId));
    case 'note':
      await showKSheet<void>(context, builder: (_) => NoteForm(board: board, sectionId: sectionId));
    case 'vendor':
      final message = await showContactFormSheet(context, boardId: board.id, askBoard: false);
      if (message != null && context.mounted) showSnack(context, message);
  }
}

Future<void> _addPhotos(BuildContext context, Board board, String? sectionId) async {
  final s = S.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final List<XFile> files;
  try {
    files = await ImagePicker().pickMultiImage(maxWidth: 2200, imageQuality: 85);
  } on PlatformException catch (e) {
    if (context.mounted) handleError(context, e);
    return;
  }
  if (files.isEmpty || !context.mounted) return;
  showSnack(context, '${s.addPhoto} · ${files.length}…');
  final importer = container.read(shareImporterProvider);
  final notifier = container.read(boardContentProvider(board.id).notifier);
  var failed = 0;
  for (final file in files) {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final draft = await importer.draftFromImage(boardId: board.id, sectionId: sectionId, bytes: bytes, extension: ext);
      await notifier.addCard(draft);
    } catch (_) {
      failed++;
    }
  }
  if (failed > 0 && context.mounted) showSnack(context, s.uploadFailed);
}

class _AddOption extends StatelessWidget {
  const _AddOption({required this.emoji, required this.title, required this.subtitle, required this.onTap});
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(title, style: t.titleMedium),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm({required this.board, this.sectionId});
  final Board board;
  final String? sectionId;

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  final _url = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillFromClipboard();
  }

  Future<void> _prefillFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && LinkDetector.extractUrl(text) != null && _url.text.isEmpty && mounted) {
        setState(() => _url.text = LinkDetector.extractUrl(text)!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    final url = LinkDetector.normaliseUserUrl(_url.text);
    if (url == null) {
      setState(() => _error = s.linkInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await ref.read(shareImporterProvider).draftFromText(
            boardId: widget.board.id,
            sectionId: widget.sectionId,
            text: url,
            note: _note.text,
          );
      await ref.read(boardContentProvider(widget.board.id).notifier).addCard(draft);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.addLink, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: KSpacing.lg),
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: s.pasteLink, hintText: 'https://', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: KSpacing.md),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: s.addNoteOptional),
          ),
          const SizedBox(height: KSpacing.xl),
          BusyButton(label: _busy ? s.fetchingPreview : s.save, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

/// Create or edit a note card.
class NoteForm extends ConsumerStatefulWidget {
  const NoteForm({super.key, required this.board, this.sectionId, this.card});
  final Board board;
  final String? sectionId;
  final CardItem? card;

  @override
  ConsumerState<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<NoteForm> {
  late final _title = TextEditingController(text: widget.card?.title);
  late final _body = TextEditingController(text: widget.card?.body);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    setState(() => _busy = true);
    final notifier = ref.read(boardContentProvider(widget.board.id).notifier);
    try {
      final existing = widget.card;
      if (existing == null) {
        await notifier.addCard(CardItem(
          id: CardsRepository.newId(),
          boardId: widget.board.id,
          sectionId: widget.sectionId,
          kind: CardKind.note,
          title: title.isEmpty ? null : title,
          body: body.isEmpty ? null : body,
          source: 'note',
        ));
      } else {
        await notifier.updateCard(
          existing.copyWith(title: title, body: body),
          {'title': title.isEmpty ? null : title, 'body': body.isEmpty ? null : body},
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.addNote, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: KSpacing.lg),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontFamily: KFonts.serif, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(hintText: s.titleHint),
          ),
          const SizedBox(height: KSpacing.md),
          TextField(
            controller: _body,
            autofocus: widget.card == null,
            minLines: 5,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: s.noteHint),
          ),
          const SizedBox(height: KSpacing.xl),
          BusyButton(label: s.save, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
