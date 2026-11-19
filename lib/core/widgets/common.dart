import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../theme/tokens.dart';
import '../utils/link_detector.dart';

/// Loading / error / data switch for AsyncValue with Keevy styling.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => ErrorState(onRetry: onRetry),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.onRetry, this.message});
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: KColors.t3),
            const SizedBox(height: KSpacing.md),
            Text(message ?? s.errGeneric, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: KSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: Text(s.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, required this.body, this.action});

  final String emoji;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.xxl, vertical: KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: KColors.white, shape: BoxShape.circle, boxShadow: KShadows.soft),
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: KSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: t.displaySmall),
            const SizedBox(height: KSpacing.sm),
            Text(body, textAlign: TextAlign.center, style: t.bodyMedium),
            if (action != null) ...[const SizedBox(height: KSpacing.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Small rounded label with a coloured dot.
class DotChip extends StatelessWidget {
  const DotChip({super.key, required this.label, required this.color, this.filled = false, this.onTap, this.dense = false});

  final String label;
  final Color color;
  final bool filled;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(KRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!filled) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: KFonts.sans,
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: filled ? color.onColor : color,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

/// Initials avatar with a stable colour derived from the name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.initials, required this.seed, this.size = 44});

  final String initials;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = KColors.boardAccents[seed.hashCode.abs() % KColors.boardAccents.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(fontFamily: KFonts.serif, fontWeight: FontWeight.w700, fontSize: size * 0.36, color: color),
      ),
    );
  }
}

/// Coloured square with the platform icon (Instagram, TikTok…).
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, this.size = 32});
  final LinkSource source;
  final double size;

  static Color colorOf(LinkSource s) => switch (s) {
        LinkSource.instagram => const Color(0xFFD6336C),
        LinkSource.tiktok => const Color(0xFF111111),
        LinkSource.pinterest => const Color(0xFFE60023),
        LinkSource.twitter => const Color(0xFF14171A),
        LinkSource.youtube => const Color(0xFFFF0000),
        LinkSource.facebook => const Color(0xFF1877F2),
        LinkSource.web => KColors.slate,
      };

  static IconData iconOf(LinkSource s) => switch (s) {
        LinkSource.instagram => Icons.camera_alt_outlined,
        LinkSource.tiktok => Icons.music_note_rounded,
        LinkSource.pinterest => Icons.push_pin_outlined,
        LinkSource.twitter => Icons.alternate_email_rounded,
        LinkSource.youtube => Icons.play_arrow_rounded,
        LinkSource.facebook => Icons.facebook_rounded,
        LinkSource.web => Icons.language_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colorOf(source), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(iconOf(source), color: Colors.white, size: size * 0.56),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.xl, KSpacing.lg, KSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.1)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// White rounded surface used for list groups and cards.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding, this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? KColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(KRadius.md),
        side: BorderSide(color: KColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(KSpacing.lg), child: child),
      ),
    );
  }
}

/// Filled button with a built-in spinner.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
  }
}
