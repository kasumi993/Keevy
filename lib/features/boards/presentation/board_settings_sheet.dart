import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../sharing/presentation/share_links_sheet.dart';
import '../application/boards_providers.dart';
import '../domain/board.dart';
import 'create_board_sheet.dart';
import 'labels.dart';

Future<void> showBoardSettingsSheet(BuildContext context, Board board) {
  return showKSheet<void>(context, expand: true, builder: (_) => BoardSettingsSheet(boardId: board.id));
}

/// Board settings. "Passer en mode Projet" lives here (design decision).
class BoardSettingsSheet extends ConsumerStatefulWidget {
  const BoardSettingsSheet({super.key, required this.boardId});
  final String boardId;

  @override
  ConsumerState<BoardSettingsSheet> createState() => _BoardSettingsSheetState();
}

class _BoardSettingsSheetState extends ConsumerState<BoardSettingsSheet> {
  bool _busy = false;

  BoardsNotifier get _notifier => ref.read(boardsProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(Board board) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: board.targetDate ?? now.add(const Duration(days: 180)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) await _run(() => _notifier.setEvent(board.id, date: picked));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final board = ref.watch(boardByIdProvider(widget.boardId));
    if (board == null) return const SizedBox(height: 120);

    if (!board.isOwner) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(board.name, style: t.displaySmall),
            const SizedBox(height: KSpacing.sm),
            Text(s.ownerOnly, style: t.bodyMedium),
            const SizedBox(height: KSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: KColors.err),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmAction(context, title: s.leaveBoard, body: board.name, confirmLabel: s.leaveBoard);
                      if (!ok) return;
                      await _run(() => _notifier.leave(board.id));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        context.go('/boards');
                      }
                    },
              icon: const Icon(Icons.logout_rounded),
              label: Text(s.leaveBoard),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xxl),
      children: [
        Row(
          children: [
            Expanded(child: Text(s.boardSettings, style: t.displaySmall)),
            if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: KSpacing.lg),
        Surface(
          onTap: () async {
            final name = await promptText(context, title: s.boardName, initial: board.name);
            if (name != null) await _run(() => _notifier.rename(board.id, name));
          },
          child: Row(
            children: [
              Text(board.displayEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: KSpacing.md),
              Expanded(child: Text(board.name, style: t.titleLarge)),
              const Icon(Icons.edit_outlined, size: 18, color: KColors.t3),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.lg),
        Text(s.boardEmoji, style: t.titleSmall),
        const SizedBox(height: KSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in boardEmojis)
              GestureDetector(
                onTap: () => _run(() => _notifier.setAppearance(board.id, emoji: e)),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: board.displayEmoji == e ? board.color.withValues(alpha: 0.18) : KColors.white,
                    borderRadius: const BorderRadius.all(KRadius.sm),
                    border: Border.all(color: board.displayEmoji == e ? board.color : KColors.border),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 18)),
                ),
              ),
          ],
        ),
        const SizedBox(height: KSpacing.lg),
        Text(s.boardColor, style: t.titleSmall),
        const SizedBox(height: KSpacing.sm),
        ColorPickerRow(
          selected: board.color,
          onSelected: (c) => _run(() => _notifier.setAppearance(board.id, colorHex: c.toHex())),
        ),
        const SizedBox(height: KSpacing.xl),
        if (!board.isProjet)
          Surface(
            color: KColors.primary,
            onTap: _busy ? null : () => _run(() => _notifier.setMode(board.id, BoardMode.projet)),
            child: Row(
              children: [
                const Text('🗓️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.switchToProjet, style: t.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(s.switchToProjetDesc, style: t.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          )
        else ...[
          Text(s.eventTypeLabel, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final type in EventType.values)
                ChoiceChip(
                  label: Text('${type.emoji} ${eventTypeLabel(s, type)}'),
                  selected: board.eventType == type,
                  onSelected: (_) => _run(() => _notifier.setEvent(board.id, type: type)),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.lg),
          Text(s.targetDateLabel, style: t.titleSmall),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(board),
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(board.targetDate == null ? s.pickDate : formatLongDate(board.targetDate!, locale)),
                ),
              ),
              if (board.targetDate != null)
                IconButton(
                  onPressed: () => _run(() => _notifier.setEvent(board.id, clearDate: true)),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => _run(() => _notifier.setMode(board.id, BoardMode.inspiration)),
            child: Text(s.switchToInspiration),
          ),
        ],
        const SizedBox(height: KSpacing.lg),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.ios_share_rounded),
          title: Text(s.shareBoard),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showShareLinksSheet(context, board),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(board.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
          title: Text(board.isArchived ? s.unarchiveBoard : s.archiveBoard),
          onTap: _busy ? null : () => _run(() => _notifier.archive(board.id, archived: !board.isArchived)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline_rounded, color: KColors.err),
          title: Text(s.deleteBoard, style: const TextStyle(color: KColors.err)),
          onTap: () async {
            final ok = await confirmAction(context, title: s.deleteBoard, body: s.deleteBoardBody, confirmLabel: s.delete);
            if (!ok || !context.mounted) return;
            final notifier = _notifier;
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go('/boards');
            try {
              await notifier.delete(board.id);
            } catch (_) {}
          },
        ),
      ],
    );
  }
}
