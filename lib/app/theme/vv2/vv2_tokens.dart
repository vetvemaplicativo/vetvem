import 'package:flutter/material.dart';

/// Tokens do Design System v1.0 (redesign 2.0). Convivem com [AppColors];
/// só as telas já migradas usam estes valores.
class Vv2 {
  Vv2._();

  // Cores
  static const brand = Color(0xFFFF6B2B);
  static const onBrand = Color(0xFF1A1A2E);
  static const canvas = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF505968);
  static const outline = Color(0xFF707B89);
  static const divider = Color(0xFFE0E4E9);
  static const primary = Color(0xFFA83C10);
  static const primaryPressed = Color(0xFF86300E);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFFF0E8);
  static const onPrimaryContainer = Color(0xFF7A2D10);
  static const secondaryContainer = Color(0xFFF4EAE4);
  static const pressedSurface = Color(0xFFF9E1D5);
  static const scrim = Color(0x801A1A2E);
  static const successBg = Color(0xFFE9F7EF);
  static const successFg = Color(0xFF145C39);

  // Degradês
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFA574), Color(0xFFFFD3BA)],
  );
  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFF6B2B), Color(0xFFFF9A63)],
  );

  // Espaço, raios, medidas
  static const gutter = 16.0;
  static const rControl = 12.0;
  static const rCard = 16.0;
  static const rOverlay = 24.0;
  static const rPill = 999.0;
  static const tapMin = 48.0;
  static const buttonMin = 52.0;
  static const fieldMin = 56.0;
  static const navMin = 64.0;

  static const cardShadow = [
    BoxShadow(color: Color(0x141A1A2E), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const overlayShadow = [
    BoxShadow(color: Color(0x241A1A2E), offset: Offset(0, 6), blurRadius: 16),
  ];

  static const fontFamily = 'PlusJakartaSans';

  /// Estilo com a fonte variável: o peso vai também como eixo `wght`.
  static TextStyle t(double size, double lineHeight, int weight,
          {Color color = text}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        color: color,
      );

  static TextStyle get displaySmall => t(32, 40, 700);
  static TextStyle get headlineSmall => t(24, 32, 700);
  static TextStyle get titleLarge => t(20, 28, 700);
  static TextStyle get titleMedium => t(16, 24, 600);
  static TextStyle get bodyLarge => t(16, 24, 400);
  static TextStyle get bodyMedium => t(14, 20, 400, color: textSecondary);
  static TextStyle get bodySmall => t(12, 18, 400, color: textSecondary);
  static TextStyle get labelLarge => t(14, 20, 600);
  static TextStyle get labelMedium => t(12, 18, 600);
  static TextStyle get price => t(18, 24, 700);
}

/// Cores de apoio do piloto (fundo creme e pastéis das categorias).
class Vv2Pastel {
  Vv2Pastel._();
  static const cream = Color(0xFFFDF4EE);
  static const cycle = <Color>[
    Color(0xFFFFD9C7),
    Color(0xFFF1E4D3),
    Color(0xFFE3EBDD),
    Color(0xFFFFEBC2),
    Color(0xFFF4DCD8),
    Color(0xFFE5EBDC),
  ];
  static Color at(int i) => cycle[i % cycle.length];
}
