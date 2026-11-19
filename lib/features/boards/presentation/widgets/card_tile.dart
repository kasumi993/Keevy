import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/link_detector.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/k_image.dart';
import '../../domain/card_item.dart';

/// Masonry tile for an inspiration card (image, link or note).
class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card, this.onTap, this.onLongPress});

  final CardItem card;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (card.kind) {
      CardKind.note => _NoteContent(card: card),
      CardKind.image => _ImageContent(card: card),
      CardKind.link => _LinkContent(card: card),
    };
    return Material(
      color: card.kind == CardKind.note ? _paperOf(card) : KColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(KRadius.md),
        side: BorderSide(color: card.kind == CardKind.note ? Colors.transparent : KColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            content,
            if (card.contactId != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: KColors.white, shape: BoxShape.circle, boxShadow: KShadows.soft),
                  child: const Icon(Icons.person_rounded, size: 13, color: KColors.t1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _paperOf(CardItem c) => KColors.notePapers[c.id.hashCode.abs() % KColors.notePapers.length];
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.card});
  final CardItem card;

  @override
  Widget build(BuildContext context) {
    final caption = card.title ?? card.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: card.aspectRatio ?? 0.8,
          child: KImage(path: card.imagePath, url: card.signedImageUrl ?? card.imageUrl),
        ),
        if (caption != null && caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KColors.t2)),
          ),
      ],
    );
  }
}

class _LinkContent extends StatelessWidget {
  const _LinkContent({required this.card});
  final CardItem card;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasImage = card.imageUrl != null || card.signedImageUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImage)
          AspectRatio(
            aspectRatio: card.linkSource.name == 'web' ? 1.4 : 0.8,
            child: KImage(url: card.signedImageUrl ?? card.imageUrl),
          ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SourceBadge(source: card.linkSource, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(card.domain ?? card.linkSource.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                  ),
                  const Icon(Icons.north_east_rounded, size: 13, color: KColors.t3),
                ],
              ),
              if ((card.title ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(card.title!, maxLines: hasImage ? 2 : 4, overflow: TextOverflow.ellipsis, style: t.titleSmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteContent extends StatelessWidget {
  const _NoteContent({required this.card});
  final CardItem card;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((card.title ?? '').isNotEmpty) ...[
            Text(card.title!, style: t.headlineSmall?.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
          ],
          if ((card.body ?? '').isNotEmpty)
            Text(card.body!, maxLines: 9, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: KColors.t1)),
        ],
      ),
    );
  }
}
