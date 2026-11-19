import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../boards/domain/card_item.dart';
import '../../boards/presentation/card_detail_sheet.dart';
import '../../boards/presentation/widgets/card_tile.dart';
import '../application/sharing_providers.dart';
import '../data/shares_repository.dart';

/// Public read-only board (web viewer at `/s/<token>`). No account needed.
class SharedBoardScreen extends ConsumerWidget {
  const SharedBoardScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final snapshotAsync = ref.watch(sharedBoardProvider(token));
    return Scaffold(
      body: AsyncBody<SharedBoardSnapshot?>(
        value: snapshotAsync,
        onRetry: () => ref.invalidate(sharedBoardProvider(token)),
        data: (snap) {
          if (snap == null) {
            return EmptyState(
              emoji: '🔒',
              title: s.sharedLinkInvalid,
              body: s.tagline,
              action: FilledButton(onPressed: () => context.go('/boards'), child: Text(s.createYourKeevy)),
            );
          }
          return _SharedBoardView(snapshot: snap);
        },
      ),
    );
  }
}

class _SharedBoardView extends StatefulWidget {
  const _SharedBoardView({required this.snapshot});
  final SharedBoardSnapshot snapshot;

  @override
  State<_SharedBoardView> createState() => _SharedBoardViewState();
}

class _SharedBoardViewState extends State<_SharedBoardView> {
  String? _section = '__all__';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final snap = widget.snapshot;
    final board = snap.board;
    final cards = _section == '__all__' ? snap.cards : snap.cards.where((c) => c.sectionId == _section).toList();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1000 ? 4 : (width > 640 ? 3 : 2);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: board.color.withValues(alpha: 0.12),
            padding: EdgeInsets.fromLTRB(KSpacing.xl, MediaQuery.paddingOf(context).top + KSpacing.xl, KSpacing.xl, KSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Keevy', style: t.headlineSmall),
                        const Spacer(),
                        DotChip(label: s.readOnly, color: KColors.t2, dense: true),
                      ],
                    ),
                    const SizedBox(height: KSpacing.xl),
                    Text(board.displayEmoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: KSpacing.sm),
                    Text(board.name, style: t.displayLarge),
                    if (snap.ownerName.isNotEmpty) Text(s.sharedBoardBy(snap.ownerName), style: t.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (snap.sections.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl, vertical: KSpacing.sm),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(s.all), selected: _section == '__all__', onSelected: (_) => setState(() => _section = '__all__')),
                  ),
                  for (final section in snap.sections)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(section.name),
                        selected: _section == section.id,
                        selectedColor: board.color,
                        onSelected: (_) => setState(() => _section = section.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(KSpacing.xl, KSpacing.sm, KSpacing.xl, KSpacing.xl),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: columns,
            mainAxisSpacing: KSpacing.md,
            crossAxisSpacing: KSpacing.md,
            childCount: cards.length,
            itemBuilder: (context, i) {
              final CardItem card = cards[i];
              return CardTile(card: card, onTap: card.url == null ? null : () => openExternal(card.url!));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.xl, KSpacing.lg, KSpacing.xl, KSpacing.xxl),
            child: Column(
              children: [
                Text(s.tagline, style: t.bodyLarge?.copyWith(fontFamily: KFonts.serif, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                const SizedBox(height: KSpacing.md),
                FilledButton(onPressed: () => context.go('/boards'), child: Text(s.createYourKeevy)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
