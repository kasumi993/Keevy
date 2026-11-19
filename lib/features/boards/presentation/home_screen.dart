import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/auth_providers.dart';
import '../application/boards_providers.dart';
import '../domain/board.dart';
import 'create_board_sheet.dart';
import 'widgets/board_tiles.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final boardsAsync = ref.watch(boardsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateBoardSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.newBoard),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KColors.primary,
          onRefresh: () => ref.read(boardsProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.lg, KSpacing.sm, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.hello(profile?.firstName), style: Theme.of(context).textTheme.bodyMedium),
                            Text(s.homeTitle, style: Theme.of(context).textTheme.displayLarge),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        tooltip: s.settingsTitle,
                        icon: CircleAvatar(
                          radius: 18,
                          backgroundColor: KColors.primary,
                          child: Text(
                            (profile?.firstName.isNotEmpty ?? false) ? profile!.firstName[0].toUpperCase() : 'K',
                            style: const TextStyle(fontFamily: KFonts.serif, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...boardsAsync.when<List<Widget>>(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
                error: (e, _) => [
                  SliverFillRemaining(child: ErrorState(onRetry: () => ref.invalidate(boardsProvider))),
                ],
                data: (boards) => _content(context, s, boards),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, S s, List<Board> boards) {
    if (boards.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            emoji: '🌸',
            title: s.emptyBoardsTitle,
            body: s.emptyBoardsBody,
            action: FilledButton.icon(
              onPressed: () => showCreateBoardSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.newBoard),
            ),
          ),
        ),
      ];
    }

    final active = boards.where((b) => !b.isArchived).toList();
    final mine = active.where((b) => b.isOwner).toList();
    final shared = active.where((b) => !b.isOwner).toList();
    final projets = mine.where((b) => b.isProjet).toList()
      ..sort((a, b) => (a.targetDate ?? DateTime(9999)).compareTo(b.targetDate ?? DateTime(9999)));
    final inspirations = mine.where((b) => !b.isProjet).toList();
    final archived = boards.where((b) => b.isArchived).toList();

    void open(Board b) => context.go('/boards/${b.id}');

    Widget grid(List<Board> list) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: KSpacing.md,
              crossAxisSpacing: KSpacing.md,
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => InspirationBoardTile(board: list[i], onTap: () => open(list[i])),
              childCount: list.length,
            ),
          ),
        );

    return [
      if (projets.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionTitle(s.projectsSection)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          sliver: SliverList.separated(
            itemCount: projets.length,
            separatorBuilder: (_, __) => const SizedBox(height: KSpacing.md),
            itemBuilder: (context, i) => ProjetBoardCard(board: projets[i], onTap: () => open(projets[i])),
          ),
        ),
      ],
      if (inspirations.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionTitle(s.inspirationSection)),
        grid(inspirations),
      ],
      if (shared.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionTitle(s.sharedSection)),
        grid(shared),
      ],
      if (archived.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.sm, KSpacing.lg, KSpacing.sm, 0),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('${s.archivedSection} (${archived.length})', style: Theme.of(context).textTheme.labelMedium),
                children: [
                  for (final b in archived)
                    ListTile(
                      leading: Text(b.displayEmoji, style: const TextStyle(fontSize: 20)),
                      title: Text(b.name),
                      subtitle: Text(b.isProjet ? s.modeProjet : s.modeInspiration),
                      onTap: () => open(b),
                    ),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}
