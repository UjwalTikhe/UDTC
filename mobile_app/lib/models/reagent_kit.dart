import 'package:flutter/material.dart';

class ReagentKit {
  final String id;
  final String name;
  final String targetDrug;
  final List<double> expectedLab; // [L*, a*, b*]
  final double thresholdPositive;
  final double thresholdInconclusive;
  final int minReactionTimeSeconds;
  final int maxReactionTimeSeconds;
  final Color representativeColor;
  final String description;

  const ReagentKit({
    required this.id,
    required this.name,
    required this.targetDrug,
    required this.expectedLab,
    required this.thresholdPositive,
    required this.thresholdInconclusive,
    required this.minReactionTimeSeconds,
    required this.maxReactionTimeSeconds,
    required this.representativeColor,
    required this.description,
  });

  String get substanceTarget => targetDrug;

  static const List<ReagentKit> allKits = [
    ReagentKit(
      id: "MARQUIS_OPIATE",
      name: "Marquis Reagent",
      targetDrug: "Opiates / Heroin / Morphine / Codeine",
      expectedLab: [26.0, 48.0, -32.0],
      thresholdPositive: 14.0,
      thresholdInconclusive: 22.0,
      minReactionTimeSeconds: 15,
      maxReactionTimeSeconds: 90,
      representativeColor: Color(0xFF5B1647), // Deep reddish purple
      description: "Formaldehyde & concentrated sulphuric acid. Rapidly turns reddish-purple in presence of opium alkaloids.",
    ),
    ReagentKit(
      id: "SCOTT_COCAINE",
      name: "Scott Reagent",
      targetDrug: "Cocaine HCl & Freebase / Crack",
      expectedLab: [38.0, -12.0, -45.0],
      thresholdPositive: 12.0,
      thresholdInconclusive: 20.0,
      minReactionTimeSeconds: 10,
      maxReactionTimeSeconds: 60,
      representativeColor: Color(0xFF0F3BBF), // Intense cobalt blue
      description: "Cobalt thiocyanate 2% in water/glycerine. Develops vivid cobalt blue precipitate with cocaine salts.",
    ),
    ReagentKit(
      id: "DUQUENOIS_THC",
      name: "Duquenois-Levine",
      targetDrug: "Cannabinoids (THC / Hashish / Ganja / Charas)",
      expectedLab: [32.0, 36.0, -22.0],
      thresholdPositive: 15.0,
      thresholdInconclusive: 25.0,
      minReactionTimeSeconds: 30,
      maxReactionTimeSeconds: 120,
      representativeColor: Color(0xFF701A75), // Deep violet
      description: "Vanillin, acetaldehyde and ethanol with HCl. Violet pigment extracts into lower chloroform layer.",
    ),
    ReagentKit(
      id: "MANDELIN_AMPHETAMINE",
      name: "Mandelin Reagent",
      targetDrug: "Amphetamines / Methamphetamine / MDMA",
      expectedLab: [30.0, 10.0, 40.0],
      thresholdPositive: 14.0,
      thresholdInconclusive: 22.0,
      minReactionTimeSeconds: 15,
      maxReactionTimeSeconds: 60,
      representativeColor: Color(0xFF1E3A20), // Dark olive green
      description: "Ammonium metavanadate in sulphuric acid. Converts to dark green/brown-green with amphetamines.",
    ),
  ];

  static ReagentKit getById(String id) {
    return allKits.firstWhere(
      (k) => k.id == id,
      orElse: () => allKits[0],
    );
  }
}
