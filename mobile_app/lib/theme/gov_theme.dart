import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

/// Government of India / Ministry of Home Affairs (MHA) Design System
/// Compliant with GIGW 3.0 (Guidelines for Indian Government Websites & Apps)
/// and WCAG 2.1 Level AA (Minimum 4.5:1 text contrast).
class GovTheme {
  // --- 1. Official Color Tokens ---
  static const Color bgBase = AppColors.bgBase;
  static const Color bgSurface = AppColors.bgSurface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color borderDefault = AppColors.borderDefault;
  
  // Government Identity Colors
  static const Color primary = AppColors.primary;
  static const Color primaryPressed = AppColors.primaryPressed;
  static const Color secondary = AppColors.secondary;
  
  // Sovereign Indian Tricolor Accents
  static const Color tricolorSaffron = AppColors.sovereignSaffron;
  static const Color tricolorWhite = AppColors.bgSurface;
  static const Color tricolorGreen = AppColors.sovereignGreen;
  static const Color ashokaNavy = AppColors.primary;

  // --- 2. Forensic / Contraband Status Colors (Non-Traffic-Light Naive) ---
  // Positive = Contraband Detected (Alert state) -> High contrast Red
  static const Color alertPositiveBg = AppColors.positiveBg;
  static const Color alertPositiveText = AppColors.positiveText;

  // Negative = No Contraband Detected (Clear state) -> High contrast Green
  static const Color alertNegativeBg = AppColors.negativeBg;
  static const Color alertNegativeText = AppColors.negativeText;
  static const Color statusSuccess = AppColors.negativeText;

  // Inconclusive = Degraded/Unconfirmed (Lab/Retest needed) -> High contrast Amber
  static const Color alertInconclusiveBg = AppColors.inconclusiveBg;
  static const Color alertInconclusiveText = AppColors.inconclusiveText;

  // --- 3. Typography Scale (Major Third 1.25 Ratio) ---
  static const TextStyle display = AppTextStyles.display;
  static const TextStyle title = AppTextStyles.title;
  static const TextStyle subtitle = AppTextStyles.subtitle;
  static const TextStyle body = AppTextStyles.body;
  static const TextStyle caption = AppTextStyles.caption;
  static const TextStyle codeHash = AppTextStyles.codeHash;

  // --- 4. 8dp Grid Spacing Tokens ---
  static const double space4 = AppSpacing.x1;
  static const double space8 = AppSpacing.x2;
  static const double space12 = 12.0;
  static const double space16 = AppSpacing.x4;
  static const double space20 = 20.0;
  static const double space24 = AppSpacing.x6;
  static const double space32 = AppSpacing.x8;
  static const double space40 = AppSpacing.x10;
  static const double space48 = AppSpacing.x12;

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

/// Official Government & Ministry of Home Affairs Top Header Banner
class GovHeaderBanner extends StatelessWidget {
  final String titleText;
  final String subtitleText;
  final String badgeText;

  const GovHeaderBanner({
    super.key,
    this.titleText = "MINISTRY OF HOME AFFAIRS",
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amberAccent, width: 1.5),
                  ),
                  child: Image.asset(
                    'assets/mha_emblem.png',
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.shield, color: Colors.amberAccent, size: 24),
                    ),
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
        color: GovTheme.alertInconclusiveBg,
        border: Border(
          top: BorderSide(color: GovTheme.alertInconclusiveText, width: 1),
          bottom: BorderSide(color: GovTheme.alertInconclusiveText, width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: GovTheme.alertInconclusiveText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: GovTheme.alertInconclusiveText,
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
