import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'commit_colors.dart';

class AppTheme {
  static ThemeData get dark => _build(
        Brightness.dark,
        const ColorScheme.dark(
          primary: Color(0xFF818CF8),
          onPrimary: Color(0xFF0B0F1A),
          secondary: Color(0xFFA78BFA),
          surface: Color(0xFF151B2D),
          error: Color(0xFFF87171),
          onSurface: Color(0xFFE6E9F5),
        ),
        const Color(0xFF0B0F1A),
        CommitColors.dark,
      );

  static ThemeData get light => _build(
        Brightness.light,
        const ColorScheme.light(
          primary: Color(0xFF5B5BF0),
          onPrimary: Colors.white,
          secondary: Color(0xFF7C3AED),
          surface: Colors.white,
          error: Color(0xFFDC2626),
          onSurface: Color(0xFF0F172A),
        ),
        const Color(0xFFF5F7FB),
        CommitColors.light,
      );

  static ThemeData _build(Brightness b, ColorScheme cs, Color bg, CommitColors cc) {
    final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: cs);
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: text,
      extensions: [cc],
      dividerColor: cc.border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cc.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cc.surfaceRaised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cc.surfaceRaised,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
    );
  }

  /// JetBrains Mono for numbers, stats and code.
  static TextStyle mono(BuildContext context, {double size = 14, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? Theme.of(context).colorScheme.onSurface);
}
