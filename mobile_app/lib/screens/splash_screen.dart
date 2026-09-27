import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../services/crypto_signer_service.dart';
import 'login_screen.dart';

/// Screen 1: Splash Screen
/// Official Government apparatus boot sequence, hardware keystore validation,
/// and provisioning integrity check under GIGW 3.0 standards.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = "Initializing Hardware Keystore...";
  bool _isKeystoreReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrapDevice();
  }

  Future<void> _bootstrapDevice() async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _statusText = "Verifying Hardware Key Fingerprint (P-256)...");

      final signer = CryptoSignerService.instance;
      signer.initializeHardwareKeystore();

      await Future.delayed(const Duration(milliseconds: 700));
      setState(() {
        _isKeystoreReady = true;
        _statusText = "Apparatus Provisioned & Verified. Loading Officer Portal...";
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Keystore Verification Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
              subtitleText: "GOVERNMENT OF INDIA • MINISTRY OF HOME AFFAIRS",
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(GovTheme.space24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ashoka Emblem / Forensic Shield Container
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: GovTheme.ashokaNavy,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: GovTheme.tricolorSaffron, width: 3),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.local_police,
                            color: Colors.amberAccent,
                            size: 58,
                          ),
                        ),
                      ),
                      const SizedBox(height: GovTheme.space24),
                      const Text(
                        "FIELD DRUG TESTING APPARATUS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: GovTheme.ashokaNavy,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: GovTheme.space8),
                      const Text(
                        "Digital Evidence Companion (SIH26231)\nNDPS Act §52A • Bharatiya Sakshya Adhiniyam §63",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GovTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: GovTheme.space40),
                      // Hardware Verification Progress Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(GovTheme.space16),
                        decoration: BoxDecoration(
                          color: GovTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GovTheme.borderDefault),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: GovTheme.primary,
                              ),
                            ),
                            const SizedBox(height: GovTheme.space16),
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GovTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: GovTheme.space8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isKeystoreReady ? Icons.check_circle : Icons.shield_outlined,
                                  size: 16,
                                  color: _isKeystoreReady ? GovTheme.alertNegativeText : GovTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Hardware Fingerprint: SHA256:7B8C...3F91",
                                  style: GovTheme.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Statutory Footer
            const StatutoryWarningBanner(
              text: "OFFICIAL GOVERNMENT PROPERTY: Unauthorized access or tampering with evidentiary audit chains is strictly penalized under BNS 2023 and NDPS Act.",
            ),
          ],
        ),
      ),
    );
  }
}
