import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevy/app.dart';
import 'package:keevy/core/providers.dart';
import 'package:keevy/core/widgets/common.dart';
import 'package:keevy/features/settings/legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('without Supabase keys the app shows the setup screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const KeevyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keevy'), findsWidgets);
    expect(find.byIcon(Icons.settings_suggest_outlined), findsOneWidget);
  });

  testWidgets('legal screen renders in English', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('fr')],
        home: LegalScreen(kind: LegalKind.privacy),
      ),
    );
    expect(find.text('In short'), findsOneWidget);
  });

  testWidgets('EmptyState shows its texts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyState(emoji: '🌸', title: 'Titre', body: 'Corps'))),
    );
    expect(find.text('Titre'), findsOneWidget);
    expect(find.text('Corps'), findsOneWidget);
  });
}
