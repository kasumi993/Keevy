import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../theme/tokens.dart';
import '../utils/errors.dart';

/// Opens a Keevy bottom sheet (the mobile "slide-over": you never lose context).
Future<T?> showKSheet<T>(BuildContext context, {required WidgetBuilder builder, bool expand = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) {
      final content = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      );
      return expand ? FractionallySizedBox(heightFactor: 0.92, child: content) : content;
    },
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final s = S.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.lg)),
      title: Text(title, style: Theme.of(ctx).textTheme.displaySmall),
      content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: destructive ? KColors.err : KColors.primary),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String? confirmLabel,
}) async {
  final s = S.of(context);
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.lg)),
      title: Text(title, style: Theme.of(ctx).textTheme.displaySmall),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.cancel)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(confirmLabel ?? s.save)),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Maps any error to a friendly message, or to the paywall for freemium limits.
void handleError(BuildContext context, Object error) {
  final s = S.of(context);
  final e = KeevyException.from(error);
  switch (e.code) {
    case KeevyErrorCode.limitProjetBoards:
      _showLimitDialog(context, s.limitProjetTitle, s.limitProjetBody);
    case KeevyErrorCode.premiumRequiredEditShare:
      _showLimitDialog(context, s.premiumBadge, s.premiumRequiredEditShare);
    case KeevyErrorCode.shareNotFound:
      showSnack(context, s.sharedLinkInvalid);
    case KeevyErrorCode.network:
      showSnack(context, s.errNetwork);
    case KeevyErrorCode.shareReadOnly:
    case KeevyErrorCode.unknown:
      debugPrint('Keevy error: ${e.details}');
      showSnack(context, s.errGeneric);
  }
}

void _showLimitDialog(BuildContext context, String title, String body) {
  final s = S.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.lg)),
      title: Text(title, style: Theme.of(ctx).textTheme.displaySmall),
      content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.close)),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/paywall');
          },
          style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
          child: Text(s.upgrade),
        ),
      ],
    ),
  );
}
