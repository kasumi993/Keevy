import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/link_detector.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/application/boards_providers.dart';
import '../../boards/domain/board.dart';
import '../../boards/domain/section.dart';
import '../../boards/presentation/widgets/board_picker.dart';
import '../../contacts/presentation/contact_form.dart';
import '../share_channel.dart';
import '../share_importer.dart';

enum _Step { choose, inspiration, vendor }

/// "Enregistrer dans Keevy": step 1 (inspiration or vendor), then step 2A / 2B.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.item});
  final SharedItem item;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  _Step _step = _Step.choose;
  Board? _board;
  String? _sectionId;
  List<Section> _sections = const [];
  final _note = TextEditingController();
  bool _busy = false;

  late final DetectedShare _detected =
      widget.item.isImage ? const DetectedShare(rawText: '') : LinkDetector.analyse(widget.item.value);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _selectBoard(Board board) async {
    setState(() {
      _board = board;
      _sectionId = null;
      _sections = const [];
    });
    try {
      final sections = await ref.read(boardsRepositoryProvider).fetchSections(board.id);
      if (mounted && _board?.id == board.id) setState(() => _sections = sections);
    } catch (_) {}
  }

  Future<void> _saveInspiration() async {
    final board = _board;
    if (board == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareImporterProvider).saveInspiration(
            widget.item,
            boardId: board.id,
            sectionId: _sectionId,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(S.of(context).savedTo(board.name));
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_step != _Step.choose)
                    IconButton(
                      onPressed: () => setState(() => _step = _Step.choose),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: s.back,
                    ),
                  Expanded(child: Text(s.shareSheetTitle, style: Theme.of(context).textTheme.displaySmall)),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              _Preview(item: widget.item, detected: _detected),
              const SizedBox(height: KSpacing.lg),
              switch (_step) {
                _Step.choose => _chooseStep(s),
                _Step.inspiration => _inspirationStep(s),
                _Step.vendor => _vendorStep(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooseStep(S s) {
    final suggestVendor = _detected.looksLikeVendor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceTile(
          emoji: '✨',
          title: s.shareAsInspiration,
          subtitle: s.shareAsInspirationDesc,
          highlighted: !suggestVendor,
          onTap: () => setState(() => _step = _Step.inspiration),
        ),
        const SizedBox(height: KSpacing.md),
        _ChoiceTile(
          emoji: '📇',
          title: s.shareAsVendor,
          subtitle: s.shareAsVendorDesc,
          highlighted: suggestVendor,
          onTap: widget.item.isImage ? null : () => setState(() => _step = _Step.vendor),
        ),
      ],
    );
  }

  Widget _inspirationStep(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.chooseBoard, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: KSpacing.sm),
        BoardPicker(selectedId: _board?.id, onSelected: _selectBoard),
        if (_board != null && _sections.isNotEmpty) ...[
          const SizedBox(height: KSpacing.lg),
          Text(s.chooseSection, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(s.noSection),
                selected: _sectionId == null,
                onSelected: (_) => setState(() => _sectionId = null),
              ),
              for (final section in _sections)
                ChoiceChip(
                  label: Text(section.name),
                  selected: _sectionId == section.id,
                  onSelected: (_) => setState(() => _sectionId = section.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: KSpacing.lg),
        TextField(
          controller: _note,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: s.addNoteOptional),
        ),
        const SizedBox(height: KSpacing.xl),
        BusyButton(label: s.save, busy: _busy, onPressed: _board == null ? null : _saveInspiration),
      ],
    );
  }

  Widget _vendorStep() {
    return ContactForm(
      initial: ShareImporter.vendorDraftFrom(widget.item.value),
      askBoard: true,
      onSaved: (message) => Navigator.of(context).pop(message),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.item, required this.detected});
  final SharedItem item;
  final DetectedShare detected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    if (item.isImage) {
      return ClipRRect(
        borderRadius: const BorderRadius.all(KRadius.md),
        child: SizedBox(
          height: 160,
          child: FutureBuilder(
            future: XFile(item.value).readAsBytes(),
            builder: (context, snap) => snap.hasData
                ? Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity)
                : Container(color: KColors.surf2),
          ),
        ),
      );
    }
    final url = detected.url;
    final id = detected.identifier;
    final hint = switch (id?.type) {
      IdentifierType.instagram => s.detected('Instagram @${id!.value}'),
      IdentifierType.tiktok => s.detected('TikTok @${id!.value}'),
      IdentifierType.email => s.detected(id!.value),
      IdentifierType.phone => s.detected(id!.value),
      _ => null,
    };
    return Surface(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        children: [
          SourceBadge(source: url == null ? LinkSource.web : detected.source, size: 40),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url != null ? LinkDetector.hostOf(url) : item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint, style: t.bodySmall?.copyWith(color: KColors.t2)),
                ] else if (url != null) ...[
                  const SizedBox(height: 2),
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.emoji, required this.title, required this.subtitle, required this.onTap, this.highlighted = false});

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: highlighted ? KColors.primary : KColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(KRadius.lg),
          side: BorderSide(color: highlighted ? KColors.primary : KColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: KSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleLarge?.copyWith(color: highlighted ? KColors.white : KColors.t1)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: t.bodyMedium?.copyWith(color: highlighted ? KColors.white.withValues(alpha: 0.75) : KColors.t2)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: highlighted ? KColors.white : KColors.t3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
