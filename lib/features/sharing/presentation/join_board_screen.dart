import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/errors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../boards/application/boards_providers.dart';
import '../application/sharing_providers.dart';

/// Collaborative link (`/join/<token>`): the signed-in user becomes a collaborator.
class JoinBoardScreen extends ConsumerStatefulWidget {
  const JoinBoardScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<JoinBoardScreen> createState() => _JoinBoardScreenState();
}

class _JoinBoardScreenState extends ConsumerState<JoinBoardScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _join() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final boardId = await ref.read(sharesRepositoryProvider).accept(widget.token);
      await ref.read(boardsProvider.notifier).refresh();
      if (!mounted) return;
      showSnack(context, s.joinedBoard);
      context.go('/boards/$boardId');
    } catch (e) {
      if (!mounted) return;
      final code = KeevyException.from(e).code;
      if (code == KeevyErrorCode.shareReadOnly) {
        context.go('/s/${widget.token}');
        return;
      }
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final preview = ref.watch(sharedBoardProvider(widget.token)).valueOrNull;
    return Scaffold(
      appBar: AppBar(leading: CloseButton(onPressed: () => context.go('/boards'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: _failed
                ? EmptyState(emoji: '🔒', title: s.sharedLinkInvalid, body: '')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preview?.board.displayEmoji ?? '🤝', style: const TextStyle(fontSize: 52)),
                      const SizedBox(height: KSpacing.md),
                      Text(preview?.board.name ?? s.joinBoard, style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
                      if (preview != null && preview.ownerName.isNotEmpty) ...[
                        const SizedBox(height: KSpacing.xs),
                        Text(s.sharedBoardBy(preview.ownerName), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: KSpacing.xl),
                      SizedBox(width: double.infinity, child: BusyButton(label: s.joinBoard, busy: _busy, onPressed: _join)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
