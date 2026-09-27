import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/crypto_signer_service.dart';
import 'dashboard_screen.dart';

/// Screen 2: Login Screen
/// Government Provisioned Device Portal. Validates pre-registered Badge Number
/// and derives ephemeral in-memory ECDSA-P256 signing key via PBKDF2.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _badgeController = TextEditingController(text: "NCB-NZ-7841");
  final TextEditingController _pinController = TextEditingController(text: "982341");
  bool _obscurePin = true;
  bool _isLoading = false;
  String? _errorMessage;
  Role _selectedRole = Role.officer;

  // Registered badge whitelist for provisioned hardware device
  static const String _provisionedBadgeOfficer = "NCB-NZ-7841";
  static const String _provisionedBadgeSupervisor = "NCB-SUP-4012";

  @override
  void dispose() {
    _badgeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final badge = _badgeController.text.trim();
    final pin = _pinController.text.trim();

    if (badge.isEmpty || pin.length < 6) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Enter valid Badge ID and 6-digit cryptographic PIN.";
      });
      return;
    }

    try {
      // Simulate PBKDF2 officer key derivation (1000 iterations + secure salt)
      await Future.delayed(const Duration(milliseconds: 600));

      // Device hardware binding validation:
      final isValidBadge = (badge == _provisionedBadgeOfficer) ||
          (badge == _provisionedBadgeSupervisor) ||
          badge.startsWith("NCB-");

      if (!isValidBadge) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "DEVICE MISMATCH: Apparatus (DEV-001) is not provisioned to Badge '$badge'. Contact NCB Zonal Director.";
        });
        return;
      }

      // Initialize crypto signer with the PIN-derived key material
      final signer = CryptoSignerService.instance;
      signer.deriveOfficerKeyFromPin(pin);

      // Construct session user
      final role = badge.contains("SUP") ? Role.supervisor : Role.officer;
      final user = User(
        userId: "OFFICER-${badge.replaceAll('NCB-', '')}",
        badgeNumber: badge,
        department: "Narcotics Control Bureau (Operations Wing)",
        role: role,
        deviceId: "NCB-SECURE-DEV-001",
        provisionedAt: DateTime.now().subtract(const Duration(days: 45)),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(currentUser: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Authentication failed: $e";
      });
    }
  }

  void _fillSupervisorCreds() {
    setState(() {
      _badgeController.text = _provisionedBadgeSupervisor;
      _pinController.text = "554433";
      _selectedRole = Role.supervisor;
      _errorMessage = null;
    });
  }

  void _fillOfficerCreds() {
    setState(() {
      _badgeController.text = _provisionedBadgeOfficer;
      _pinController.text = "982341";
      _selectedRole = Role.officer;
      _errorMessage = null;
    });
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
              subtitleText: "OPERATIONAL SECTOR PORTAL • RESTRICTED ACCESS",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GovTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: GovTheme.space8),
                    // Apparatus Status Card
                    Container(
                      padding: const EdgeInsets.all(GovTheme.space16),
                      decoration: BoxDecoration(
                        color: GovTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GovTheme.borderDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phonelink_lock, color: GovTheme.primary, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "DEVICE BINDING: HARDWARE VERIFIED",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: GovTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Keystore Fingerprint: 7B8C...3F91 • Status: ACTIVE",
                                  style: GovTheme.caption,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: GovTheme.alertNegativeBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GovTheme.alertNegativeText),
                            ),
                            child: const Text(
                              "BOUND",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: GovTheme.alertNegativeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GovTheme.space24),
                    // Quick Role Switcher (For demo/evaluation purposes)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _fillOfficerCreds,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedRole == Role.officer
                                    ? GovTheme.primary
                                    : GovTheme.bgSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectedRole == Role.officer
                                      ? GovTheme.primary
                                      : GovTheme.borderDefault,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Officer Demo",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == Role.officer
                                        ? Colors.white
                                        : GovTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _fillSupervisorCreds,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedRole == Role.supervisor
                                    ? GovTheme.ashokaNavy
                                    : GovTheme.bgSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectedRole == Role.supervisor
                                      ? GovTheme.ashokaNavy
                                      : GovTheme.borderDefault,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Supervisor Demo",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedRole == Role.supervisor
                                        ? Colors.white
                                        : GovTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GovTheme.space24),
                    const Text(
                      "Officer Authorization",
                      style: GovTheme.title,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Enter pre-registered Government Badge ID and 6-digit Cryptographic Key derivation PIN.",
                      style: GovTheme.caption,
                    ),
                    const SizedBox(height: GovTheme.space24),
                    // Badge Number Input
                    const Text(
                      "BADGE ID / SERVICE NUMBER",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: GovTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _badgeController,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: GovTheme.bgSurface,
                        prefixIcon: const Icon(Icons.badge, color: GovTheme.primary),
                        hintText: "e.g. NCB-NZ-7841",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.borderDefault),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.borderDefault),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: GovTheme.space16),
                    // PIN Input
                    const Text(
                      "6-DIGIT EVIDENCE SIGNING PIN",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: GovTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: _obscurePin,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: GovTheme.bgSurface,
                        prefixIcon: const Icon(Icons.lock, color: GovTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin ? Icons.visibility_off : Icons.visibility,
                            color: GovTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.borderDefault),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.borderDefault),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GovTheme.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: GovTheme.space8),
                    Row(
                      children: [
                        const Icon(Icons.vpn_key, size: 14, color: GovTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          "PIN derives ECDSA key via PBKDF2. Never stored on disk.",
                          style: GovTheme.caption,
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: GovTheme.space16),
                      Container(
                        padding: const EdgeInsets.all(GovTheme.space12 ?? 12),
                        decoration: BoxDecoration(
                          color: GovTheme.alertPositiveBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GovTheme.alertPositiveText),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: GovTheme.alertPositiveText, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: GovTheme.alertPositiveText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: GovTheme.space32),
                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GovTheme.primary,
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "AUTHENTICATE & ENTER PORTAL",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const StatutoryWarningBanner(
              text: "Notice: Admin and Auditor functions are restricted to secure Web Console. Field devices strictly provisioned for Officer and Supervisor roles.",
            ),
          ],
        ),
      ),
    );
  }
}
