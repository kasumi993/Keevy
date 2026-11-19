import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/tokens.dart';

/// Shown when the app was built without Supabase keys.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Keevy', style: t.displayLarge),
                  const SizedBox(height: KSpacing.xl),
                  const Icon(Icons.settings_suggest_outlined, size: 44, color: KColors.t3),
                  const SizedBox(height: KSpacing.lg),
                  Text(s.setupTitle, style: t.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: KSpacing.sm),
                  Text(s.setupBody, style: t.bodyMedium, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
