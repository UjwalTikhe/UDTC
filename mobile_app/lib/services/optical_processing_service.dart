import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/domain_models.dart';
import 'colorimeter_service.dart';

/// Reagent candidate outcome in the MHA field testing database
class CandidateOutcome {
  final String id;
  final String name;
  final String targetDrug;
  final List<double> expectedLab; // [L*, a*, b*]
  final double threshold;
  final bool isPositive;
  final bool requiresSecondaryStep;
  final String? secondaryReagentName;
  final String? secondaryReagentPurpose;
  final List<String> interferents;

  const CandidateOutcome({
    required this.id,
    required this.name,
    required this.targetDrug,
    required this.expectedLab,
    required this.threshold,
    required this.isPositive,
    this.requiresSecondaryStep = false,
    this.secondaryReagentName,
    this.secondaryReagentPurpose,
    this.interferents = const [],
  });
}

/// Analysis input parameters for isolate execution
class OpticalAnalysisInput {
  final String imagePath;
  final List<int>? imageBytes;
  final KitType kitType;
  final int reagentStep; // 1 = Primary, 2 = Secondary
  final String cardSerial;

  OpticalAnalysisInput({
    required this.imagePath,
    this.imageBytes,
    required this.kitType,
    this.reagentStep = 1,
    required this.cardSerial,
  });
}

/// Structured analysis output returned from pixel-level CV analysis
class OpticalAnalysisOutput {
  final ClassificationResult classification;
  final double deltaE;
  final List<double> measuredLab;
  final List<double> expectedLab;
  final Color measuredRgb;
  final Color expectedRgb;
  final double laplacianVariance;
  final double exposureScore;
  final bool cardDetected;
  final bool whiteBalanceApplied;
  final List<double> whiteBalanceScales; // [sR, sG, sB]
  final bool requiresSecondaryStep;
  final String? secondaryReagentName;
  final String? secondaryReagentPurpose;
  final String matchedCandidateName;
  final String diagnosticSummary;

  OpticalAnalysisOutput({
    required this.classification,
    required this.deltaE,
    required this.measuredLab,
    required this.expectedLab,
    required this.measuredRgb,
    required this.expectedRgb,
    required this.laplacianVariance,
    required this.exposureScore,
    required this.cardDetected,
    required this.whiteBalanceApplied,
    required this.whiteBalanceScales,
    required this.requiresSecondaryStep,
    this.secondaryReagentName,
    this.secondaryReagentPurpose,
    required this.matchedCandidateName,
    required this.diagnosticSummary,
  });
}

class OpticalProcessingService {
  static final OpticalProcessingService instance = OpticalProcessingService._internal();

  OpticalProcessingService._internal();

  /// Statutory Reagent Sequence Database (NDDK, PCDK, KDK)
  static final Map<KitType, Map<int, List<CandidateOutcome>>> reagentDatabase = {
    KitType.nddk: {
      1: [
        // NDDK Step 1: Marquis Reagent
        CandidateOutcome(
          id: "NDDK_MARQUIS_OPIATE",
          name: "Opiates (Heroin / Morphine / Codeine)",
          targetDrug: "Heroin / Morphine / Opium Alkaloids",
          expectedLab: [68.0, 18.0, -12.0], // Characteristic violet-purple Marquis chromophore
          threshold: 18.0,
          isPositive: true,
          requiresSecondaryStep: true,
          secondaryReagentName: "Nitric Acid (HNO3)",
          secondaryReagentPurpose: "Differentiate Heroin vs Morphine vs Codeine",
          interferents: [
            "NOTE: Heroin / Morphine / Opium alkaloids detected.",
            "KNOWN INTERFERENT: Levamisole, Paracetamol, or Codeine may produce secondary chromophore reaction; quantitative laboratory chromatography (GC-MS / HPLC) mandated under NDPS §52A.",
          ],
        ),
        CandidateOutcome(
          id: "NDDK_MARQUIS_AMPHETAMINE",
          name: "Amphetamine / Methamphetamine",
          targetDrug: "Amphetamine / Methamphetamine",
          expectedLab: [38.0, 22.0, 45.0], // Orange-brown
          threshold: 16.0,
          isPositive: true,
          requiresSecondaryStep: false,
          interferents: [
            "KNOWN INTERFERENT: Ephedrine/Pseudoephedrine may produce faint orange reaction.",
          ],
        ),
        CandidateOutcome(
          id: "NDDK_MARQUIS_MDMA",
          name: "MDMA / Ecstasy",
          targetDrug: "MDMA / MDA / MDEA",
          expectedLab: [15.0, 8.0, -12.0], // Dark purple to black
          threshold: 15.0,
          isPositive: true,
          requiresSecondaryStep: false,
          interferents: [
            "KNOWN INTERFERENT: Sugar, lactose, and flour caramelize to black with sulfuric acid. Verify rapid color evolution (<15s).",
          ],
        ),
        CandidateOutcome(
          id: "NDDK_MARQUIS_NEGATIVE",
          name: "Unreactive / Negative",
          targetDrug: "No Contraband Alkaloid Detected",
          expectedLab: [82.0, -2.0, 28.0], // Amber / pale straw unreacted Marquis
          threshold: 14.0,
          isPositive: false,
          interferents: [],
        ),
      ],
      2: [
        // NDDK Step 2: Nitric Acid Secondary Confirmation
        CandidateOutcome(
          id: "NDDK_NITRIC_HEROIN",
          name: "Heroin (Diacetylmorphine)",
          targetDrug: "Heroin (Diacetylmorphine)",
          expectedLab: [65.0, 4.0, 52.0], // Yellow to green-yellow
          threshold: 18.0,
          isPositive: true,
          interferents: [
            "CONFIRMED HEROIN CHROMOPHORE: Differentiated from Morphine via nitric acid yellow-green shift.",
          ],
        ),
        CandidateOutcome(
          id: "NDDK_NITRIC_MORPHINE",
          name: "Morphine / Raw Opium",
          targetDrug: "Morphine / Natural Opium",
          expectedLab: [52.0, 38.0, 56.0], // Orange-red to deep orange
          threshold: 18.0,
          isPositive: true,
          interferents: [
            "CONFIRMED MORPHINE CHROMOPHORE: Rapid red-orange chromophore formation confirmed.",
          ],
        ),
        CandidateOutcome(
          id: "NDDK_NITRIC_CODEINE",
          name: "Codeine",
          targetDrug: "Codeine Base / Phosphate",
          expectedLab: [58.0, 20.0, 48.0], // Yellow-orange
          threshold: 18.0,
          isPositive: true,
          interferents: [],
        ),
      ],
    },
    KitType.pcdk: {
      1: [
        // PCDK: Duquenois-Levine Reagent
        CandidateOutcome(
          id: "PCDK_DUQUENOIS_THC",
          name: "Cannabinoids (THC / Ganja / Charas / Hashish)",
          targetDrug: "THC / Cannabinoids",
          expectedLab: [32.0, 36.0, -22.0], // Indigo-violet in lower chloroform layer
          threshold: 18.0,
          isPositive: true,
          interferents: [
            "NOTE: Cannabinoids (THC / Hashish / Ganja) detected.",
            "PROCEDURE NOTE: Violet pigment extraction into lower chloroform layer must be visually verified.",
            "KNOWN INTERFERENT: Certain culinary herbs (coffee, rosemary) produce brown-purple tint in top layer, but do NOT extract into chloroform.",
          ],
        ),
        CandidateOutcome(
          id: "PCDK_EPHEDRINE_PRECURSOR",
          name: "Ephedrine / Pseudoephedrine Precursor",
          targetDrug: "Ephedrine / Pseudoephedrine",
          expectedLab: [42.0, 25.0, -28.0], // Chen-Kao purple
          threshold: 16.0,
          isPositive: true,
          interferents: [
            "PRECURSOR CHEMICAL DETECTED: Ephedrine / Pseudoephedrine identified under NDPS Schedule A precursor controls.",
          ],
        ),
        CandidateOutcome(
          id: "PCDK_NEGATIVE",
          name: "Unreactive / Negative",
          targetDrug: "No Precursor / Cannabinoid Detected",
          expectedLab: [78.0, 2.0, 22.0], // Clear pale straw
          threshold: 14.0,
          isPositive: false,
          interferents: [],
        ),
      ],
    },
    KitType.kdk: {
      1: [
        // KDK: Scott Reagent (Cobalt Thiocyanate)
        CandidateOutcome(
          id: "KDK_SCOTT_COCAINE",
          name: "Cocaine HCl / Crack Cocaine",
          targetDrug: "Cocaine HCl / Freebase Crack",
          expectedLab: [38.0, -12.0, -45.0], // Intense Cobalt Blue precipitate in chloroform
          threshold: 18.0,
          isPositive: true,
          interferents: [
            "NOTE: Cocaine HCl / Crack detected.",
            "KNOWN INTERFERENT: Synthetic local anaesthetics (Lidocaine, Benzocaine, Procaine) may cause transient blue tint in Stage 1, but dissolve completely upon HCl addition.",
          ],
        ),
        CandidateOutcome(
          id: "KDK_SCOTT_KETAMINE",
          name: "Ketamine HCl",
          targetDrug: "Ketamine HCl",
          expectedLab: [34.0, 15.0, -38.0], // Deep Violet-Blue
          threshold: 17.0,
          isPositive: true,
          interferents: [
            "NOTE: Ketamine HCl detected.",
            "Mandatory lab confirmatory analysis under NDPS Act §52A.",
          ],
        ),
        CandidateOutcome(
          id: "KDK_NEGATIVE",
          name: "Unreactive / Negative",
          targetDrug: "No Stimulant / Ketamine Detected",
          expectedLab: [75.0, -5.0, 18.0], // Pale pink / clear
          threshold: 14.0,
          isPositive: false,
          interferents: [],
        ),
      ],
    },
  };

  /// Analyzes an image asynchronously (typically executed in compute() isolate)
  static OpticalAnalysisOutput analyzeFrameSync(OpticalAnalysisInput input) {
    // 1. Read Image Bytes
    List<int> bytes;
    if (input.imageBytes != null && input.imageBytes!.isNotEmpty) {
      bytes = input.imageBytes!;
    } else {
      final file = File(input.imagePath);
      if (file.existsSync()) {
        bytes = file.readAsBytesSync();
      } else {
        throw Exception("Target evidence photo file does not exist: ${input.imagePath}");
      }
    }

    // 2. Decode Image using pure-Dart image package
    final decodedImage = img.decodeImage(Uint8List.fromList(bytes));
    if (decodedImage == null) {
      throw Exception("Failed to decode image buffer as JPEG/PNG.");
    }

    final int width = decodedImage.width;
    final int height = decodedImage.height;

    // 3. Compute Real Laplacian Blur Variance (Sharpness)
    final double laplacianVar = _computeLaplacianVariance(decodedImage);

    // 4. Compute Real Exposure Score & Clipping Ratio
    final exposureMetrics = _computeExposureMetrics(decodedImage);
    final double exposureScore = exposureMetrics['exposureScore']!;
    final double clippingRatio = exposureMetrics['clippingRatio']!;

    // 5. Detect White-Balance Reference Patch on Reference Card
    final whiteBalanceData = _extractWhiteBalanceScaling(decodedImage);
    final bool cardDetected = whiteBalanceData['cardDetected'] as bool;
    final bool whiteBalanceApplied = whiteBalanceData['whiteBalanceApplied'] as bool;
    final List<double> scales = whiteBalanceData['scales'] as List<double>;

    // 6. Sample Center Reaction Region (ROI) and Apply White-Balance
    final List<double> correctedRgb = _sampleReactionZone(decodedImage, scales);
    final int rInt = correctedRgb[0].round().clamp(0, 255);
    final int gInt = correctedRgb[1].round().clamp(0, 255);
    final int bInt = correctedRgb[2].round().clamp(0, 255);

    // 7. Convert Corrected sRGB to CIE L*a*b* (D65 Illuminant)
    final List<double> measuredLab = ColorimeterService.rgbToLab(rInt, gInt, bInt);

    // 8. Load Candidate Reagent Database for this Kit & Step
    final kitSteps = reagentDatabase[input.kitType] ?? reagentDatabase[KitType.nddk]!;
    final candidates = kitSteps[input.reagentStep] ?? kitSteps[1]!;

    // 9. Match Against Candidates using exact CIEDE2000 (ΔE₀₀)
    CandidateOutcome? bestMatch;
    double minDeltaE = 999999.0;

    for (final candidate in candidates) {
      final double deltaE = ColorimeterService.computeDeltaE2000(measuredLab, candidate.expectedLab);
      if (deltaE < minDeltaE) {
        minDeltaE = deltaE;
        bestMatch = candidate;
      }
    }

    bestMatch ??= candidates.first;

    // 10. Determine Final Result Category
    ResultCategory category;
    if (bestMatch.isPositive) {
      if (minDeltaE <= bestMatch.threshold) {
        category = ResultCategory.positive;
      } else if (minDeltaE <= bestMatch.threshold * 1.45) {
        category = ResultCategory.inconclusive;
      } else {
        category = ResultCategory.negative;
      }
    } else {
      // Best match was unreactive standard
      if (minDeltaE <= bestMatch.threshold * 1.5) {
        category = ResultCategory.negative;
      } else {
        // If far from negative and far from positive, mark inconclusive
        category = ResultCategory.inconclusive;
      }
    }

    // If blur is catastrophic (laplacian < 15.0), fail closed to inconclusive
    if (laplacianVar < 15.0 && category == ResultCategory.positive) {
      category = ResultCategory.inconclusive;
    }

    // 11. Compute Real Dynamic Confidence %
    // Formula requirement from PDF: Confidence = f(ΔE match margin, Laplacian blur, Exposure clipping)
    // Must visibly change between high quality and degraded quality photos of the same reaction!
    final double matchMarginScore = max(0.0, 1.0 - (minDeltaE / (bestMatch.threshold * 1.4))) * 100.0;
    final double qualityBlur = min(1.0, laplacianVar / 120.0);
    final double qualityExposure = max(0.0, min(1.0, 1.0 - (clippingRatio * 2.0)));
    final double compositeQuality = qualityBlur * qualityExposure * 100.0;

    double confidence = (0.65 * matchMarginScore) + (0.35 * compositeQuality);
    confidence = confidence.clamp(15.0, 99.4);
    confidence = double.parse(confidence.toStringAsFixed(1));

    // 12. Format Diagnostic Summary & Warnings
    final List<String> warnings = List<String>.from(bestMatch.interferents);
    if (laplacianVar < 75.0) {
      warnings.insert(0, "QUALITY WARNING: Low sharpness detected (Laplacian variance: ${laplacianVar.toStringAsFixed(1)} < 75.0). Hold device steady.");
    }
    if (clippingRatio > 0.15) {
      warnings.insert(0, "EXPOSURE WARNING: High specular reflection or shadow clipping (${(clippingRatio * 100).toStringAsFixed(1)}%). Re-orient angle.");
    }

    final diagnosticSummary = "Evaluated ${width}x${height} frame against ${candidates.length} reagent models. "
        "Best match: '${bestMatch.name}' (ΔE₀₀ = ${minDeltaE.toStringAsFixed(2)}, Sharpness = ${laplacianVar.toStringAsFixed(1)}, Exposure = ${(exposureScore * 100).toStringAsFixed(0)}%).";

    return OpticalAnalysisOutput(
      classification: ClassificationResult(
        category: category,
        confidence: confidence,
        interferentWarnings: warnings,
      ),
      deltaE: double.parse(minDeltaE.toStringAsFixed(2)),
      measuredLab: [
        double.parse(measuredLab[0].toStringAsFixed(2)),
        double.parse(measuredLab[1].toStringAsFixed(2)),
        double.parse(measuredLab[2].toStringAsFixed(2)),
      ],
      expectedLab: bestMatch.expectedLab,
      measuredRgb: Color.fromARGB(255, rInt, gInt, bInt),
      expectedRgb: ColorimeterService.labToRgb(
        bestMatch.expectedLab[0],
        bestMatch.expectedLab[1],
        bestMatch.expectedLab[2],
      ),
      laplacianVariance: double.parse(laplacianVar.toStringAsFixed(2)),
      exposureScore: double.parse(exposureScore.toStringAsFixed(2)),
      cardDetected: cardDetected,
      whiteBalanceApplied: whiteBalanceApplied,
      whiteBalanceScales: scales,
      requiresSecondaryStep: bestMatch.requiresSecondaryStep && category == ResultCategory.positive && input.reagentStep == 1,
      secondaryReagentName: bestMatch.secondaryReagentName,
      secondaryReagentPurpose: bestMatch.secondaryReagentPurpose,
      matchedCandidateName: bestMatch.name,
      diagnosticSummary: diagnosticSummary,
    );
  }

  /// High-efficiency discrete 2D Laplacian operator variance calculation
  static double _computeLaplacianVariance(img.Image image) {
    final int w = image.width;
    final int h = image.height;

    // Use downsampling step for fast calculation on high-res camera photos
    final int step = max(1, (max(w, h) / 300).floor());
    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    // 5-point discrete Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
    for (int y = step; y < h - step; y += step) {
      for (int x = step; x < w - step; x += step) {
        final double center = image.getPixel(x, y).luminance.toDouble();
        final double top = image.getPixel(x, y - step).luminance.toDouble();
        final double bottom = image.getPixel(x, y + step).luminance.toDouble();
        final double left = image.getPixel(x - step, y).luminance.toDouble();
        final double right = image.getPixel(x + step, y).luminance.toDouble();

        final double lap = (top + bottom + left + right - 4.0 * center);
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final double mean = sum / count;
    final double variance = (sumSq / count) - (mean * mean);
    return max(0.0, variance);
  }

  /// Calculates dynamic range exposure and clipping ratio
  static Map<String, double> _computeExposureMetrics(img.Image image) {
    final int w = image.width;
    final int h = image.height;
    final int step = max(1, (max(w, h) / 250).floor());

    int clippedCount = 0;
    int totalCount = 0;

    for (int y = 0; y < h; y += step) {
      for (int x = 0; x < w; x += step) {
        final double lum = image.getPixel(x, y).luminance.toDouble();
        if (lum < 15.0 || lum > 245.0) {
          clippedCount++;
        }
        totalCount++;
      }
    }

    final double clippingRatio = totalCount > 0 ? (clippedCount / totalCount) : 0.0;
    final double exposureScore = max(0.0, 1.0 - clippingRatio);

    return {
      'clippingRatio': clippingRatio,
      'exposureScore': exposureScore,
    };
  }

  /// Locates reference white patch from the card alignment region and computes Bradford scaling
  static Map<String, dynamic> _extractWhiteBalanceScaling(img.Image image) {
    final int w = image.width;
    final int h = image.height;

    // Scan top 30% area of the frame (where the reference card step-wedge sits)
    int rSum = 0;
    int gSum = 0;
    int bSum = 0;
    int whiteSamples = 0;

    final int step = max(1, (w / 150).floor());

    for (int y = (h * 0.05).toInt(); y < (h * 0.35).toInt(); y += step) {
      for (int x = (w * 0.15).toInt(); x < (w * 0.85).toInt(); x += step) {
        final pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // White reference patch candidate: high luminance and neutral saturation
        final int maxC = max(r, max(g, b));
        final int minC = min(r, min(g, b));
        if (minC > 165 && (maxC - minC) < 32) {
          rSum += r;
          gSum += g;
          bSum += b;
          whiteSamples++;
        }
      }
    }

    if (whiteSamples > 25) {
      final double rMean = rSum / whiteSamples;
      final double gMean = gSum / whiteSamples;
      final double bMean = bSum / whiteSamples;

      // Scaling factors to D65 standard target white (245, 245, 245)
      final double sR = 245.0 / max(10.0, rMean);
      final double sG = 245.0 / max(10.0, gMean);
      final double sB = 245.0 / max(10.0, bMean);

      return {
        'cardDetected': true,
        'whiteBalanceApplied': true,
        'scales': [sR, sG, sB],
      };
    }

    // Default unity scaling if card patch not isolated
    return {
      'cardDetected': false,
      'whiteBalanceApplied': false,
      'scales': [1.0, 1.0, 1.0],
    };
  }

  /// Samples the center reaction spot region with specular glare rejection
  static List<double> _sampleReactionZone(img.Image image, List<double> scales) {
    final int w = image.width;
    final int h = image.height;

    final int startX = (w * 0.35).toInt();
    final int endX = (w * 0.65).toInt();
    final int startY = (h * 0.35).toInt();
    final int endY = (h * 0.65).toInt();

    final int step = max(1, ((endX - startX) / 80).floor());

    double rAcc = 0;
    double gAcc = 0;
    double bAcc = 0;
    int count = 0;

    for (int y = startY; y < endY; y += step) {
      for (int x = startX; x < endX; x += step) {
        final pixel = image.getPixel(x, y);
        final double r = pixel.r.toDouble();
        final double g = pixel.g.toDouble();
        final double b = pixel.b.toDouble();

        // Reject saturated specular reflections (glare) and extreme dark shadows
        final double lum = pixel.luminance.toDouble();
        if (lum > 15.0 && lum < 245.0) {
          rAcc += r;
          gAcc += g;
          bAcc += b;
          count++;
        }
      }
    }

    if (count == 0) {
      return [128.0, 128.0, 128.0];
    }

    final double rRaw = rAcc / count;
    final double gRaw = gAcc / count;
    final double bRaw = bAcc / count;

    // Apply chromatic scaling factors
    final double rCorr = (rRaw * scales[0]).clamp(0.0, 255.0);
    final double gCorr = (gRaw * scales[1]).clamp(0.0, 255.0);
    final double bCorr = (bRaw * scales[2]).clamp(0.0, 255.0);

    return [rCorr, gCorr, bCorr];
  }

  /// Top-level compute() entry point for background isolate execution
  Future<OpticalAnalysisOutput> analyzeCapturedFrame(OpticalAnalysisInput input) async {
    return await compute(analyzeFrameSync, input);
  }
}
