import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../contacts/presentation/contact_sheet.dart';
import '../application/boards_providers.dart';
import '../domain/board.dart';
import '../domain/card_item.dart';
import '../domain/section.dart';
import 'add_card_sheet.dart';
import 'card_detail_sheet.dart';
import 'widgets/card_tile.dart';

/// Sections as horizontal pages (sticky chips on top), masonry grid inside each.
class InspirationTab extends ConsumerStatefulWidget {
  const InspirationTab({super.key, required this.board});
  final Board board;

  @override
  ConsumerState<InspirationTab> createState() => _InspirationTabState();
}

/// A page of the board: a real section, or the virtual "Unsorted" bucket (id null).
class _Page {
  const _Page(this.id, this.name);
  final String? id;
  final String name;
}

class _InspirationTabState extends ConsumerState<InspirationTab> with AutomaticKeepAliveClientMixin {
  final _pageController = PageController();
  int _index = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_Page> _pagesOf(BoardContent content, S s) => [
        for (final section in content.sections) _Page(section.id, section.name),
        if (content.hasUnsorted || content.sections.isEmpty) _Page(null, s.unsorted),
      ];

  void _goTo(int i) {
    setState(() => _index = i);
    if (_pageController.hasClients) {
      _pageController.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _addSection() async {
    final s = S.of(context);
    final name = await promptText(context, title: s.newSection, hint: s.sectionName, confirmLabel: s.add);
    if (name == null) return;
    try {
      await ref.read(boardContentProvider(widget.board.id).notifier).addSection(name);
      final content = ref.read(boardContentProvider(widget.board.id)).valueOrNull;
      if (content != null && mounted) {
        final pages = _pagesOf(content, s);
        final i = pages.indexWhere((p) => p.name == name);
        if (i >= 0) WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(i));
      }
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  Future<void> _sectionMenu(Section section) async {
    final s = S.of(context);
    final action = await showKSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(s.renameSection), onTap: () => Navigator.pop(ctx, 'rename')),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: KColors.err),
              title: Text(s.deleteSection, style: const TextStyle(color: KColors.err)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final notifier = ref.read(boardContentProvider(widget.board.id).notifier);
    try {
      if (action == 'rename') {
        final name = await promptText(context, title: s.renameSection, initial: section.name);
        if (name != null) await notifier.renameSection(section.id, name);
      } else if (action == 'delete') {
        final ok = await confirmAction(context, title: s.deleteSection, body: s.deleteSectionBody, confirmLabel: s.delete);
        if (ok) {
          await notifier.deleteSection(section.id);
          if (mounted) setState(() => _index = 0);
        }
      }
    } catch (e) {
      if (mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final contentAsync = ref.watch(boardContentProvider(widget.board.id));

    return AsyncBody<BoardContent>(
      value: contentAsync,
      onRetry: () => ref.invalidate(boardContentProvider(widget.board.id)),
      data: (content) {
        final pages = _pagesOf(content, s);
        final index = _index.clamp(0, pages.length - 1);
        final current = pages[index];
        return Stack(
          children: [
            Column(
              children: [
                _VendorStrip(boardId: widget.board.id),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg, vertical: KSpacing.sm),
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: KSpacing.sm),
                          child: GestureDetector(
                            onLongPress: pages[i].id == null
                                ? null
                                : () => _sectionMenu(content.sections.firstWhere((x) => x.id == pages[i].id)),
                            child: ChoiceChip(
                              label: Text('${pages[i].name}  ${content.cardsIn(pages[i].id).length}'),
                              selected: i == index,
                              selectedColor: widget.board.color,
                              labelStyle: TextStyle(
                                fontFamily: KFonts.sans,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: i == index ? widget.board.color.onColor : KColors.t1,
                              ),
                              onSelected: (_) => _goTo(i),
                            ),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: Text(s.addSection),
                        onPressed: _addSection,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _SectionPage(
                      board: widget.board,
                      cards: content.cardsIn(pages[i].id),
                      sectionId: pages[i].id,
                      onSectionMenu: pages[i].id == null
                          ? null
                          : () => _sectionMenu(content.sections.firstWhere((x) => x.id == pages[i].id)),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: KSpacing.lg,
              bottom: KSpacing.lg,
              child: FloatingActionButton(
                heroTag: 'add-card-${widget.board.id}',
                onPressed: () => showAddCardSheet(context, board: widget.board, sectionId: current.id),
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionPage extends ConsumerWidget {
  const _SectionPage({required this.board, required this.cards, required this.sectionId, this.onSectionMenu});

  final Board board;
  final List<CardItem> cards;
  final String? sectionId;
  final VoidCallback? onSectionMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    if (cards.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            emoji: '🪄',
            title: s.emptySectionTitle,
            body: s.emptySectionBody,
            action: OutlinedButton.icon(
              onPressed: () => showAddCardSheet(context, board: board, sectionId: sectionId),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.add),
            ),
          ),
        ],
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 900 ? 4 : (width > 600 ? 3 : 2);
    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: () => ref.read(boardContentProvider(board.id).notifier).reload(),
      child: MasonryGridView.count(
        padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.xs, KSpacing.lg, 110),
        crossAxisCount: columns,
        mainAxisSpacing: KSpacing.md,
        crossAxisSpacing: KSpacing.md,
        itemCount: cards.length,
        itemBuilder: (context, i) {
          final card = cards[i];
          return CardTile(
            card: card,
            onTap: () => showCardDetailSheet(context, board: board, card: card),
            onLongPress: () => showCardQuickActions(context, ref, board: board, card: card),
          );
        },
      ),
    );
  }
}

/// Vendors linked to the board, always one tap away (both modes).
class _VendorStrip extends ConsumerWidget {
  const _VendorStrip({required this.boardId});
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(boardVendorsProvider(boardId)).valueOrNull ?? const [];
    if (vendors.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.sm, KSpacing.lg, 0),
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: KSpacing.sm),
        itemBuilder: (context, i) {
          final v = vendors[i];
          return ActionChip(
            avatar: InitialsAvatar(initials: v.contact.initials, seed: v.contact.id, size: 22),
            label: Text(v.contact.name),
            onPressed: () => showContactSheet(context, v.contact.id),
          );
        },
      ),
    );
  }
}
