import 'package:flutter/material.dart';

/// Keevy design tokens (from the original mockups).
class KColors {
  KColors._();

  // Brand
  static const bg = Color(0xFFF7F4F1);
  static const primary = Color(0xFF1A1A2E);
  static const white = Color(0xFFFFFFFF);
  static const surf = Color(0xFFF5F2EF);
  static const surf2 = Color(0xFFEFEAE5);
  static const border = Color(0xFFEAE5E0);

  // Text
  static const t1 = Color(0xFF1A1A2E);
  static const t2 = Color(0xFF6B7280);
  static const t3 = Color(0xFF9CA3AF);

  // Status
  static const ok = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
  static const err = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const purple = Color(0xFF7C3AED);

  // Board accents
  static const pink = Color(0xFFC084A0);
  static const brown = Color(0xFFB07860);
  static const slate = Color(0xFF7080B0);
  static const sage = Color(0xFF6A9E6A);
  static const amber = Color(0xFFD4904C);

  static const boardAccents = <Color>[brown, pink, sage, slate, amber, purple, info, primary];

  // Note card papers
  static const notePapers = <Color>[
    Color(0xFFFFF4D6),
    Color(0xFFFCE7EF),
    Color(0xFFE7F3E7),
    Color(0xFFE8ECF8),
  ];
}

class KRadius {
  KRadius._();
  static const xs = Radius.circular(6);
  static const sm = Radius.circular(10);
  static const md = Radius.circular(14);
  static const lg = Radius.circular(20);
  static const xl = Radius.circular(28);
  static const full = Radius.circular(999);
}

class KSpacing {
  KSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class KFonts {
  KFonts._();
  static const serif = 'Lora';
  static const sans = 'InstrumentSans';
}

class KShadows {
  KShadows._();
  static const soft = [
    BoxShadow(color: Color(0x0F1A1A2E), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x1F1A1A2E), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

/// `#RRGGBB` ⇄ [Color].
extension HexColor on Color {
  String toHex() {
    final v = toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Text colour that stays readable on top of this colour.
  Color get onColor => computeLuminance() > 0.55 ? KColors.t1 : KColors.white;

  Color tint(double alpha) => withValues(alpha: alpha);
}

Color colorFromHex(String? hex, {Color fallback = KColors.brown}) {
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
