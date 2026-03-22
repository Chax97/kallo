import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router/admin_router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);

    return MaterialApp.router(
      title: 'Kallo Admin',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: _buildTheme(),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1A2E),
        brightness: Brightness.light,
        primary: const Color(0xFF1A1A2E),
        secondary: const Color(0xFF4F6AFF),
        surface: const Color(0xFFFAFAFC),
        onSurface: const Color(0xFF0D0D1A),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F5F9),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0D0D1A),
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0D0D1A),
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0D0D1A),
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0D0D1A),
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF3D3D5C),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6B6B8A),
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0D0D1A),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8E8F0), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8F0),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4F6AFF), width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: const Color(0xFFAAAAAC),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A2E),
          side: const BorderSide(color: Color(0xFFE0E0F0)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F0F8),
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide.none,
      ),
    );
  }
}
