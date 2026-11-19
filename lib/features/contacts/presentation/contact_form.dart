import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/application/boards_providers.dart';
import '../../boards/domain/board.dart';
import '../../boards/presentation/widgets/board_picker.dart';
import '../application/contacts_providers.dart';
import '../domain/contact.dart';

/// Create / edit a vendor. Used in the contacts tab, boards and the share sheet.
class ContactForm extends ConsumerStatefulWidget {
  const ContactForm({
    super.key,
    this.initial = const ContactDraft(),
    this.contactId,
    this.boardId,
    this.askBoard = false,
    required this.onSaved,
  });

  final ContactDraft initial;

  /// Set when editing an existing contact.
  final String? contactId;

  /// Board to link the new contact to (planning tab).
  final String? boardId;

  /// Show a board picker (share sheet, contacts tab).
  final bool askBoard;

  /// Receives a confirmation message.
  final ValueChanged<String> onSaved;

  @override
  ConsumerState<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.name);
  late final _profession = TextEditingController(text: widget.initial.profession);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _email = TextEditingController(text: widget.initial.email);
  late final _instagram = TextEditingController(text: widget.initial.instagram);
  late final _tiktok = TextEditingController(text: widget.initial.tiktok);
  late final _website = TextEditingController(text: widget.initial.website);
  late final _recommended = TextEditingController(text: widget.initial.recommendedBy);
  late final _notes = TextEditingController(text: widget.initial.notes);
  Board? _board;
  bool _busy = false;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _more = [widget.initial.tiktok, widget.initial.recommendedBy, widget.initial.notes]
        .any((v) => v != null && v.isNotEmpty);
  }

  @override
  void dispose() {
    for (final c in [_name, _profession, _phone, _email, _instagram, _tiktok, _website, _recommended, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  ContactDraft get _draft => ContactDraft(
        name: _name.text.trim(),
        profession: _profession.text,
        phone: _phone.text,
        email: _email.text,
        instagram: _instagram.text,
        tiktok: _tiktok.text,
        website: _website.text,
        recommendedBy: _recommended.text,
        notes: _notes.text,
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final notifier = ref.read(contactsProvider.notifier);
      if (widget.contactId != null) {
        await notifier.updateContact(widget.contactId!, _draft);
        if (mounted) widget.onSaved(s.save);
      } else {
        final boardId = widget.boardId ?? _board?.id;
        final result = await notifier.create(_draft, boardId: boardId);
        if (!mounted) return;
        final board = boardId == null ? null : ref.read(boardByIdProvider(boardId));
        widget.onSaved(result.existed ? s.contactExists : (board != null ? s.savedTo(board.name) : result.contact.name));
      }
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    InputDecoration deco(String label, {String? hint, IconData? icon}) =>
        InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 20));

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: deco(s.contactName),
            validator: (v) => (v == null || v.trim().isEmpty) ? s.nameIsRequired : null,
          ),
          const SizedBox(height: KSpacing.md),
          TextFormField(
            controller: _profession,
            textCapitalization: TextCapitalization.sentences,
            decoration: deco(s.profession, hint: s.professionHint),
          ),
          const SizedBox(height: KSpacing.md),
          TextFormField(controller: _instagram, decoration: deco(s.instagram, hint: '@', icon: Icons.camera_alt_outlined)),
          const SizedBox(height: KSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: deco(s.phone, icon: Icons.phone_outlined),
          ),
          const SizedBox(height: KSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: deco(s.email, icon: Icons.mail_outline_rounded),
          ),
          const SizedBox(height: KSpacing.md),
          TextFormField(
            controller: _website,
            keyboardType: TextInputType.url,
            decoration: deco(s.website, icon: Icons.language_rounded),
          ),
          if (!_more)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _more = true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('${s.tiktok} · ${s.recommendedBy} · ${s.notes}'),
              ),
            )
          else ...[
            const SizedBox(height: KSpacing.md),
            TextFormField(controller: _tiktok, decoration: deco(s.tiktok, hint: '@', icon: Icons.music_note_rounded)),
            const SizedBox(height: KSpacing.md),
            TextFormField(
              controller: _recommended,
              textCapitalization: TextCapitalization.words,
              decoration: deco(s.recommendedBy, icon: Icons.favorite_border_rounded),
            ),
            const SizedBox(height: KSpacing.md),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(s.notes),
            ),
          ],
          if (widget.askBoard && widget.contactId == null && widget.boardId == null) ...[
            const SizedBox(height: KSpacing.lg),
            Text('${s.addToBoard} (${s.optional})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: KSpacing.sm),
            BoardPicker(
              selectedId: _board?.id,
              onSelected: (b) => setState(() => _board = _board?.id == b.id ? null : b),
            ),
          ],
          const SizedBox(height: KSpacing.xl),
          BusyButton(label: s.save, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

/// Opens the contact form in a sheet.
Future<String?> showContactFormSheet(
  BuildContext context, {
  ContactDraft initial = const ContactDraft(),
  String? contactId,
  String? boardId,
  bool askBoard = true,
}) {
  final s = S.of(context);
  return showKSheet<String>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(contactId == null ? s.newContact : s.editContact, style: Theme.of(ctx).textTheme.displaySmall),
          const SizedBox(height: KSpacing.lg),
          ContactForm(
            initial: initial,
            contactId: contactId,
            boardId: boardId,
            askBoard: askBoard,
            onSaved: (msg) => Navigator.of(ctx).pop(msg),
          ),
        ],
      ),
    ),
  );
}
