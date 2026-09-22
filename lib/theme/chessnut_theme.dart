import 'package:flutter/material.dart';

enum ChessnutVisualTheme {
  modern,
  classic;

  String get label {
    return switch (this) {
      ChessnutVisualTheme.modern => 'Modern',
      ChessnutVisualTheme.classic => 'Classic',
    };
  }
}

class ChessnutThemeTokens extends ThemeExtension<ChessnutThemeTokens> {
  const ChessnutThemeTokens({
    required this.visualTheme,
    required this.panelFill,
    required this.panelBorder,
    required this.panelShadow,
    required this.backgroundGlowPrimary,
    required this.backgroundGlowSecondary,
    required this.showAmbientGlow,
    required this.visualEffectsEnabled,
    required this.panelRadius,
    required this.controlRadius,
    required this.touchTarget,
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
  });

  final ChessnutVisualTheme visualTheme;
  final Color panelFill;
  final Color panelBorder;
  final Color panelShadow;
  final Color backgroundGlowPrimary;
  final Color backgroundGlowSecondary;
  final bool showAmbientGlow;
  final bool visualEffectsEnabled;
  final double panelRadius;
  final double controlRadius;
  final double touchTarget;
  final Color success;
  final Color info;
  final Color warning;
  final Color danger;

  @override
  ChessnutThemeTokens copyWith({
    ChessnutVisualTheme? visualTheme,
    Color? panelFill,
    Color? panelBorder,
    Color? panelShadow,
    Color? backgroundGlowPrimary,
    Color? backgroundGlowSecondary,
    bool? showAmbientGlow,
    bool? visualEffectsEnabled,
    double? panelRadius,
    double? controlRadius,
    double? touchTarget,
    Color? success,
    Color? info,
    Color? warning,
    Color? danger,
  }) {
    return ChessnutThemeTokens(
      visualTheme: visualTheme ?? this.visualTheme,
      panelFill: panelFill ?? this.panelFill,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      backgroundGlowPrimary:
          backgroundGlowPrimary ?? this.backgroundGlowPrimary,
      backgroundGlowSecondary:
          backgroundGlowSecondary ?? this.backgroundGlowSecondary,
      showAmbientGlow: showAmbientGlow ?? this.showAmbientGlow,
      visualEffectsEnabled: visualEffectsEnabled ?? this.visualEffectsEnabled,
      panelRadius: panelRadius ?? this.panelRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      touchTarget: touchTarget ?? this.touchTarget,
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  ChessnutThemeTokens lerp(
      ThemeExtension<ChessnutThemeTokens>? other, double t) {
    if (other is! ChessnutThemeTokens) return this;
    return ChessnutThemeTokens(
      visualTheme: t < 0.5 ? visualTheme : other.visualTheme,
      panelFill: Color.lerp(panelFill, other.panelFill, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      backgroundGlowPrimary:
          Color.lerp(backgroundGlowPrimary, other.backgroundGlowPrimary, t)!,
      backgroundGlowSecondary: Color.lerp(
          backgroundGlowSecondary, other.backgroundGlowSecondary, t)!,
      showAmbientGlow: t < 0.5 ? showAmbientGlow : other.showAmbientGlow,
      visualEffectsEnabled:
          t < 0.5 ? visualEffectsEnabled : other.visualEffectsEnabled,
      panelRadius: _lerpDouble(panelRadius, other.panelRadius, t),
      controlRadius: _lerpDouble(controlRadius, other.controlRadius, t),
      touchTarget: _lerpDouble(touchTarget, other.touchTarget, t),
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class ChessnutTheme {
  static const String primaryFontFamily = 'Plus Jakarta Sans';
  static const List<String> fontFamilyFallback = [
    'MiSans',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Heiti SC',
    'WenQuanYi Micro Hei',
    'sans-serif',
  ];

  static const Color green = Color(0xFF22C55E);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color darkCanvas = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color lightCanvas = Color(0xFFEFF5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color classicGreen = Color(0xFF36543E);
  static const Color classicGold = Color(0xFFD7B46A);
  static const Color classicWalnut = Color(0xFF8B5E34);
  static const Color classicInk = Color(0xFF241A12);
  static const Color classicIvory = Color(0xFFF7F0E2);

  static ChessnutThemeTokens tokensOf(BuildContext context) {
    return Theme.of(context).extension<ChessnutThemeTokens>() ??
        _tokens(
          Theme.of(context).brightness == Brightness.dark
              ? ChessnutVisualTheme.modern
              : ChessnutVisualTheme.modern,
          dark: Theme.of(context).brightness == Brightness.dark,
          visualEffectsEnabled: true,
        );
  }

  static ThemeData dark([
    ChessnutVisualTheme visualTheme = ChessnutVisualTheme.modern,
    bool visualEffectsEnabled = true,
  ]) {
    final base = ThemeData(
      brightness: Brightness.dark,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      useMaterial3: true,
    );
    final classic = visualTheme == ChessnutVisualTheme.classic;
    final scheme = classic
        ? const ColorScheme.dark(
            surface: Color(0xFF211811),
            primary: classicGold,
            onPrimary: Color(0xFF1B130C),
            secondary: Color(0xFFA7B48C),
            onSecondary: Color(0xFF13180F),
            tertiary: Color(0xFFC9975A),
            onSurface: Color(0xFFF8F0DF),
          )
        : const ColorScheme.dark(
            surface: darkSurface,
            primary: green,
            onPrimary: Color(0xFF041008),
            secondary: cyan,
          );
    final canvas = classic ? const Color(0xFF18130E) : darkCanvas;
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      extensions: [
        _tokens(
          visualTheme,
          dark: true,
          visualEffectsEnabled: visualEffectsEnabled,
        ),
      ],
      textTheme: _textTheme(base.textTheme, visualTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: _textTheme(base.primaryTextTheme, visualTheme),
      cardTheme: _cardTheme(
        classic ? const Color(0xE6211811) : const Color(0xB80F172A),
        classic ? const Color(0x40D7B46A) : Colors.white10,
        classic ? 10 : 14,
      ),
      dividerColor: classic ? const Color(0x55D7B46A) : Colors.white24,
      filledButtonTheme: _filledButtonTheme(scheme, visualTheme),
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(scheme, true, visualTheme),
      iconButtonTheme: _iconButtonTheme(scheme, true, visualTheme),
      chipTheme: _chipTheme(base.chipTheme, scheme, true),
      inputDecorationTheme: _inputTheme(scheme, true),
      segmentedButtonTheme: _segmentedTheme(scheme, true),
      switchTheme: _switchTheme(scheme),
      bottomSheetTheme: _bottomSheetTheme(true),
      dialogTheme: _dialogTheme(true),
    );
  }

  static ThemeData light([
    ChessnutVisualTheme visualTheme = ChessnutVisualTheme.modern,
    bool visualEffectsEnabled = true,
  ]) {
    final base = ThemeData(
      brightness: Brightness.light,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      useMaterial3: true,
    );
    final classic = visualTheme == ChessnutVisualTheme.classic;
    final scheme = classic
        ? const ColorScheme.light(
            surface: Color(0xFFFFFCF4),
            primary: classicGreen,
            onPrimary: Color(0xFFFFFBEB),
            secondary: classicWalnut,
            onSecondary: Color(0xFFFFFBEB),
            tertiary: Color(0xFFB8893E),
            onSurface: classicInk,
          )
        : const ColorScheme.light(
            surface: lightSurface,
            primary: Color(0xFF16A34A),
            onPrimary: Color(0xFF041008),
            secondary: Color(0xFF0284C7),
          );
    final canvas = classic ? classicIvory : lightCanvas;
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      extensions: [
        _tokens(
          visualTheme,
          dark: false,
          visualEffectsEnabled: visualEffectsEnabled,
        ),
      ],
      textTheme: _textTheme(base.textTheme, visualTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: _textTheme(base.primaryTextTheme, visualTheme),
      cardTheme: _cardTheme(
        classic ? const Color(0xF7FFFCF4) : const Color(0xD9FFFFFF),
        classic ? const Color(0x408B5E34) : const Color(0x1A0F172A),
        classic ? 10 : 14,
      ),
      dividerColor: classic ? const Color(0x338B5E34) : const Color(0x260F172A),
      filledButtonTheme: _filledButtonTheme(scheme, visualTheme),
      elevatedButtonTheme: _elevatedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(scheme, false, visualTheme),
      iconButtonTheme: _iconButtonTheme(scheme, false, visualTheme),
      chipTheme: _chipTheme(base.chipTheme, scheme, false),
      inputDecorationTheme: _inputTheme(scheme, false),
      segmentedButtonTheme: _segmentedTheme(scheme, false),
      switchTheme: _switchTheme(scheme),
      bottomSheetTheme: _bottomSheetTheme(false),
      dialogTheme: _dialogTheme(false),
    );
  }

  static ChessnutThemeTokens _tokens(
    ChessnutVisualTheme visualTheme, {
    required bool dark,
    required bool visualEffectsEnabled,
  }) {
    final classic = visualTheme == ChessnutVisualTheme.classic;
    if (classic) {
      return ChessnutThemeTokens(
        visualTheme: visualTheme,
        panelFill: dark ? const Color(0xF0211811) : const Color(0xF7FFFCF4),
        panelBorder: dark ? const Color(0x40D7B46A) : const Color(0x408B5E34),
        panelShadow: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
        backgroundGlowPrimary:
            dark ? const Color(0x1AD7B46A) : const Color(0x1A8B5E34),
        backgroundGlowSecondary:
            dark ? const Color(0x1436543E) : const Color(0x1236543E),
        showAmbientGlow: false,
        visualEffectsEnabled: visualEffectsEnabled,
        panelRadius: 10,
        controlRadius: 8,
        touchTarget: 48,
        success: dark ? const Color(0xFFA7B48C) : classicGreen,
        info: dark ? const Color(0xFFC9A66B) : const Color(0xFF6A5638),
        warning: dark ? classicGold : const Color(0xFF9B6F28),
        danger: dark ? const Color(0xFFE29C86) : const Color(0xFF9B3F2F),
      );
    }
    return ChessnutThemeTokens(
      visualTheme: visualTheme,
      panelFill: dark ? const Color(0xF0111C2F) : const Color(0xFAFFFFFF),
      panelBorder:
          dark ? Colors.white.withValues(alpha: 0.11) : const Color(0x240F172A),
      panelShadow: Colors.black.withValues(alpha: dark ? 0.18 : 0.06),
      backgroundGlowPrimary: cyan.withValues(alpha: dark ? 0.09 : 0.06),
      backgroundGlowSecondary: green.withValues(alpha: dark ? 0.06 : 0.05),
      showAmbientGlow: visualEffectsEnabled,
      visualEffectsEnabled: visualEffectsEnabled,
      panelRadius: 14,
      controlRadius: 12,
      touchTarget: 46,
      success: green,
      info: cyan,
      warning: const Color(0xFFF59E0B),
      danger: const Color(0xFFEF4444),
    );
  }

  static CardThemeData _cardTheme(Color color, Color border, double radius) {
    return CardThemeData(
      color: color,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ChessnutVisualTheme visualTheme) {
    final classic = visualTheme == ChessnutVisualTheme.classic;
    final themed = base.apply(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
    final headingFallback = classic
        ? const [
            'MiSans',
            'Microsoft YaHei UI',
            'Microsoft YaHei',
            'Noto Sans CJK SC',
            'Noto Sans SC',
            'Source Han Sans SC',
            'Georgia',
            'Times New Roman',
            'serif',
          ]
        : fontFamilyFallback;
    final fallbackThemed = _withCjkFallback(themed);
    return fallbackThemed.copyWith(
      headlineMedium: fallbackThemed.headlineMedium?.copyWith(
        fontSize: classic ? 30 : 28,
        height: classic ? 1.12 : 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        fontFamilyFallback: headingFallback,
      ),
      headlineSmall: fallbackThemed.headlineSmall?.copyWith(
        fontSize: classic ? 28 : 27,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        fontFamilyFallback: headingFallback,
      ),
      titleLarge: fallbackThemed.titleLarge?.copyWith(
        fontSize: classic ? 21 : 20,
        height: classic ? 1.24 : 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        fontFamilyFallback: headingFallback,
      ),
      titleMedium: fallbackThemed.titleMedium?.copyWith(
        fontSize: 16,
        height: classic ? 1.32 : 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      bodyLarge: fallbackThemed.bodyLarge?.copyWith(
        fontSize: classic ? 16 : 15,
        height: classic ? 1.52 : 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: fallbackThemed.bodyMedium?.copyWith(
        fontSize: classic ? 15 : 14,
        height: classic ? 1.48 : 1.42,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: fallbackThemed.bodySmall?.copyWith(
        fontSize: classic ? 13 : 12,
        height: classic ? 1.42 : 1.34,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: fallbackThemed.labelLarge?.copyWith(
        fontSize: classic ? 14 : 13,
        height: 1.16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      labelSmall: fallbackThemed.labelSmall?.copyWith(
        fontSize: classic ? 11 : 10,
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        fontFamilyFallback: fontFamilyFallback,
      ),
    );
  }

  static TextTheme _withCjkFallback(TextTheme theme) {
    return theme.copyWith(
      displayLarge:
          theme.displayLarge?.copyWith(fontFamilyFallback: fontFamilyFallback),
      displayMedium:
          theme.displayMedium?.copyWith(fontFamilyFallback: fontFamilyFallback),
      displaySmall:
          theme.displaySmall?.copyWith(fontFamilyFallback: fontFamilyFallback),
      headlineLarge:
          theme.headlineLarge?.copyWith(fontFamilyFallback: fontFamilyFallback),
      headlineMedium: theme.headlineMedium
          ?.copyWith(fontFamilyFallback: fontFamilyFallback),
      headlineSmall:
          theme.headlineSmall?.copyWith(fontFamilyFallback: fontFamilyFallback),
      titleLarge:
          theme.titleLarge?.copyWith(fontFamilyFallback: fontFamilyFallback),
      titleMedium:
          theme.titleMedium?.copyWith(fontFamilyFallback: fontFamilyFallback),
      titleSmall:
          theme.titleSmall?.copyWith(fontFamilyFallback: fontFamilyFallback),
      bodyLarge:
          theme.bodyLarge?.copyWith(fontFamilyFallback: fontFamilyFallback),
      bodyMedium:
          theme.bodyMedium?.copyWith(fontFamilyFallback: fontFamilyFallback),
      bodySmall:
          theme.bodySmall?.copyWith(fontFamilyFallback: fontFamilyFallback),
      labelLarge:
          theme.labelLarge?.copyWith(fontFamilyFallback: fontFamilyFallback),
      labelMedium:
          theme.labelMedium?.copyWith(fontFamilyFallback: fontFamilyFallback),
      labelSmall:
          theme.labelSmall?.copyWith(fontFamilyFallback: fontFamilyFallback),
    );
  }

  static TextStyle _appFontStyle({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      color: color,
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontWeight: fontWeight,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static FilledButtonThemeData _filledButtonTheme(
    ColorScheme scheme,
    ChessnutVisualTheme visualTheme,
  ) {
    final classic = visualTheme == ChessnutVisualTheme.classic;
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.30),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
        elevation: 0,
        minimumSize: Size(0, classic ? 50 : 46),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(classic ? 8 : 12)),
        textStyle: _appFontStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: _appFontStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: _appFontStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
      ColorScheme scheme, bool dark, ChessnutVisualTheme visualTheme) {
    final classic = visualTheme == ChessnutVisualTheme.classic;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? scheme.onSurface : const Color(0xFF101820),
        backgroundColor: classic
            ? (dark ? const Color(0xD9211811) : const Color(0xF7FFFCF4))
            : (dark ? const Color(0x8A0F172A) : const Color(0xD9FFFFFF)),
        side: BorderSide(
          color: classic
              ? (dark ? const Color(0x40D7B46A) : const Color(0x408B5E34))
              : (dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0x1A0F172A)),
        ),
        minimumSize: Size(0, classic ? 50 : 46),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(classic ? 8 : 12)),
        textStyle: _appFontStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  static IconButtonThemeData _iconButtonTheme(
      ColorScheme scheme, bool dark, ChessnutVisualTheme visualTheme) {
    final classic = visualTheme == ChessnutVisualTheme.classic;
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: classic
            ? (dark ? const Color(0xD9211811) : const Color(0xF7FFFCF4))
            : (dark ? const Color(0xCC0F172A) : const Color(0xE6FFFFFF)),
        foregroundColor: dark ? scheme.onSurface : const Color(0xFF101820),
        disabledBackgroundColor: Colors.transparent,
        minimumSize: Size.square(classic ? 46 : 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(classic ? 8 : 10),
          side: BorderSide(
            color: classic
                ? (dark ? const Color(0x40D7B46A) : const Color(0x408B5E34))
                : (dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0x1A0F172A)),
          ),
        ),
      ),
    );
  }

  static ChipThemeData _chipTheme(
      ChipThemeData base, ColorScheme scheme, bool dark) {
    return base.copyWith(
      backgroundColor: dark ? const Color(0xB80F172A) : const Color(0xE6FFFFFF),
      selectedColor: scheme.primary.withValues(alpha: dark ? 0.20 : 0.14),
      side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.11)
              : const Color(0x1A0F172A)),
      labelStyle: TextStyle(
        color: dark ? Colors.white : const Color(0xFF101820),
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w800,
      ),
      secondaryLabelStyle: TextStyle(
        color: scheme.primary,
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  static InputDecorationTheme _inputTheme(ColorScheme scheme, bool dark) {
    final fill = dark ? const Color(0x99020617) : const Color(0xE6FFFFFF);
    final border =
        dark ? Colors.white.withValues(alpha: 0.11) : const Color(0x1A0F172A);
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      labelStyle: TextStyle(
        color: dark ? const Color(0xFFA4AFBF) : const Color(0xFF5F6F7D),
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: scheme.secondary,
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w700,
      ),
      helperStyle: TextStyle(
        color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
      ),
      prefixStyle: const TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
      ),
      suffixStyle: const TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
      ),
      counterStyle: const TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: dark ? const Color(0xFFA4AFBF) : const Color(0xFF5F6F7D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: scheme.secondary.withValues(alpha: 0.72), width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
    );
  }

  static SegmentedButtonThemeData _segmentedTheme(
      ColorScheme scheme, bool dark) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: dark ? 0.20 : 0.14);
          }
          return dark ? const Color(0x8A0F172A) : const Color(0xD9FFFFFF);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return dark ? Colors.white : const Color(0xFF101820);
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: scheme.primary.withValues(alpha: 0.42));
          }
          return BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.11)
                  : const Color(0x1A0F172A));
        }),
        textStyle: WidgetStatePropertyAll(
          _appFontStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  static SwitchThemeData _switchTheme(ColorScheme scheme) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return const Color(0xFFE2E8F0);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: 0.32);
        }
        return Colors.black.withValues(alpha: 0.16);
      }),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(bool dark) {
    return BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      dragHandleColor:
          dark ? Colors.white.withValues(alpha: 0.28) : const Color(0x660F172A),
    );
  }

  static DialogThemeData _dialogTheme(bool dark) {
    return DialogThemeData(
      backgroundColor: dark ? const Color(0xF20F172A) : const Color(0xF2FFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
