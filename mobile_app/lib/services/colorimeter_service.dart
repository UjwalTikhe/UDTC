import 'dart:math';
import 'package:flutter/material.dart';
import '../models/reagent_kit.dart';

class ColorimetryResult {
  final List<double> measuredLab;
  final List<double> expectedLab;
  final double deltaE2000;
  final String classification; // 'PRESUMPTIVE_POSITIVE', 'PRESUMPTIVE_NEGATIVE', 'INCONCLUSIVE'
  final double confidenceScore;
  final Color measuredRgbColor;
  final Color expectedRgbColor;
  final String legalExplanation;

  ColorimetryResult({
    required this.measuredLab,
    required this.expectedLab,
    required this.deltaE2000,
    required this.classification,
    required this.confidenceScore,
    required this.measuredRgbColor,
    required this.expectedRgbColor,
    required this.legalExplanation,
  });
}

class ColorimeterService {
  /// Converts 8-bit sRGB [0..255] to CIE L*a*b* using standard D65 illuminant
  static List<double> rgbToLab(int r, int g, int b) {
    // 1. Normalize and linearize sRGB
    double lr = r / 255.0;
    double lg = g / 255.0;
    double lb = b / 255.0;

    lr = (lr > 0.04045) ? pow((lr + 0.055) / 1.055, 2.4).toDouble() : (lr / 12.92);
    lg = (lg > 0.04045) ? pow((lg + 0.055) / 1.055, 2.4).toDouble() : (lg / 12.92);
    lb = (lb > 0.04045) ? pow((lb + 0.055) / 1.055, 2.4).toDouble() : (lb / 12.92);

    // 2. Convert sRGB to XYZ (D65 illuminant)
    double x = (0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb) * 100.0;
    double y = (0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb) * 100.0;
    double z = (0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb) * 100.0;

    // D65 reference white
    const double xn = 95.047;
    const double yn = 100.000;
    const double zn = 108.883;

    double xr = x / xn;
    double yr = y / yn;
    double zr = z / zn;

    double fx = (xr > 0.008856) ? pow(xr, 1.0 / 3.0).toDouble() : (7.787 * xr + 16.0 / 116.0);
    double fy = (yr > 0.008856) ? pow(yr, 1.0 / 3.0).toDouble() : (7.787 * yr + 16.0 / 116.0);
    double fz = (zr > 0.008856) ? pow(zr, 1.0 / 3.0).toDouble() : (7.787 * zr + 16.0 / 116.0);

    double lVal = max(0.0, min(100.0, 116.0 * fy - 16.0));
    double aVal = 500.0 * (fx - fy);
    double bVal = 200.0 * (fy - fz);

    return [lVal, aVal, bVal];
  }

  /// Converts CIE L*a*b* back to approximate sRGB Color for UI rendering
  static Color labToRgb(double l, double a, double b) {
    double fy = (l + 16.0) / 116.0;
    double fx = a / 500.0 + fy;
    double fz = fy - b / 200.0;

    const double delta = 6.0 / 29.0;
    double x = (fx > delta) ? pow(fx, 3).toDouble() : (fx - 16.0 / 116.0) * 3 * delta * delta;
    double y = (fy > delta) ? pow(fy, 3).toDouble() : (fy - 16.0 / 116.0) * 3 * delta * delta;
    double z = (fz > delta) ? pow(fz, 3).toDouble() : (fz - 16.0 / 116.0) * 3 * delta * delta;

    x *= 95.047 / 100.0;
    y *= 100.000 / 100.0;
    z *= 108.883 / 100.0;

    double rLin = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    double gLin = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    double bLin = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;

    int r = (max(0.0, min(1.0, (rLin > 0.0031308) ? 1.055 * pow(rLin, 1.0 / 2.4) - 0.055 : 12.92 * rLin)) * 255).round();
    int g = (max(0.0, min(1.0, (gLin > 0.0031308) ? 1.055 * pow(gLin, 1.0 / 2.4) - 0.055 : 12.92 * gLin)) * 255).round();
    int bInt = (max(0.0, min(1.0, (bLin > 0.0031308) ? 1.055 * pow(bLin, 1.0 / 2.4) - 0.055 : 12.92 * bLin)) * 255).round();

    return Color.fromARGB(255, r, g, bInt);
  }

  /// Exact CIEDE2000 (ΔE₀₀) color difference algorithm
  static double computeDeltaE2000(List<double> lab1, List<double> lab2) {
    final double l1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
    final double l2 = lab2[0], a2 = lab2[1], b2 = lab2[2];

    final double c1 = sqrt(a1 * a1 + b1 * b1);
    final double c2 = sqrt(a2 * a2 + b2 * b2);
    final double cBar = (c1 + c2) / 2.0;

    final double g = 0.5 * (1.0 - sqrt(pow(cBar, 7) / (pow(cBar, 7) + pow(25.0, 7))));
    final double a1Prime = a1 * (1.0 + g);
    final double a2Prime = a2 * (1.0 + g);

    final double c1Prime = sqrt(a1Prime * a1Prime + b1 * b1);
    final double c2Prime = sqrt(a2Prime * a2Prime + b2 * b2);

    double h1Prime = atan2(b1, a1Prime) * 180.0 / pi;
    if (h1Prime < 0) h1Prime += 360.0;

    double h2Prime = atan2(b2, a2Prime) * 180.0 / pi;
    if (h2Prime < 0) h2Prime += 360.0;

    final double deltaLPrime = l2 - l1;
    final double deltaCPrime = c2Prime - c1Prime;

    double deltahPrime;
    if (c1Prime * c2Prime == 0) {
      deltahPrime = 0.0;
    } else if ((h2Prime - h1Prime).abs() <= 180.0) {
      deltahPrime = h2Prime - h1Prime;
    } else if (h2Prime - h1Prime > 180.0) {
      deltahPrime = (h2Prime - h1Prime) - 360.0;
    } else {
      deltahPrime = (h2Prime - h1Prime) + 360.0;
    }

    final double deltaHPrime = 2.0 * sqrt(c1Prime * c2Prime) * sin((deltahPrime / 2.0) * pi / 180.0);

    final double lBarPrime = (l1 + l2) / 2.0;
    final double cBarPrime = (c1Prime + c2Prime) / 2.0;

    double hBarPrime;
    if (c1Prime * c2Prime == 0) {
      hBarPrime = h1Prime + h2Prime;
    } else if ((h1Prime - h2Prime).abs() <= 180.0) {
      hBarPrime = (h1Prime + h2Prime) / 2.0;
    } else if (h1Prime + h2Prime < 360.0) {
      hBarPrime = (h1Prime + h2Prime + 360.0) / 2.0;
    } else {
      hBarPrime = (h1Prime + h2Prime - 360.0) / 2.0;
    }

    final double t = 1.0 -
        0.17 * cos((hBarPrime - 30.0) * pi / 180.0) +
        0.24 * cos((2.0 * hBarPrime) * pi / 180.0) +
        0.32 * cos((3.0 * hBarPrime + 6.0) * pi / 180.0) -
        0.20 * cos((4.0 * hBarPrime - 63.0) * pi / 180.0);

    final double deltaTheta = 30.0 * exp(-pow((hBarPrime - 275.0) / 25.0, 2));
    final double rc = 2.0 * sqrt(pow(cBarPrime, 7) / (pow(cBarPrime, 7) + pow(25.0, 7)));
    final double rt = -sin(2.0 * deltaTheta * pi / 180.0) * rc;

    final double sl = 1.0 + (0.015 * pow(lBarPrime - 50.0, 2)) / sqrt(20.0 + pow(lBarPrime - 50.0, 2));
    final double sc = 1.0 + 0.045 * cBarPrime;
    final double sh = 1.0 + 0.015 * cBarPrime * t;

    final double termL = deltaLPrime / sl;
    final double termC = deltaCPrime / sc;
    final double termH = deltaHPrime / sh;

    final double deltaE = sqrt(termL * termL + termC * termC + termH * termH + rt * termC * termH);
    return deltaE;
  }

  /// Analyzes a field test color patch against the selected reagent profile
  static ColorimetryResult evaluateReagentSample({
    required ReagentKit kit,
    required List<double> measuredLab,
    double blurVariance = 120.0,
  }) {
    final double deltaE = computeDeltaE2000(measuredLab, kit.expectedLab);

    String classification;
    String legalExplanation;

    if (deltaE <= kit.thresholdPositive) {
      classification = "PRESUMPTIVE_POSITIVE";
      legalExplanation = "Measured color deviation (ΔE₀₀ = ${deltaE.toStringAsFixed(2)}) is within statutory field threshold (≤ ${kit.thresholdPositive}). Reagent reaction strongly aligns with ${kit.targetDrug}.";
    } else if (deltaE <= kit.thresholdInconclusive) {
      classification = "INCONCLUSIVE";
      legalExplanation = "Measured color deviation (ΔE₀₀ = ${deltaE.toStringAsFixed(2)}) is in the marginal indeterminate zone (${kit.thresholdPositive} < ΔE₀₀ ≤ ${kit.thresholdInconclusive}). Lighting or contaminant interference suspected.";
    } else {
      classification = "PRESUMPTIVE_NEGATIVE";
      legalExplanation = "Measured color deviation (ΔE₀₀ = ${deltaE.toStringAsFixed(2)}) exceeds tolerance (> ${kit.thresholdInconclusive}). No characteristic chromatic reaction detected for ${kit.targetDrug}.";
    }

    // Confidence as a function of ΔE and image sharpness
    double confidence = max(15.0, min(99.4, 100.0 - (deltaE * 2.6)));
    if (blurVariance < 75.0) {
      confidence *= 0.85; // Penalize for blur
    }

    return ColorimetryResult(
      measuredLab: measuredLab,
      expectedLab: kit.expectedLab,
      deltaE2000: deltaE,
      classification: classification,
      confidenceScore: double.parse(confidence.toStringAsFixed(1)),
      measuredRgbColor: labToRgb(measuredLab[0], measuredLab[1], measuredLab[2]),
      expectedRgbColor: labToRgb(kit.expectedLab[0], kit.expectedLab[1], kit.expectedLab[2]),
      legalExplanation: legalExplanation,
    );
  }
}
