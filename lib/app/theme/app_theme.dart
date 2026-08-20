import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textLight,
          ),
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
