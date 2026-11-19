import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../auth/application/auth_providers.dart';
import '../../boards/domain/board.dart';
import '../application/sharing_providers.dart';
import '../domain/board_share.dart';

Future<void> showShareLinksSheet(BuildContext context, Board board) {
  return showKSheet<void>(context, builder: (_) => ShareLinksSheet(board: board));
}

/// Private by default: share one board by link, read-only (free) or collaborative (Premium).
class ShareLinksSheet extends ConsumerWidget {
  const ShareLinksSheet({super.key, required this.board});
  final Board board;

  Future<void> _create(BuildContext context, WidgetRef ref, ShareAccess access) async {
    try {
      final share = await ref.read(boardSharesProvider(board.id).notifier).create(access);
      await Clipboard.setData(ClipboardData(text: share.url));
      if (context.mounted) showSnack(context, S.of(context).linkCopied);
    } catch (e) {
      if (context.mounted) handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final sharesAsync = ref.watch(boardSharesProvider(board.id));
    final isPremium = ref.watch(isPremiumProvider);
    final shares = sharesAsync.valueOrNull ?? const <BoardShare>[];
    final read = shares.where((x) => x.access == ShareAccess.read).toList();
    final edit = shares.where((x) => x.access == ShareAccess.edit).toList();

    Widget block({
      required String emoji,
      required String title,
      required String desc,
      required List<BoardShare> links,
      required ShareAccess access,
      bool premium = false,
    }) {
      return Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: KSpacing.md),
                Expanded(child: Text(title, style: t.titleLarge)),
                if (premium && !isPremium) const DotChip(label: 'Premium', color: KColors.amber, filled: true, dense: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(desc, style: t.bodyMedium),
            const SizedBox(height: KSpacing.md),
            for (final link in links)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(color: KColors.surf, borderRadius: BorderRadius.all(KRadius.sm)),
                        child: Text(link.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: KColors.t1)),
                      ),
                    ),
                    IconButton(
                      tooltip: s.copyLink,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link.url));
                        if (context.mounted) showSnack(context, s.linkCopied);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: s.revokeLink,
                      onPressed: () => ref.read(boardSharesProvider(board.id).notifier).revoke(link),
                      icon: const Icon(Icons.link_off_rounded, size: 20, color: KColors.err),
                    ),
                  ],
                ),
              ),
            if (links.isEmpty)
              OutlinedButton.icon(
                onPressed: () => _create(context, ref, access),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(s.createLink),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.shareTitle(board.name), style: t.displaySmall),
          const SizedBox(height: KSpacing.sm),
          Text(s.shareBody, style: t.bodyMedium),
          const SizedBox(height: KSpacing.lg),
          if (sharesAsync.isLoading && shares.isEmpty)
            const Padding(padding: EdgeInsets.all(KSpacing.xl), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            block(emoji: '👀', title: s.readLink, desc: s.readLinkDesc, links: read, access: ShareAccess.read),
            const SizedBox(height: KSpacing.md),
            block(emoji: '🤝', title: s.editLink, desc: s.editLinkDesc, links: edit, access: ShareAccess.edit, premium: true),
          ],
        ],
      ),
    );
  }
}
