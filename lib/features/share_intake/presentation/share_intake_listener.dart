import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/dialogs.dart';
import '../share_channel.dart';
import '../share_intake_controller.dart';
import 'share_sheet.dart';

/// Shows the share sheet for each incoming item, one at a time.
class ShareIntakeListener extends ConsumerStatefulWidget {
  const ShareIntakeListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShareIntakeListener> createState() => _ShareIntakeListenerState();
}

class _ShareIntakeListenerState extends ConsumerState<ShareIntakeListener> {
  bool _showing = false;
  late final ShareIntakeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(shareIntakeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _controller.importedCount.addListener(_onImported);
      _controller.start();
      await _controller.retryAfterSignIn();
      if (mounted && ref.read(shareIntakeProvider).isNotEmpty) await _showNext();
    });
  }

  @override
  void dispose() {
    _controller.importedCount.removeListener(_onImported);
    super.dispose();
  }

  void _onImported() {
    final n = _controller.importedCount.value;
    if (n > 0 && mounted) {
      showSnack(context, S.of(context).importedFromShare(n));
      _controller.importedCount.value = 0;
    }
  }

  Future<void> _showNext() async {
    if (_showing || !mounted) return;
    final queue = ref.read(shareIntakeProvider);
    if (queue.isEmpty) return;
    _showing = true;
    final item = queue.first;
    final result = await showKSheet<String>(context, builder: (_) => ShareSheet(item: item));
    _controller.pop();
    _showing = false;
    if (!mounted) return;
    if (result != null) {
      showSnack(context, result);
      if (ref.read(shareIntakeProvider).isEmpty) await ShareChannel.instance.finishShareActivity();
    }
    if (mounted && ref.read(shareIntakeProvider).isNotEmpty) await _showNext();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<SharedItem>>(shareIntakeProvider, (previous, next) {
      if (next.isNotEmpty && !_showing) _showNext();
    });
    return widget.child;
  }
}
