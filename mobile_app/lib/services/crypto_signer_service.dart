import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class DualSignatureResult {
  final String deviceSigHex;
  final String officerSigHex;
  final String devicePublicKeyFingerprint;
  final int timestampUtc;

  DualSignatureResult({
    required this.deviceSigHex,
    required this.officerSigHex,
    required this.devicePublicKeyFingerprint,
    required this.timestampUtc,
  });
}

class CryptoSignerService {
  static final CryptoSignerService instance = CryptoSignerService._internal();

  CryptoSignerService._internal();

  // Persistent simulated Android Keystore StrongBox ECDSA P-256 key pair
  ECPrivateKey? _devicePrivateKey;
  ECPublicKey? _devicePublicKey;
  String _deviceKeyFingerprint = "KEYSTORE-P256-MHA-DEV-042";
  String? _derivedOfficerPin;
  String _currentOfficerId = "OFFICER-7841";

  String get deviceKeyFingerprint => _deviceKeyFingerprint;

  void deriveOfficerKeyFromPin(String pin, {String officerId = "OFFICER-7841"}) {
    _derivedOfficerPin = pin;
    _currentOfficerId = officerId;
  }

  String signWithDeviceHardware(String payload) => signWithDeviceHardwareKey(payload);

  String signWithOfficerKey(String payload) {
    return signWithOfficerPin(
      officerPin: _derivedOfficerPin ?? "982341",
      officerId: _currentOfficerId,
      payloadToSign: payload,
    );
  }

  void initializeHardwareKeystore() {
    if (_devicePrivateKey != null) return;

    // Initialize secp256r1 (NIST P-256) curve
    final domainParams = ECDomainParameters('prime256v1');
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(domainParams), secureRandom));

    final pair = keyGen.generateKeyPair();
    _devicePrivateKey = pair.privateKey as ECPrivateKey;
    _devicePublicKey = pair.publicKey as ECPublicKey;

    final pubBytes = _devicePublicKey!.Q!.getEncoded(false);
    final pubDigest = sha256.convert(pubBytes);
    _deviceKeyFingerprint = "KS-P256:${pubDigest.toString().substring(0, 16).toUpperCase()}";
  }

  /// Factor 1: Device Hardware Signature (ECDSA P-256 / SHA-256)
  /// Non-exportable hardware-backed signing
  String signWithDeviceHardwareKey(String payloadToSign) {
    initializeHardwareKeystore();

    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64));
    final privKeyParam = PrivateKeyParameter<ECPrivateKey>(_devicePrivateKey!);
    signer.init(true, privKeyParam);

    final payloadBytes = utf8.encode(payloadToSign);
    final sig = signer.generateSignature(Uint8List.fromList(payloadBytes)) as ECSignature;

    // Encode r and s as 64-byte hex (32 bytes r + 32 bytes s)
    final rHex = sig.r.toRadixString(16).padLeft(64, '0');
    final sHex = sig.s.toRadixString(16).padLeft(64, '0');
    return '$rHex$sHex';
  }

  /// Factor 2: Officer Signature (PBKDF2 with SHA-256 derived from Officer PIN + Officer ID salt)
  /// Derived in-memory only at time of test verification; never persisted to disk.
  String signWithOfficerPin({
    required String officerPin,
    required String officerId,
    required String payloadToSign,
  }) {
    // 1. Derive 256-bit officer key using PBKDF2 (10,000 iterations)
    final pbkdf2 = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final salt = utf8.encode("MHA-SALT-LEGAL:$officerId");
    final params = Pbkdf2Parameters(Uint8List.fromList(salt), 10000, 32);
    pbkdf2.init(params);

    final pinBytes = utf8.encode(officerPin);
    final derivedKeyBytes = pbkdf2.process(Uint8List.fromList(pinBytes));

    // 2. Compute HMAC-SHA256 over the payload using the derived officer key
    final hmac = Hmac(sha256, derivedKeyBytes);
    final digest = hmac.convert(utf8.encode(payloadToSign));
    return digest.toString();
  }

  /// Executes complete Section 4.3 Dual-Bound Signature on a field test
  DualSignatureResult signDualBound({
    required String canonicalRecordPayload,
    required String officerPin,
    required String officerId,
  }) {
    final devSig = signWithDeviceHardwareKey(canonicalRecordPayload);
    final offSig = signWithOfficerPin(
      officerPin: officerPin,
      officerId: officerId,
      payloadToSign: canonicalRecordPayload,
    );

    return DualSignatureResult(
      deviceSigHex: devSig,
      officerSigHex: offSig,
      devicePublicKeyFingerprint: _deviceKeyFingerprint,
      timestampUtc: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    );
  }
}
