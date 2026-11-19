import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/k_image.dart';
import '../../domain/board.dart';

/// Mosaic of up to 4 preview images (or the board colour + emoji).
class BoardMosaic extends StatelessWidget {
  const BoardMosaic({super.key, required this.board, this.height = 120});
  final Board board;
  final double height;

  @override
  Widget build(BuildContext context) {
    final previews = board.previews.take(4).toList();
    final bg = board.color.withValues(alpha: 0.18);
    Widget img(int i) => KImage(path: previews[i].path, url: previews[i].url, placeholderColor: bg);

    final Widget content;
    if (previews.isEmpty) {
      content = Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(board.displayEmoji, style: const TextStyle(fontSize: 34)),
      );
    } else if (previews.length == 1) {
      content = img(0);
    } else if (previews.length == 2) {
      content = Row(children: [Expanded(child: img(0)), const SizedBox(width: 2), Expanded(child: img(1))]);
    } else if (previews.length == 3) {
      content = Row(children: [
        Expanded(flex: 3, child: img(0)),
        const SizedBox(width: 2),
        Expanded(flex: 2, child: Column(children: [Expanded(child: img(1)), const SizedBox(height: 2), Expanded(child: img(2))])),
      ]);
    } else {
      content = Column(children: [
        Expanded(child: Row(children: [Expanded(child: img(0)), const SizedBox(width: 2), Expanded(child: img(1))])),
        const SizedBox(height: 2),
        Expanded(child: Row(children: [Expanded(child: img(2)), const SizedBox(width: 2), Expanded(child: img(3))])),
      ]);
    }
    return SizedBox(height: height, width: double.infinity, child: content);
  }
}

/// Inspiration board tile (2-column grid on the home screen).
class InspirationBoardTile extends StatelessWidget {
  const InspirationBoardTile({super.key, required this.board, required this.onTap});
  final Board board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: KColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(KRadius.lg),
        side: BorderSide(color: KColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BoardMosaic(board: board, height: 118),
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(board.displayEmoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(board.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(s.inspirationsCount(board.cardCount), style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Projet board card: countdown, progress and previews.
class ProjetBoardCard extends StatelessWidget {
  const ProjetBoardCard({super.key, required this.board, required this.onTap});
  final Board board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final date = board.targetDate;
    final days = date == null ? null : daysUntil(date);
    final countdown = days == null
        ? null
        : days > 0
            ? s.daysLeft(days)
            : days == 0
                ? s.dDay
                : s.datePassed;

    return Material(
      color: KColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(KRadius.lg),
        side: BorderSide(color: KColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: board.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(board.displayEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(board.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
                        ),
                        if (countdown != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: board.color.withValues(alpha: 0.14),
                              borderRadius: const BorderRadius.all(KRadius.full),
                            ),
                            child: Text(
                              countdown,
                              style: TextStyle(fontFamily: KFonts.sans, fontSize: 12, fontWeight: FontWeight.w700, color: board.color),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (date != null) formatLongDate(date, locale),
                        s.inspirationsCount(board.cardCount),
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                    if (board.taskCount > 0) ...[
                      const SizedBox(height: KSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(KRadius.full),
                              child: LinearProgressIndicator(
                                value: board.progress,
                                minHeight: 6,
                                color: KColors.ok,
                                backgroundColor: KColors.surf2,
                              ),
                            ),
                          ),
                          const SizedBox(width: KSpacing.md),
                          Text(s.tasksProgress(board.taskDoneCount, board.taskCount), style: t.labelMedium),
                        ],
                      ),
                    ],
                    if (board.previews.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.md),
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            for (final p in board.previews.take(4))
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.all(KRadius.sm),
                                  child: SizedBox(width: 52, height: 52, child: KImage(path: p.path, url: p.url)),
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
          ],
        ),
      ),
    );
  }
}
