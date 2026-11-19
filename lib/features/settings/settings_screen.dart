import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../auth/application/auth_providers.dart';
import '../premium/billing_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(billingServiceProvider).reset();
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (mounted) handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final s = S.of(context);
    final ok = await confirmAction(context, title: s.deleteAccount, body: s.deleteAccountBody, confirmLabel: s.deleteAccountConfirm);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(billingServiceProvider).reset();
      await ref.read(authRepositoryProvider).deleteAccount();
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
    final profile = ref.watch(profileProvider).valueOrNull;
    final premium = ref.watch(isPremiumProvider);
    final locale = ref.watch(localeOverrideProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.sm, KSpacing.lg, KSpacing.xxl),
        children: [
          SectionTitle(s.account, padding: const EdgeInsets.fromLTRB(KSpacing.xs, KSpacing.md, 0, KSpacing.sm)),
          Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(profile?.displayName ?? s.displayName),
                  subtitle: Text(profile?.email ?? ''),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    final name = await promptText(context, title: s.displayName, initial: profile?.displayName);
                    if (name != null) await ref.read(profileProvider.notifier).updateName(name);
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(premium ? Icons.workspace_premium_rounded : Icons.star_outline_rounded, color: premium ? KColors.amber : null),
                  title: Text(premium ? s.planPremium : s.planFree),
                  subtitle: Text(premium ? s.alreadyPremium : s.planFreeDesc),
                  trailing: premium ? null : FilledButton(
                    onPressed: () => context.push('/paywall'),
                    style: FilledButton.styleFrom(minimumSize: const Size(40, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: Text(s.upgrade),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(s.language, padding: const EdgeInsets.fromLTRB(KSpacing.xs, KSpacing.xl, 0, KSpacing.sm)),
          Wrap(
            spacing: KSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(s.languageSystem),
                selected: locale == null,
                onSelected: (_) => ref.read(localeOverrideProvider.notifier).set(null),
              ),
              ChoiceChip(
                label: const Text('Français'),
                selected: locale?.languageCode == 'fr',
                onSelected: (_) {
                  ref.read(localeOverrideProvider.notifier).set(const Locale('fr'));
                  ref.read(profileProvider.notifier).updateLocale('fr');
                },
              ),
              ChoiceChip(
                label: const Text('English'),
                selected: locale?.languageCode == 'en',
                onSelected: (_) {
                  ref.read(localeOverrideProvider.notifier).set(const Locale('en'));
                  ref.read(profileProvider.notifier).updateLocale('en');
                },
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xl),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.ios_share_rounded, size: 20),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(child: Text(s.shareExtensionHelp, style: t.titleMedium)),
                  ],
                ),
                const SizedBox(height: KSpacing.sm),
                Text(s.shareExtensionHelpBody, style: t.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(s.privacy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/privacy'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(s.terms),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          OutlinedButton.icon(
            onPressed: _busy ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(s.signOut),
          ),
          const SizedBox(height: KSpacing.sm),
          TextButton(
            onPressed: _busy ? null : _deleteAccount,
            style: TextButton.styleFrom(foregroundColor: KColors.err),
            child: Text(s.deleteAccount),
          ),
          const SizedBox(height: KSpacing.lg),
          Center(child: Text('Keevy · ${s.version(Env.appVersion)}', style: t.bodySmall)),
        ],
      ),
    );
  }
}
