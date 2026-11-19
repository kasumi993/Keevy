import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../planning/presentation/planning_tab.dart';
import '../../sharing/presentation/share_links_sheet.dart';
import '../application/boards_providers.dart';
import 'board_settings_sheet.dart';
import 'inspiration_tab.dart';

/// A board. Projet boards get two tabs: Inspiration and Planification.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.boardId});
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final boardsAsync = ref.watch(boardsProvider);
    final board = ref.watch(boardByIdProvider(boardId));

    if (board == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/boards'))),
        body: boardsAsync.isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : EmptyState(emoji: '🔍', title: s.boardNotFound, body: ''),
      );
    }

    final appBarTitle = Row(
      children: [
        Text(board.displayEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: KSpacing.sm),
        Flexible(child: Text(board.name, overflow: TextOverflow.ellipsis)),
        if (!board.isOwner) ...[
          const SizedBox(width: KSpacing.sm),
          DotChip(label: s.sharedBadge, color: KColors.info, dense: true),
        ],
      ],
    );

    final actions = [
      if (board.isOwner)
        IconButton(
          tooltip: s.shareBoard,
          onPressed: () => showShareLinksSheet(context, board),
          icon: const Icon(Icons.ios_share_rounded),
        ),
      IconButton(
        tooltip: s.boardSettings,
        onPressed: () => showBoardSettingsSheet(context, board),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    ];

    final leading = BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/boards'));

    if (!board.isProjet) {
      return Scaffold(
        appBar: AppBar(leading: leading, title: appBarTitle, actions: actions),
        body: InspirationTab(board: board),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: leading,
          title: appBarTitle,
          actions: actions,
          bottom: TabBar(
            labelColor: KColors.t1,
            unselectedLabelColor: KColors.t3,
            indicatorColor: board.color,
            indicatorWeight: 3,
            dividerColor: KColors.border,
            labelStyle: const TextStyle(fontFamily: KFonts.sans, fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [Tab(text: s.tabInspiration), Tab(text: s.tabPlanning)],
          ),
        ),
        body: TabBarView(
          children: [
            InspirationTab(board: board),
            PlanningTab(board: board),
          ],
        ),
      ),
    );
  }
}
