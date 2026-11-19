import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sharedPrefsProvider).setBool(onboardingSeenKey, true);
    if (!mounted) return;
    final from = widget.from;
    context.go(from == null ? '/auth' : '/auth?from=${Uri.encodeComponent(from)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final slides = [
      _Slide(art: const _Mosaic(), title: s.onb1Title, body: s.onb1Body),
      _Slide(art: const _ShareArt(), title: s.onb2Title, body: s.onb2Body),
      _Slide(art: const _PlanArt(), title: s.onb3Title, body: s.onb3Body),
    ];
    final last = _index == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(KSpacing.xl, KSpacing.md, KSpacing.md, 0),
                  child: Row(
                    children: [
                      Text('Keevy', style: Theme.of(context).textTheme.displayMedium),
                      const Spacer(),
                      if (!last) TextButton(onPressed: _finish, child: Text(s.skip)),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: slides,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index ? KColors.primary : KColors.border,
                          borderRadius: const BorderRadius.all(KRadius.full),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: last
                          ? _finish
                          : () => _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                      child: Text(last ? s.start : s.next),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});
  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: art)),
          Text(title, style: t.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: KSpacing.md),
          Text(body, style: t.bodyLarge?.copyWith(color: KColors.t2), textAlign: TextAlign.center),
          const SizedBox(height: KSpacing.xl),
        ],
      ),
    );
  }
}

/// Simple illustrations drawn with containers (no image assets needed).
class _Mosaic extends StatelessWidget {
  const _Mosaic();

  @override
  Widget build(BuildContext context) {
    Widget tile(Color c, double h, String emoji) => Container(
          height: h,
          margin: const EdgeInsets.all(5),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.all(KRadius.md), boxShadow: KShadows.soft),
          child: Text(emoji, style: const TextStyle(fontSize: 30)),
        );
    return SizedBox(
      width: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: [tile(KColors.pink.tint(0.35), 150, '💐'), tile(KColors.sage.tint(0.3), 90, '🕯️')])),
          Expanded(child: Column(children: [tile(KColors.amber.tint(0.3), 90, '🎂'), tile(KColors.slate.tint(0.3), 150, '👗')])),
        ],
      ),
    );
  }
}

class _ShareArt extends StatelessWidget {
  const _ShareArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: const BoxDecoration(color: KColors.white, borderRadius: BorderRadius.all(KRadius.lg), boxShadow: KShadows.lifted),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 110, decoration: BoxDecoration(color: KColors.brown.tint(0.25), borderRadius: const BorderRadius.all(KRadius.md))),
          const SizedBox(height: KSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final c in [const Color(0xFFD6336C), const Color(0xFF111111), KColors.primary])
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.all(KRadius.sm)),
                  child: c == KColors.primary
                      ? const Center(child: Text('K', style: TextStyle(fontFamily: KFonts.serif, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanArt extends StatelessWidget {
  const _PlanArt();

  @override
  Widget build(BuildContext context) {
    Widget row(bool done, double w) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined, color: done ? KColors.ok : KColors.t3, size: 20),
              const SizedBox(width: 10),
              Container(width: w, height: 10, decoration: BoxDecoration(color: KColors.surf2, borderRadius: BorderRadius.circular(5))),
            ],
          ),
        );
    return Container(
      width: 250,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: const BoxDecoration(color: KColors.white, borderRadius: BorderRadius.all(KRadius.lg), boxShadow: KShadows.lifted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('J-128', style: TextStyle(fontFamily: KFonts.serif, fontSize: 28, fontWeight: FontWeight.w700, color: KColors.t1)),
          const SizedBox(height: 4),
          const ClipRRect(
            borderRadius: BorderRadius.all(KRadius.full),
            child: LinearProgressIndicator(value: 0.4, minHeight: 6, color: KColors.ok, backgroundColor: KColors.surf2),
          ),
          const SizedBox(height: KSpacing.md),
          row(true, 140),
          row(true, 110),
          row(false, 150),
          row(false, 90),
        ],
      ),
    );
  }
}
