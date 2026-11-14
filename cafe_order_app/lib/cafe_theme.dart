import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const cafePaper = Color(0xFFF8F3EA);
const cafeSurface = Color(0xFFFFFBF4);
const cafeInk = Color(0xFF2C1C16);
const cafeMuted = Color(0xFF6A5A4C);
const cafeForest = Color(0xFF354638);
const cafeLine = Color(0xFFDED0BE);

ThemeData buildCafeTheme() {
  const colors = ColorScheme.light(
    primary: cafeForest,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDFE7D9),
    onPrimaryContainer: Color(0xFF26382A),
    secondary: Color(0xFF85492F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF5DECA),
    onSecondaryContainer: Color(0xFF40291D),
    tertiary: Color(0xFF69542F),
    tertiaryContainer: Color(0xFFF1E4C8),
    onTertiaryContainer: Color(0xFF3E301C),
    error: Color(0xFF9A3E35),
    errorContainer: Color(0xFFF8DED7),
    onErrorContainer: Color(0xFF631F1A),
    surface: cafeSurface,
    onSurface: cafeInk,
    onSurfaceVariant: cafeMuted,
    surfaceContainerLowest: Color(0xFFFFFDF8),
    surfaceContainerLow: Color(0xFFF7EFE2),
    surfaceContainer: Color(0xFFF3EADD),
    surfaceContainerHigh: Color(0xFFEEE3D2),
    surfaceContainerHighest: Color(0xFFE7DAC6),
    outline: Color(0xFF8C7A68),
    outlineVariant: cafeLine,
    inverseSurface: cafeInk,
    onInverseSurface: cafePaper,
  );
  final base = ThemeData(
    colorScheme: colors,
    fontFamily: 'Be Vietnam Pro',
    useMaterial3: true,
  );
  final type = base.textTheme.apply(bodyColor: cafeInk, displayColor: cafeInk);
  TextStyle display(TextStyle? style, double size) => style!.copyWith(
    fontFamily: 'Playfair Display',
    fontWeight: FontWeight.w600,
    fontSize: size,
    height: 1.14,
    letterSpacing: -.45,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final border = OutlineInputBorder(
    borderSide: const BorderSide(color: cafeLine),
    borderRadius: BorderRadius.circular(13),
  );

  return base.copyWith(
    scaffoldBackgroundColor: cafePaper,
    splashFactory: InkRipple.splashFactory,
    textTheme: type.copyWith(
      displayLarge: display(type.displayLarge, 66),
      displayMedium: display(type.displayMedium, 52),
      displaySmall: display(type.displaySmall, 43),
      headlineLarge: display(type.headlineLarge, 36),
      headlineMedium: display(type.headlineMedium, 30),
      headlineSmall: display(type.headlineSmall, 25),
      titleLarge: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: type.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: type.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: type.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: type.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cafePaper,
      foregroundColor: cafeInk,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: cafeSurface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: cafeLine),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: cafeForest, width: 1.6),
      ),
      errorBorder: border.copyWith(borderSide: BorderSide(color: colors.error)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.error, width: 1.6),
      ),
      prefixIconColor: cafeMuted,
      suffixIconColor: cafeMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: cafeLine),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(0, 44), shape: shape),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: cafeSurface,
      selectedColor: colors.primaryContainer,
      side: const BorderSide(color: cafeLine),
      shape: const StadiumBorder(),
      labelStyle: type.labelLarge?.copyWith(color: cafeInk),
    ),
    dividerTheme: const DividerThemeData(color: cafeLine, thickness: 1),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: cafeSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: cafeSurface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cafeInk,
      contentTextStyle: type.bodyMedium?.copyWith(color: cafePaper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      width: 460,
    ),
  );
}
