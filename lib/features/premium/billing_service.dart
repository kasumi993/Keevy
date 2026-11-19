import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/env.dart';

/// RevenueCat wrapper. The source of truth for limits stays the server
/// (profiles.is_premium, updated by the revenuecat-webhook Edge Function).
class BillingService {
  bool _configured = false;

  bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => Env.revenueCatAppleKey.isNotEmpty,
      TargetPlatform.android => Env.revenueCatGoogleKey.isNotEmpty,
      _ => false,
    };
  }

  String get _apiKey => defaultTargetPlatform == TargetPlatform.iOS ? Env.revenueCatAppleKey : Env.revenueCatGoogleKey;

  /// RevenueCat app user id = Supabase user id, so the webhook knows whom to upgrade.
  Future<void> identify(String userId) async {
    if (!isSupported) return;
    try {
      if (!_configured) {
        final config = PurchasesConfiguration(_apiKey)..appUserID = userId;
        await Purchases.configure(config);
        _configured = true;
      } else {
        await Purchases.logIn(userId);
      }
    } catch (e) {
      debugPrint('RevenueCat identify failed: $e');
    }
  }

  Future<void> reset() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  Future<List<Package>> packages() async {
    if (!isSupported || !_configured) return const [];
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  /// Returns true when the premium entitlement is active after the purchase,
  /// false when the user cancelled.
  Future<bool> purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(Env.premiumEntitlement);
  }

  Future<bool> restore() async {
    if (!isSupported || !_configured) return false;
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(Env.premiumEntitlement);
  }
}

final billingServiceProvider = Provider<BillingService>((ref) => BillingService());
