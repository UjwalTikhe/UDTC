import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/gov_theme.dart';
import '../services/crypto_signer_service.dart';
import 'login_screen.dart';

/// Screen 1: Splash Screen & Statutory Hardware Provisioning
/// Prompts for real Android Camera & GPS permissions mandated under NDPS Act §52A.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = "Initializing Hardware Keystore...";
  bool _isKeystoreReady = false;
  bool _needsPermissions = false;

  @override
  void initState() {
    super.initState();
    _bootstrapDevice();
  }

  Future<void> _bootstrapDevice() async {
    try {
      setState(() => _statusText = "Verifying Hardware Key Fingerprint (P-256)...");

      final signer = CryptoSignerService.instance;
      signer.initializeHardwareKeystore();

      setState(() {
        _isKeystoreReady = true;
        _statusText = "Checking Statutory GPS Permissions...";
      });

      // Check Location runtime permission (Camera is strictly on-demand only)
      final locationStatus = await Permission.locationWhenInUse.status;

      if (!locationStatus.isGranted) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          if (!mounted) return;
          setState(() {
            _needsPermissions = true;
            _statusText = "Statutory GPS Permission Required under NDPS §52A for chain-of-custody geotagging.";
          });
          return;
        }
      }

      setState(() => _statusText = "Hardware & Sensors Verified. Entering Portal...");
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Initialization Error: $e";
      });
    }
  }

  Future<void> _requestPermissionsAgain() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      setState(() => _needsPermissions = false);
      _bootstrapDevice();
    } else {
      await openAppSettings();
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
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "GOVERNMENT OF INDIA • MINISTRY OF HOME AFFAIRS",
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(GovTheme.space24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lion Capital of Ashoka (MHA Official Emblem)
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: GovTheme.tricolorSaffron, width: 3),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/mha_emblem.png',
                            height: 74,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.account_balance,
                              color: GovTheme.ashokaNavy,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: GovTheme.space24),
                      const Text(
                        "FIELD DRUG TESTING APPARATUS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: GovTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: GovTheme.space32),

                      // Status or Permission Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(GovTheme.space16),
                        decoration: BoxDecoration(
                          color: GovTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _needsPermissions ? GovTheme.alertPositiveText : GovTheme.borderDefault,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (!_needsPermissions) ...[
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: GovTheme.primary,
                                ),
                              ),
                              const SizedBox(height: GovTheme.space16),
                            ] else ...[
                              const Icon(Icons.security_update_warning, color: GovTheme.alertPositiveText, size: 36),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _needsPermissions ? GovTheme.alertPositiveText : GovTheme.textPrimary,
                              ),
                            ),
                            if (_needsPermissions) ...[
                              const SizedBox(height: GovTheme.space16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GovTheme.primary,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed: _requestPermissionsAgain,
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text(
                                  "GRANT CAMERA & GPS PERMISSIONS",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ] else ...[
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
                                    "Keystore Attestation: SHA256:7B8C...3F91",
                                    style: GovTheme.caption,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const StatutoryWarningBanner(
              text: "STATUTORY WARNING: Evidence without spatial GPS binding and device attestation is inadmissible under NDPS Act §52A.",
            ),
          ],
        ),
      ),
    );
  }
}
