import 'package:flutter/material.dart';

import 'tokens.dart';

class KeevyTheme {
  KeevyTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: KColors.primary,
      onPrimary: KColors.white,
      secondary: KColors.brown,
      onSecondary: KColors.white,
      surface: KColors.bg,
      onSurface: KColors.t1,
      surfaceContainerHighest: KColors.surf,
      surfaceContainerHigh: KColors.surf2,
      surfaceContainer: KColors.white,
      outline: KColors.border,
      outlineVariant: KColors.border,
      error: KColors.err,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: KFonts.serif, fontSize: 30, fontWeight: FontWeight.w700, color: KColors.t1, height: 1.15),
      displayMedium: TextStyle(fontFamily: KFonts.serif, fontSize: 24, fontWeight: FontWeight.w700, color: KColors.t1, height: 1.2),
      displaySmall: TextStyle(fontFamily: KFonts.serif, fontSize: 20, fontWeight: FontWeight.w700, color: KColors.t1, height: 1.25),
      headlineSmall: TextStyle(fontFamily: KFonts.serif, fontSize: 18, fontWeight: FontWeight.w700, color: KColors.t1),
      titleLarge: TextStyle(fontFamily: KFonts.sans, fontSize: 16, fontWeight: FontWeight.w700, color: KColors.t1),
      titleMedium: TextStyle(fontFamily: KFonts.sans, fontSize: 14, fontWeight: FontWeight.w700, color: KColors.t1),
      titleSmall: TextStyle(fontFamily: KFonts.sans, fontSize: 12, fontWeight: FontWeight.w700, color: KColors.t1),
      bodyLarge: TextStyle(fontFamily: KFonts.sans, fontSize: 15, fontWeight: FontWeight.w400, color: KColors.t1, height: 1.4),
      bodyMedium: TextStyle(fontFamily: KFonts.sans, fontSize: 13, fontWeight: FontWeight.w400, color: KColors.t2, height: 1.4),
      bodySmall: TextStyle(fontFamily: KFonts.sans, fontSize: 11, fontWeight: FontWeight.w400, color: KColors.t3),
      labelLarge: TextStyle(fontFamily: KFonts.sans, fontSize: 14, fontWeight: FontWeight.w700, color: KColors.t1),
      labelMedium: TextStyle(fontFamily: KFonts.sans, fontSize: 12, fontWeight: FontWeight.w700, color: KColors.t2),
      labelSmall: TextStyle(fontFamily: KFonts.sans, fontSize: 10, fontWeight: FontWeight.w700, color: KColors.t3, letterSpacing: 0.4),
    );

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(KRadius.md),
      borderSide: BorderSide(color: KColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KColors.bg,
      fontFamily: KFonts.sans,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: KColors.bg,
        foregroundColor: KColors.t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: KFonts.serif, fontSize: 20, fontWeight: FontWeight.w700, color: KColors.t1),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KColors.white,
        indicatorColor: KColors.primary.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: KFonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? KColors.primary : KColors.t3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? KColors.primary : KColors.t3, size: 24);
        }),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: KColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(KRadius.md),
          borderSide: BorderSide(color: KColors.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: KColors.t3, fontFamily: KFonts.sans),
        labelStyle: TextStyle(color: KColors.t2, fontFamily: KFonts.sans),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KColors.primary,
          foregroundColor: KColors.white,
          minimumSize: const Size(48, 52),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.md)),
          textStyle: const TextStyle(fontFamily: KFonts.sans, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KColors.t1,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: KColors.border),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.md)),
          textStyle: const TextStyle(fontFamily: KFonts.sans, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KColors.t1,
          textStyle: const TextStyle(fontFamily: KFonts.sans, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.lg)),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: KColors.white,
        selectedColor: KColors.primary,
        side: BorderSide(color: KColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.full)),
        labelStyle: TextStyle(fontFamily: KFonts.sans, fontSize: 12, fontWeight: FontWeight.w700, color: KColors.t1),
        secondaryLabelStyle: TextStyle(fontFamily: KFonts.sans, fontSize: 12, fontWeight: FontWeight.w700, color: KColors.white),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KColors.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: KColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: KRadius.xl)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KColors.primary,
        contentTextStyle: TextStyle(fontFamily: KFonts.sans, color: KColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.md)),
      ),
      dividerTheme: const DividerThemeData(color: KColors.border, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: KColors.t2,
        titleTextStyle: TextStyle(fontFamily: KFonts.sans, fontSize: 15, fontWeight: FontWeight.w700, color: KColors.t1),
        subtitleTextStyle: TextStyle(fontFamily: KFonts.sans, fontSize: 13, color: KColors.t2),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(KRadius.xs)),
        side: const BorderSide(color: KColors.t3, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? KColors.ok : Colors.transparent,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: KColors.primary, linearTrackColor: KColors.border),
    );
  }
}
