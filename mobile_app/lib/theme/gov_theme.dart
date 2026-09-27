import 'package:flutter/material.dart';

/// Government of India / Narcotics Control Bureau (NCB) Design System
/// Compliant with GIGW 3.0 (Guidelines for Indian Government Websites & Apps)
/// and WCAG 2.1 Level AA (Minimum 4.5:1 text contrast).
class GovTheme {
  // --- 1. Official Color Tokens ---
  static const Color bgBase = Color(0xFFF7F9FC); // Light, cool, crisp canvas
  static const Color bgSurface = Color(0xFFFFFFFF); // Clean elevated surfaces
  static const Color textPrimary = Color(0xFF1A1F29); // 15.65:1 contrast against bgBase
  static const Color textSecondary = Color(0xFF5B6472); // ~4.6:1 contrast against bgBase
  static const Color borderDefault = Color(0xFFE1E5EB); // Subtle framing divider
  
  // Government Identity Colors
  static const Color primary = Color(0xFF1E4B8F); // Indian Govt Emblem Navy (8.55:1 against white)
  static const Color primaryPressed = Color(0xFF163765);
  static const Color secondary = Color(0xFF445266);
  
  // Sovereign Indian Tricolor Accents
  static const Color tricolorSaffron = Color(0xFFFF9933);
  static const Color tricolorWhite = Color(0xFFFFFFFF);
  static const Color tricolorGreen = Color(0xFF138808);
  static const Color ashokaNavy = Color(0xFF0A2558);

  // --- 2. Forensic / Contraband Status Colors (Non-Traffic-Light Naive) ---
  // Positive = Contraband Detected (Alert state) -> High contrast Red
  static const Color alertPositiveBg = Color(0xFFFDECEA);
  static const Color alertPositiveText = Color(0xFFB3261E); // 5.71:1 contrast

  // Negative = No Contraband Detected (Clear state) -> High contrast Green
  static const Color alertNegativeBg = Color(0xFFE8F5E9);
  static const Color alertNegativeText = Color(0xFF1B6E2F); // 5.62:1 contrast

  // Inconclusive = Degraded/Unconfirmed (Lab/Retest needed) -> High contrast Amber
  static const Color alertInconclusiveBg = Color(0xFFFFF4E0);
  static const Color alertInconclusiveText = Color(0xFF9E5B00); // 4.88:1 contrast

  // --- 3. Typography Scale (Major Third 1.25 Ratio) ---
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: textPrimary,
    fontFamily: 'Roboto',
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: textPrimary,
    fontFamily: 'Roboto',
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Roboto',
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.45,
    fontFamily: 'Roboto',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    fontFamily: 'Roboto',
  );

  static const TextStyle codeHash = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    color: textPrimary,
    letterSpacing: 0.5,
  );

  // --- 4. 8dp Grid Spacing Tokens ---
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // --- 5. Touch Target Constraints ---
  static const double minTouchTarget = 48.0;
  static const double primaryButtonHeight = 56.0;
  static const double shutterDiameter = 72.0;

  // --- 6. ThemeData Constructor ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgBase,
      primaryColor: primary,
      cardColor: bgSurface,
      dividerColor: borderDefault,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: bgSurface,
        background: bgBase,
        error: alertPositiveText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ashokaNavy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(primaryButtonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          minimumSize: const Size.fromHeight(primaryButtonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
    );
  }
}

/// Official Indian Government Tricolor Bar Widget
class GovTricolorBar extends StatelessWidget {
  final double height;
  const GovTricolorBar({super.key, this.height = 4.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: height, color: GovTheme.tricolorSaffron)),
        Expanded(child: Container(height: height, color: GovTheme.tricolorWhite)),
        Expanded(child: Container(height: height, color: GovTheme.tricolorGreen)),
      ],
    );
  }
}

/// Official Government & Narcotics Control Bureau Top Header Banner
class GovHeaderBanner extends StatelessWidget {
  final String titleText;
  final String subtitleText;
  final String badgeText;

  const GovHeaderBanner({
    super.key,
    this.titleText = "NARCOTICS CONTROL BUREAU",
    this.subtitleText = "MINISTRY OF HOME AFFAIRS • GOVT OF INDIA",
    this.badgeText = "NDPS §52A / BSA §63 SECURE APPARATUS",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GovTheme.ashokaNavy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield, color: Colors.amberAccent, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amberAccent, width: 1),
                  ),
                  child: const Text(
                    "SECURE",
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const GovTricolorBar(height: 3),
        ],
      ),
    );
  }
}

/// Non-Dismissible Statutory Warning Banner (Mandatory under NDPS §52A / BSA §63)
class StatutoryWarningBanner extends StatelessWidget {
  final String text;

  const StatutoryWarningBanner({
    super.key,
    this.text = "Presumptive field result only — mandatory laboratory confirmation required under NDPS Act §52A & BSA 2023 §63.",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border(
          top: BorderSide(color: const Color(0xFFFFEEBA), width: 1),
          bottom: BorderSide(color: const Color(0xFFFFD966), width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: Color(0xFF856404), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF856404),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official High-Contrast Result Badge (Icon + Text + Tint)
class GovResultBadge extends StatelessWidget {
  final String classification;
  final double confidence;
  final bool isLarge;

  const GovResultBadge({
    super.key,
    required this.classification,
    required this.confidence,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPos = classification.toUpperCase().contains("POS");
    final bool isNeg = classification.toUpperCase().contains("NEG");

    final Color bgColor = isPos
        ? GovTheme.alertPositiveBg
        : (isNeg ? GovTheme.alertNegativeBg : GovTheme.alertInconclusiveBg);

    final Color fgColor = isPos
        ? GovTheme.alertPositiveText
        : (isNeg ? GovTheme.alertNegativeText : GovTheme.alertInconclusiveText);

    final IconData icon = isPos
        ? Icons.warning_amber_rounded
        : (isNeg ? Icons.check_circle_outline_rounded : Icons.help_outline_rounded);

    final String label = isPos
        ? "CONTRABAND DETECTED (POSITIVE)"
        : (isNeg ? "NO CONTRABAND DETECTED (NEGATIVE)" : "INCONCLUSIVE / RETEST REQUIRED");

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 20 : 12,
        vertical: isLarge ? 16 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fgColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: isLarge ? 32 : 20),
          SizedBox(width: isLarge ? 12 : 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: isLarge ? 16 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  "Forensic Match Confidence: ${confidence.toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: fgColor.withOpacity(0.9),
                    fontSize: isLarge ? 13 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
