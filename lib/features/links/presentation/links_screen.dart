import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/link_detector.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/domain/card_item.dart';
import '../../boards/presentation/card_detail_sheet.dart';
import '../application/links_providers.dart';

/// Every saved link, with the board it lives in.
class LinksScreen extends ConsumerStatefulWidget {
  const LinksScreen({super.key});

  @override
  ConsumerState<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends ConsumerState<LinksScreen> {
  String _query = '';
  LinkSource? _source;

  bool _matches(CardItem c) {
    if (_source != null && c.linkSource != _source) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [c.title, c.domain, c.url, c.body, c.boardName].whereType<String>().any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final linksAsync = ref.watch(linksProvider);
    final present = (linksAsync.valueOrNull ?? const <CardItem>[]).map((c) => c.linkSource).toSet();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KColors.primary,
          onRefresh: () => ref.refresh(linksProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.lg, KSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.linksTitle, style: t.displayLarge),
                      Text(s.linksSubtitle, style: t.bodyMedium),
                      const SizedBox(height: KSpacing.lg),
                      TextField(
                        onChanged: (v) => setState(() => _query = v.trim()),
                        decoration: InputDecoration(hintText: s.searchLinks, prefixIcon: const Icon(Icons.search_rounded), isDense: true),
                      ),
                      if (present.length > 1) ...[
                        const SizedBox(height: KSpacing.md),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(label: Text(s.all), selected: _source == null, onSelected: (_) => setState(() => _source = null)),
                              ),
                              for (final src in LinkSource.values.where(present.contains))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(src.label),
                                    selected: _source == src,
                                    selectedColor: SourceBadge.colorOf(src),
                                    onSelected: (_) => setState(() => _source = _source == src ? null : src),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ...linksAsync.when<List<Widget>>(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => [const SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
                error: (e, _) => [SliverFillRemaining(child: ErrorState(onRetry: () => ref.invalidate(linksProvider)))],
                data: (links) {
                  if (links.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(emoji: '🔗', title: s.emptyLinksTitle, body: s.emptyLinksBody),
                      ),
                    ];
                  }
                  final filtered = links.where(_matches).toList();
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.md, KSpacing.lg, 120),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
                        itemBuilder: (context, i) => _LinkTile(card: filtered[i]),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.card});
  final CardItem card;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final color = card.boardColor ?? KColors.brown;
    return Surface(
      padding: const EdgeInsets.all(KSpacing.md),
      onTap: () => openExternal(card.url!),
      child: Row(
        children: [
          SourceBadge(source: card.linkSource, size: 40),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.domain ?? card.linkSource.label, style: t.bodySmall),
                Text(
                  (card.title ?? '').isNotEmpty ? card.title! : (card.url ?? ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium,
                ),
                if (card.boardName != null) ...[
                  const SizedBox(height: 6),
                  DotChip(
                    label: card.boardName!,
                    color: color,
                    dense: true,
                    onTap: () => context.go('/boards/${card.boardId}'),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: KColors.t3),
            onSelected: (v) {
              if (v == 'board') context.go('/boards/${card.boardId}');
              if (v == 'open') openExternal(card.url!);
              if (v == 'copy') showSnack(context, card.url!);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'open', child: Text(s.openLink)),
              PopupMenuItem(value: 'board', child: Text(s.openBoard)),
            ],
          ),
        ],
      ),
    );
  }
}
