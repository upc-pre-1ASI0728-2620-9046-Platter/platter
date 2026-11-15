import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad visual de Platter, alineada con el logo: naranja de la campana, café espresso y crema,
/// con verde huacatay y ají amarillo como acentos. Titulares en Fraunces (serif gastronómica), texto en Inter.
class PlatterColors {
  PlatterColors._();

  static const terracotta = Color(0xFFCC4F16);
  static const terracottaDeep = Color(0xFFA93F10);
  static const ember = Color(0xFFF27321);
  static const huacatay = Color(0xFF1F4D3A);
  static const huacatayDeep = Color(0xFF12301F);
  static const huacatayLight = Color(0xFF2E6B52);
  static const aji = Color(0xFFE6A532);
  static const cream = Color(0xFFFCF7F1);
  static const ink = Color(0xFF2B1712);

  /// Degradado de marca para héroes y avatares.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEE6A22), Color(0xFFB53D0D)],
  );

  static const sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A2219), Color(0xFF21130D)],
  );
}

/// En las pruebas de widgets no hay red: se usan las fuentes del sistema.
bool platterBrandFonts = true;

ColorScheme _scheme(Brightness b) {
  final light = b == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: PlatterColors.terracotta, brightness: b);
  return light
      ? base.copyWith(
          primary: PlatterColors.terracotta,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFDE3D2),
          onPrimaryContainer: const Color(0xFF3B1407),
          secondary: PlatterColors.huacatay,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFD6EADF),
          onSecondaryContainer: const Color(0xFF0B2419),
          tertiary: const Color(0xFF9A6A00),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFCE8BF),
          onTertiaryContainer: const Color(0xFF3A2700),
          surface: Colors.white,
          onSurface: PlatterColors.ink,
          onSurfaceVariant: const Color(0xFF6E5D52),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFCF8F3),
          surfaceContainer: const Color(0xFFF6EFE6),
          surfaceContainerHigh: const Color(0xFFF0E7DC),
          surfaceContainerHighest: const Color(0xFFE9DED1),
          outline: const Color(0xFFC9BAAC),
          outlineVariant: const Color(0xFFEADFD3),
        )
      : base.copyWith(
          primary: const Color(0xFFFF8A4C),
          onPrimary: const Color(0xFF3B1407),
          primaryContainer: const Color(0xFF6A2A12),
          onPrimaryContainer: const Color(0xFFFFDBCC),
          secondary: const Color(0xFF8FC7A8),
          onSecondary: const Color(0xFF0B2419),
          secondaryContainer: const Color(0xFF24503D),
          onSecondaryContainer: const Color(0xFFCDEBDB),
          tertiary: const Color(0xFFF2C462),
          onTertiary: const Color(0xFF3A2700),
          tertiaryContainer: const Color(0xFF574000),
          onTertiaryContainer: const Color(0xFFFCE8BF),
          surface: const Color(0xFF211A16),
          onSurface: const Color(0xFFF3E9DF),
          onSurfaceVariant: const Color(0xFFC9B8AA),
          surfaceContainerLowest: const Color(0xFF15110E),
          surfaceContainerLow: const Color(0xFF1C1612),
          surfaceContainer: const Color(0xFF241D18),
          surfaceContainerHigh: const Color(0xFF2C241F),
          surfaceContainerHighest: const Color(0xFF362C26),
          outline: const Color(0xFF6A5B50),
          outlineVariant: const Color(0xFF3A302A),
        );
}

TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
  if (!platterBrandFonts) return base.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final body = GoogleFonts.interTextTheme(base);
  TextStyle? display(TextStyle? s, {FontWeight w = FontWeight.w600}) =>
      GoogleFonts.fraunces(textStyle: s, fontWeight: w, letterSpacing: -0.3);
  return body
      .copyWith(
        displayLarge: display(body.displayLarge),
        displayMedium: display(body.displayMedium),
        displaySmall: display(body.displaySmall),
        headlineLarge: display(body.headlineLarge),
        headlineMedium: display(body.headlineMedium),
        headlineSmall: display(body.headlineSmall),
        titleLarge: display(body.titleLarge),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final light = brightness == Brightness.light;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = _textTheme(base.textTheme, scheme);
  final radius = BorderRadius.circular(14);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: light ? PlatterColors.cream : scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      toolbarHeight: 68,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: buttonPadding,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: buttonPadding,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outline),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: buttonText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? const Color(0xFFFCF8F3) : scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.secondary,
      secondarySelectedColor: scheme.secondary,
      checkmarkColor: scheme.onSecondary,
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      secondaryLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSecondary),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.secondary : null),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : scheme.outline,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.secondary,
        selectedForegroundColor: scheme.onSecondary,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.headlineSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? PlatterColors.ink : scheme.surfaceContainerHighest,
      contentTextStyle: text.bodyMedium?.copyWith(color: light ? Colors.white : scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: radius)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: PlatterColors.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: text.bodySmall?.copyWith(color: Colors.white),
    ),
  );
}
