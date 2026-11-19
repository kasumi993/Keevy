
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../auth/application/auth_providers.dart';
import 'billing_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;

  BillingService get _billing => ref.read(billingServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final packages = await _billing.packages();
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _selected = packages.where((p) => p.packageType == PackageType.annual).firstOrNull ?? packages.firstOrNull;
      });
    } catch (e) {
      debugPrint('offerings failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The webhook updates profiles.is_premium a few seconds after the purchase.
  Future<void> _waitForServer() async {
    for (var i = 0; i < 6; i++) {
      await ref.read(profileProvider.notifier).reload();
      if (ref.read(isPremiumProvider)) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _purchase() async {
    final package = _selected;
    if (package == null) return;
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final active = await _billing.purchase(package);
      if (!active) return;
      await _waitForServer();
      if (!mounted) return;
      showSnack(context, s.purchaseSuccess);
      context.pop();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final active = await _billing.restore();
      if (active) await _waitForServer();
      if (!mounted) return;
      showSnack(context, active ? s.purchaseSuccess : s.restoreNothing);
      if (active) context.pop();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final premium = ref.watch(isPremiumProvider);
    final supported = _billing.isSupported;

    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpacing.xl, 0, KSpacing.xl, KSpacing.xl),
              children: [
                const Text('✨', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
                const SizedBox(height: KSpacing.sm),
                Text(s.paywallTitle, style: t.displayLarge, textAlign: TextAlign.center),
                const SizedBox(height: KSpacing.xs),
                Text(s.paywallSubtitle, style: t.bodyLarge?.copyWith(color: KColors.t2), textAlign: TextAlign.center),
                const SizedBox(height: KSpacing.xl),
                for (final benefit in [s.benefitUnlimitedProjets, s.benefitCollab, s.benefitFuture, s.benefitIndie])
                  Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: KColors.ok, size: 22),
                        const SizedBox(width: KSpacing.md),
                        Expanded(child: Text(benefit, style: t.bodyLarge)),
                      ],
                    ),
                  ),
                const SizedBox(height: KSpacing.lg),
                if (premium)
                  Surface(child: Text(s.alreadyPremium, style: t.titleMedium, textAlign: TextAlign.center))
                else if (kIsWeb || !supported)
                  Surface(child: Text(kIsWeb ? s.paywallWebNote : s.paywallUnavailable, style: t.bodyMedium, textAlign: TextAlign.center))
                else if (_loading)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else if (_packages.isEmpty)
                  Surface(child: Text(s.paywallUnavailable, style: t.bodyMedium, textAlign: TextAlign.center))
                else ...[
                  for (final p in _packages) ...[
                    _PlanTile(package: p, selected: _selected == p, onTap: () => setState(() => _selected = p)),
                    const SizedBox(height: KSpacing.sm),
                  ],
                  const SizedBox(height: KSpacing.md),
                  BusyButton(label: s.subscribe, busy: _busy, onPressed: _purchase),
                  const SizedBox(height: KSpacing.sm),
                  Text(s.legalSubscription, style: t.bodySmall, textAlign: TextAlign.center),
                ],
                if (!premium && supported && !kIsWeb)
                  TextButton(onPressed: _busy ? null : _restore, child: Text(s.restore)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () => context.push('/terms'), child: Text(s.terms, style: t.bodySmall)),
                    TextButton(onPressed: () => context.push('/privacy'), child: Text(s.privacy, style: t.bodySmall)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.package, required this.selected, required this.onTap});
  final Package package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    final annual = package.packageType == PackageType.annual;
    final period = annual ? s.perYear : s.perMonth;
    return Material(
      color: selected ? KColors.primary : KColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(KRadius.md),
        side: BorderSide(color: selected ? KColors.primary : KColors.border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(KRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  annual ? s.yearly : s.monthly,
                  style: t.titleLarge?.copyWith(color: selected ? Colors.white : KColors.t1),
                ),
              ),
              if (annual) ...[
                DotChip(label: s.bestValue, color: KColors.amber, filled: true, dense: true),
                const SizedBox(width: KSpacing.sm),
              ],
              Text(
                '${package.storeProduct.priceString}$period',
                style: t.titleMedium?.copyWith(color: selected ? Colors.white : KColors.t1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
