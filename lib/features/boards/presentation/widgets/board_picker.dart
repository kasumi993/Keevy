import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../application/boards_providers.dart';
import '../../domain/board.dart';

/// Vertical list of the user's active boards, with inline "new board".
class BoardPicker extends ConsumerWidget {
  const BoardPicker({super.key, required this.selectedId, required this.onSelected, this.excludeIds = const {}});

  final String? selectedId;
  final ValueChanged<Board> onSelected;
  final Set<String> excludeIds;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final name = await promptText(context, title: s.newBoard, hint: s.boardNameHint, confirmLabel: s.create);
    if (name == null || !context.mounted) return;
    try {
      final board = await ref.read(boardsProvider.notifier).create(
            name: name,
            colorHex: KColors.boardAccents.first.toHex(),
            mode: BoardMode.inspiration,
            sections: defaultSectionsFor(null, isFr: s.isFr),
          );
      onSelected(board);
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final boards = ref.watch(activeBoardsProvider).where((b) => !excludeIds.contains(b.id)).toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: const BoxDecoration(
        color: KColors.white,
        borderRadius: BorderRadius.all(KRadius.md),
        border: Border.fromBorderSide(BorderSide(color: KColors.border)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        children: [
          for (final b in boards)
            ListTile(
              dense: true,
              onTap: () => onSelected(b),
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: b.color.withValues(alpha: 0.16), borderRadius: const BorderRadius.all(KRadius.sm)),
                child: Text(b.displayEmoji, style: const TextStyle(fontSize: 17)),
              ),
              title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(b.isProjet ? s.modeProjet : s.modeInspiration),
              trailing: selectedId == b.id
                  ? const Icon(Icons.check_circle_rounded, color: KColors.ok)
                  : const Icon(Icons.circle_outlined, color: KColors.border),
            ),
          ListTile(
            dense: true,
            onTap: () => _create(context, ref),
            leading: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: KColors.surf2, borderRadius: BorderRadius.all(KRadius.sm)),
              child: const Icon(Icons.add_rounded, color: KColors.t1),
            ),
            title: Text(s.newBoard),
          ),
        ],
      ),
    );
  }
}
