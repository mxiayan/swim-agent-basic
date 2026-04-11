// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFlutterFlowThemeModeKey = 'flutter_flow_theme_mode';

abstract class FlutterFlowTheme {
  static ThemeMode themeMode = ThemeMode.system;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kFlutterFlowThemeModeKey);
    if (stored == null) {
      return;
    }
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) {
        themeMode = mode;
        return;
      }
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFlutterFlowThemeModeKey, mode.name);
  }

  static FlutterFlowTheme of(BuildContext context) {
    return LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color primaryBtnText;
  late Color lineColor;
  late Color prussianBlue;
  late Color marigold;
  late Color turquoiseGreen;
  late Color cerise;
  late Color fireOpal;
  late Color lightGrey;

  FFDesignTokens get designToken => FFDesignTokens(this);

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  /// Energetic cyan / light blue — primary brand (tabs, chips, CTAs).
  late Color primary = const Color(0xFF29B6F6);
  late Color secondary = const Color(0xFFF0A202);
  late Color tertiary = const Color(0xFF94DDBC);
  late Color alternate = const Color(0xFFDA4167);
  /// Default body text on white (meet titles use explicit black where needed).
  late Color primaryText = const Color(0xFF0F172A);
  /// Softer grey for secondary lines (“Showing meets…”, meta copy).
  late Color secondaryText = const Color(0xFF94A3B8);
  /// Pure white app scaffold.
  late Color primaryBackground = const Color(0xFFFFFFFF);
  /// Pure white cards (depth from shadow only).
  late Color secondaryBackground = const Color(0xFFFFFFFF);
  late Color accent1 = const Color(0xFF64748B);
  late Color accent2 = const Color(0xFF94A3B8);
  late Color accent3 = const Color(0xFFE2E8F0);
  late Color accent4 = const Color(0xFFF1F5F9);
  late Color success = const Color(0xFF04A24C);
  late Color warning = const Color(0xFFFCDC0C);
  late Color error = const Color(0xFFE21C3D);
  late Color info = const Color(0xFF0288D1);

  late Color primaryBtnText = const Color(0xFFFFFFFF);
  /// Very light grey for chip outlines and hairlines.
  late Color lineColor = const Color(0xFFE2E8F0);
  late Color prussianBlue = const Color(0xFF29B6F6);
  late Color marigold = const Color(0xFFF0A202);
  late Color turquoiseGreen = const Color(0xFF94DDBC);
  late Color cerise = const Color(0xFFDA4167);
  late Color fireOpal = const Color(0xFFEB5E55);
  late Color lightGrey = const Color(0xFFBBBBBB);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'Sora';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 57.0,
      );
  String get displayMediumFamily => 'Sora';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 45.0,
      );
  String get displaySmallFamily => 'Sora';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w800,
        fontSize: 24.0,
      );
  String get headlineLargeFamily => 'Sora';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 32.0,
      );
  String get headlineMediumFamily => 'Sora';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.sora(
        color: theme.secondaryText,
        fontWeight: FontWeight.bold,
        fontSize: 22.0,
      );
  String get headlineSmallFamily => 'Sora';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 20.0,
      );
  String get titleLargeFamily => 'Sora';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 22.0,
      );
  String get titleMediumFamily => 'Sora';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 18.0,
      );
  String get titleSmallFamily => 'Sora';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.sora(
        color: theme.secondaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      );
  String get labelLargeFamily => 'Sora';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 14.0,
      );
  String get labelMediumFamily => 'Sora';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 12.0,
      );
  String get labelSmallFamily => 'Sora';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.w500,
        fontSize: 11.0,
      );
  String get bodyLargeFamily => 'Sora';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 16.0,
      );
  String get bodyMediumFamily => 'Sora';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.sora(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
      );
  String get bodySmallFamily => 'Sora';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.sora(
        color: theme.secondaryText,
        fontWeight: FontWeight.w300,
        fontSize: 14.0,
      );
}

class FFDesignTokens {
  const FFDesignTokens(this.theme);
  final FlutterFlowTheme theme;
  FFSpacing get spacing => const FFSpacing();
  FFRadius get radius => const FFRadius();
  FFShadows get shadow => FFShadows(theme);
}

class FFSpacing {
  const FFSpacing();
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
}

class FFRadius {
  const FFRadius();
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get full => 9999.0;
}

class FFShadows {
  const FFShadows(this.theme);
  final FlutterFlowTheme theme;
  BoxShadow get sm => const BoxShadow(
      blurRadius: 3.0,
      color: const Color(0x1A000000),
      offset: const Offset(0.0, 1.0),
      spreadRadius: 0.0);
  BoxShadow get md => const BoxShadow(
      blurRadius: 6.0,
      color: const Color(0x1A000000),
      offset: const Offset(0.0, 3.0),
      spreadRadius: 0.0);
  BoxShadow get lg => const BoxShadow(
      blurRadius: 15.0,
      color: const Color(0x1A000000),
      offset: const Offset(0.0, 8.0),
      spreadRadius: 0.0);
  BoxShadow get xl => const BoxShadow(
      blurRadius: 25.0,
      color: const Color(0x1A000000),
      offset: const Offset(0.0, 16.0),
      spreadRadius: 0.0);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
