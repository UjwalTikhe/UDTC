import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_field_drug_testing/models/domain_models.dart';
import 'package:sih_field_drug_testing/services/optical_processing_service.dart';

void main() {
  test('OpticalProcessingService processes positive field sample image', () {
    final file = File('assets/field_sample_positive.png');
    expect(file.existsSync(), isTrue);

    final input = OpticalAnalysisInput(
      imagePath: file.path,
      kitType: KitType.nddk,
      cardSerial: 'MHACARD-NDDK-2026-DEL-0491',
    );

    final output = OpticalProcessingService.analyzeFrameSync(input);
    print('Positive Sample Result: ${output.classification.category}, Confidence: ${output.classification.confidence}%, deltaE: ${output.deltaE}');
    print('Measured Lab: ${output.measuredLab}, Expected Lab: ${output.expectedLab}');
    print('Measured RGB: ${output.measuredRgb}, Scales: ${output.whiteBalanceScales}');
    expect(output.classification.category, equals(ResultCategory.positive));
    expect(output.deltaE, lessThan(20.0));
    expect(output.laplacianVariance, greaterThan(100.0));
    expect(output.classification.confidence, greaterThan(70.0));
  });

  test('OpticalProcessingService processes negative field sample image', () {
    final file = File('assets/field_sample_negative.png');
    expect(file.existsSync(), isTrue);

    final input = OpticalAnalysisInput(
      imagePath: file.path,
      kitType: KitType.nddk,
      cardSerial: 'MHACARD-NDDK-2026-DEL-0491',
    );

    final output = OpticalProcessingService.analyzeFrameSync(input);
    print('Negative Sample Result: ${output.classification.category}, Confidence: ${output.classification.confidence}%, deltaE: ${output.deltaE}');
    expect(output.classification.category, equals(ResultCategory.negative));
  });

  test('OpticalProcessingService visibly reduces confidence on blurry sample image', () {
    final sharpFile = File('assets/field_sample_negative.png');
    final blurryFile = File('assets/field_sample_blurry.png');

    final sharpOutput = OpticalProcessingService.analyzeFrameSync(
      OpticalAnalysisInput(imagePath: sharpFile.path, kitType: KitType.nddk, cardSerial: 'MHACARD-NDDK-0491'),
    );
    final blurryOutput = OpticalProcessingService.analyzeFrameSync(
      OpticalAnalysisInput(imagePath: blurryFile.path, kitType: KitType.nddk, cardSerial: 'MHACARD-NDDK-0491'),
    );

    print('Sharp Confidence: ${sharpOutput.classification.confidence}%, Blurry Confidence: ${blurryOutput.classification.confidence}%');
    print('Sharp Laplacian: ${sharpOutput.laplacianVariance}, Blurry Laplacian: ${blurryOutput.laplacianVariance}');

    expect(blurryOutput.laplacianVariance, lessThan(sharpOutput.laplacianVariance));
    expect(blurryOutput.classification.confidence, lessThan(sharpOutput.classification.confidence));
  });
}
