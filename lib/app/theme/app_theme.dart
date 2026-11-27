import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vv2/vv2_tokens.dart';

class AppColors {
  static const primary = Color(0xFFFF6B2B);
  static const primaryDark = Color(0xFFE55A1C);
  static const primaryLight = Color(0xFFFF8C57);
  static const secondary = Color(0xFF2B4EFF);
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const textDark = Color(0xFF1A1A2E);
  static const textMedium = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const cardShadow = Color(0x14000000);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          displayLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          displayMedium: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          titleMedium: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textMedium,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textMedium,
          ),
          labelLarge: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textDark),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        // Redesign 2.0: botões em pílula, campos creme, folhas e diálogos
        // com a fonte e os raios do Design System (ver Vv2).
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Vv2.brand,
            foregroundColor: Vv2.onBrand,
            disabledBackgroundColor: Vv2.brand.withValues(alpha: 0.5),
            disabledForegroundColor: Vv2.onBrand.withValues(alpha: 0.6),
            minimumSize: const Size(double.infinity, 56),
            shape: const StadiumBorder(),
            elevation: 0,
            textStyle: Vv2.t(16, 22, 700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Vv2.onPrimaryContainer,
            backgroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            side: const BorderSide(color: Color(0xFF6E4B3E)),
            shape: const StadiumBorder(),
            textStyle: Vv2.t(16, 22, 700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Vv2.primary,
            minimumSize: const Size(48, 48),
            textStyle: Vv2.t(14, 20, 700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Vv2Pastel.cream,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Vv2.rControl),
            borderSide: const BorderSide(color: Vv2.pressedSurface),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Vv2.rControl),
            borderSide: const BorderSide(color: Vv2.pressedSurface),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Vv2.rControl),
            borderSide: const BorderSide(color: Vv2.brand, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Vv2.rControl),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          labelStyle: Vv2.t(14, 20, 600, color: Vv2.textSecondary),
          floatingLabelStyle: Vv2.t(14, 20, 700, color: Vv2.primary),
          hintStyle: Vv2.t(14, 20, 400, color: Vv2.outline),
          prefixIconColor: Vv2.primary,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Vv2.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Vv2.rOverlay)),
          titleTextStyle: Vv2.t(20, 28, 700),
          contentTextStyle: Vv2.t(14, 20, 400, color: Vv2.textSecondary),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Vv2.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : Vv2.outline),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Vv2.primary : Vv2.divider),
          trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Vv2.primary : Vv2.outline),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Vv2.primary : null),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Vv2.primary : Vv2.outline),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textLight,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );
}
