import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';

class KeevyApp extends ConsumerWidget {
  const KeevyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeOverrideProvider);
    return MaterialApp.router(
      title: 'Keevy',
      debugShowCheckedModeBanner: false,
      theme: KeevyTheme.light,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      localeResolutionCallback: (device, supported) =>
          device?.languageCode == 'en' ? const Locale('en') : const Locale('fr'),
    );
  }
}
