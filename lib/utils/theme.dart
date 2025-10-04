import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Color Palette ---
const Color kColorBlack = Color(0xFF000000);
const Color kColorWhite = Color(0xFFFFFFFF);
const Color kColorGreyDark = Color(0xFF333333); // For borders and dividers
const Color kColorGreyLight = Color(0xFF808080); // For secondary text
const Color kColorOverlay = Color.fromRGBO(0, 0, 0, 0.7); // Overlay with 70% opacity

// --- Text Styles ---
final TextTheme kTextTheme = TextTheme(
  displayLarge: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: kColorWhite),
  bodyLarge: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.normal, color: kColorWhite),
  bodyMedium: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.normal, color: kColorGreyLight),
  labelLarge: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: kColorBlack), // For buttons with white background
);

// --- App Theme ---
final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kColorBlack,
  primaryColor: kColorBlack,
  fontFamily: GoogleFonts.roboto().fontFamily,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: kColorWhite,
    onPrimary: kColorBlack,
    secondary: kColorGreyLight,
    onSecondary: kColorBlack,
    error: Colors.redAccent, // Standard error color for visibility
    onError: kColorWhite,
    background: kColorBlack,
    onBackground: kColorWhite,
    surface: kColorBlack,
    onSurface: kColorWhite,
    tertiary: kColorGreyDark, // Used for borders
  ),
  textTheme: kTextTheme,
  appBarTheme: AppBarTheme(
    backgroundColor: kColorBlack,
    elevation: 0,
    iconTheme: const IconThemeData(color: kColorWhite, size: 24),
    titleTextStyle: kTextTheme.displayLarge?.copyWith(fontSize: 20),
  ),
  iconTheme: const IconThemeData(
    color: kColorWhite,
    size: 24,
  ),
  inputDecorationTheme: InputDecorationTheme(
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: kColorGreyDark),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: kColorWhite),
    ),
    labelStyle: kTextTheme.bodyMedium,
    hintStyle: kTextTheme.bodyMedium,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: kColorWhite,
    linearTrackColor: kColorGreyDark,
  ),
  tooltipTheme: TooltipThemeData(
    padding: const EdgeInsets.all(8.0),
    textStyle: kTextTheme.bodyMedium?.copyWith(color: kColorWhite),
    decoration: BoxDecoration(
      color: kColorGreyDark,
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);