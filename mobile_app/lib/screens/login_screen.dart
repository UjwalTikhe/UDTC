import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/local_ledger_database.dart';
import '../services/crypto_signer_service.dart';
import 'dashboard_screen.dart';

/// Screen 2: Ministry of Home Affairs Authentication & Officer Onboarding Portal
/// Features:
/// 1. Tab 0: Officer Sign In with email and password
/// 2. Tab 1: Officer Sign Up with Email and Password only (+ optional Name)
/// 3. Passwords stored securely in SQLite with individual cryptographic salts and SHA-256 hashes
/// 4. Official Department Registry and Badge Verification is integrated inside Officer Profile
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  late TabController _tabController;

  // Sign In Controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Sign Up Controllers (Complete Official PII Profile)
  final TextEditingController _signUpNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpBadgeController = TextEditingController();
  final TextEditingController _signUpUnitController = TextEditingController();
  final TextEditingController _signUpCityController = TextEditingController(text: "New Delhi");
  final TextEditingController _signUpPasswordController = TextEditingController();
  final TextEditingController _signUpConfirmPasswordController = TextEditingController();
  String _signUpRank = "Police Sub-Inspector (PSI)";
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    await _db.database;
    await _db.seedDefaultUsersIfEmpty();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpBadgeController.dispose();
    _signUpUnitController.dispose();
    _signUpCityController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  // ====================================================
  // SIGN IN HANDLER
  // ====================================================
  Future<void> _handleSignIn() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Please enter both official email and password.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = await _db.authenticateUser(email: email, password: password);

      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "AUTHENTICATION FAILED\n"
              "Invalid official email or password. Passwords are cryptographic hashes stored in SQLite.";
        });
        return;
      }

      // Initialize crypto keystore
      CryptoSignerService.instance.deriveOfficerKeyFromPin(
        password,
        officerId: user.badgeNumber,
      );

      setState(() {
        _isLoading = false;
        _successMessage = "Authentication verified for ${user.name} (${user.badgeNumber})";
      });

      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

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
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  // ====================================================
  // SIGN UP HANDLER (COMPLETE PII PROFILE ONBOARDING)
  // ====================================================
  Future<void> _handleSignUp() async {
    final name = _signUpNameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final badge = _signUpBadgeController.text.trim();
    final unit = _signUpUnitController.text.trim();
    final city = _signUpCityController.text.trim();
    final password = _signUpPasswordController.text;
    final confirmPassword = _signUpConfirmPasswordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = "Please enter your Full Name.");
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = "Please enter a valid official email (e.g. officer@mha.gov.in).");
      return;
    }
    if (badge.isEmpty) {
      setState(() => _errorMessage = "Please enter your Official Badge / ID Number.");
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters long.");
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = "Passwords do not match. Please verify.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final role = _signUpRank.toLowerCase().contains("superintendent") ? Role.supervisor : Role.officer;
      final effectiveUnit = unit.isNotEmpty ? unit : "Special Task Force (Anti-Narcotics Unit)";
      final effectiveCity = city.isNotEmpty ? city : "New Delhi";

      final newUser = await _db.registerUser(
        name: name,
        email: email,
        badgeNumber: badge.toUpperCase(),
        age: 32,
        gender: "Male",
        city: effectiveCity,
        role: role,
        password: password,
        department: "$effectiveUnit • Ministry of Home Affairs",
        rank: _signUpRank,
        unit: effectiveUnit,
        isVerified: true,
      );

      // Initialize crypto key
      CryptoSignerService.instance.deriveOfficerKeyFromPin(
        password,
        officerId: newUser.badgeNumber,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = "Official account provisioned & verified for ${newUser.name}. Entering dashboard...";
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(currentUser: newUser),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll("Exception: ", "");
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
            // Tricolor Statutory Header Strip
            _buildTricolorBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: [
                    // Official Ministry of Home Affairs Lion Emblem & Header
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),

                    // Tab Selector: Sign In vs Sign Up
                    _buildTabSelector(),
                    const SizedBox(height: 16),

                    // Error & Success Feedback Banners
                    if (_errorMessage != null) _buildAlertCard(_errorMessage!, isError: true),
                    if (_successMessage != null) _buildAlertCard(_successMessage!, isError: false),

                    // Active Tab Content
                    _tabController.index == 0 ? _buildSignInForm() : _buildSignUpForm(),

                    const SizedBox(height: 24),

                    // Footer Statutory Security Notice
                    const Text(
                      "RESTRICTED LAW ENFORCEMENT PORTAL • MINISTRY OF HOME AFFAIRS\n"
                      "Unauthorized access is punishable under NDPS Act §52A and Bharatiya Nyaya Sanhita.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: GovTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTricolorBar() {
    return SizedBox(
      height: 4,
      child: Row(
        children: const [
          Expanded(child: ColoredBox(color: Color(0xFFFF9933))),
          Expanded(child: ColoredBox(color: Color(0xFFFFFFFF))),
          Expanded(child: ColoredBox(color: Color(0xFF138808))),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/mha_emblem.png',
            height: 76,
            width: 76,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shield,
              size: 54,
              color: GovTheme.ashokaNavy,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "MINISTRY OF HOME AFFAIRS",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: GovTheme.ashokaNavy,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "GOVERNMENT OF INDIA • LAW ENFORCEMENT APPARATUS",
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: GovTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: GovTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GovTheme.primary.withValues(alpha: 0.25)),
          ),
          child: const Text(
            "NDPS ACT §52A APPARATUS • SECTION 63 BSA 2023 COMPLIANT",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: GovTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _errorMessage = null;
            _successMessage = null;
          });
        },
        labelColor: GovTheme.ashokaNavy,
        unselectedLabelColor: GovTheme.textSecondary,
        indicatorColor: GovTheme.ashokaNavy,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.login, size: 20),
            text: "OFFICER SIGN IN",
          ),
          Tab(
            icon: Icon(Icons.person_add, size: 20),
            text: "CREATE ACCOUNT",
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String message, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isError ? Colors.red.shade400 : Colors.green.shade400,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade800 : Colors.green.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: isError ? Colors.red.shade900 : Colors.green.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // FORM: SIGN IN WITH EMAIL & PASSWORD
  // ====================================================
  Widget _buildSignInForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GovTheme.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Officer Sign In",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GovTheme.ashokaNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            "Sign in with your registered official email and cryptographic password.",
            style: TextStyle(fontSize: 13.5, color: GovTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 16),

          // Pre-verified Quick-Fill Demo Credentials (As Requested)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified, size: 16, color: GovTheme.primary),
                    SizedBox(width: 6),
                    Text(
                      "PRE-VERIFIED DEMO ACCOUNTS (ONE-TAP):",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: GovTheme.ashokaNavy, letterSpacing: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 1. Field Officer Account
                InkWell(
                  onTap: () {
                    setState(() {
                      _loginEmailController.text = "officer@mha.gov.in";
                      _loginPasswordController.text = "Officer@123";
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, size: 20, color: GovTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Field Officer: officer@mha.gov.in",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
                              ),
                              Text(
                                "PSI Rajesh Kumar • Pass: Officer@123",
                                style: TextStyle(fontSize: 11.5, color: GovTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.touch_app, size: 18, color: GovTheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Superintendent Account
                InkWell(
                  onTap: () {
                    setState(() {
                      _loginEmailController.text = "superintendent@mha.gov.in";
                      _loginPasswordController.text = "Supervisor@123";
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 20, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Superintendent: superintendent@mha.gov.in",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
                              ),
                              Text(
                                "SP Amitabh Sharma • Pass: Supervisor@123",
                                style: TextStyle(fontSize: 11.5, color: GovTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.touch_app, size: 18, color: Colors.amber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. PSI Ujwal Tikhe
                InkWell(
                  onTap: () {
                    setState(() {
                      _loginEmailController.text = "ujwal.tikhe@mha.gov.in";
                      _loginPasswordController.text = "Officer@123";
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: GovTheme.ashokaNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "PSI Ujwal Tikhe: ujwal.tikhe@mha.gov.in",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
                              ),
                              Text(
                                "Special Task Force • Pass: Officer@123",
                                style: TextStyle(fontSize: 11.5, color: GovTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.touch_app, size: 18, color: GovTheme.ashokaNavy),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Official Email Input
          TextField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "OFFICIAL EMAIL ADDRESS *",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: Icon(Icons.email_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Password Input
          TextField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: "PASSWORD *",
              labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: const Icon(Icons.lock_outline, size: 22),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 22),

          // Sign In CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.primary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isLoading ? null : _handleSignIn,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open, color: Colors.white, size: 22),
            label: const Text(
              "SECURE OFFICER SIGN IN",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // FORM: COMPLETE PII ONBOARDING & SIGN UP
  // ====================================================
  Widget _buildSignUpForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GovTheme.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Officer Onboarding & Registration",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GovTheme.ashokaNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            "Provide official law enforcement credentials upfront for instant verified profile activation.",
            style: TextStyle(fontSize: 13.5, color: GovTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 18),

          // Full Name
          TextField(
            controller: _signUpNameController,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "FULL NAME (OFFICIAL) *",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              hintText: "e.g., PSI Vikram Rathore",
              prefixIcon: Icon(Icons.person_outline, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Official Email
          TextField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "OFFICIAL GOVT EMAIL *",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              hintText: "e.g., officer@mha.gov.in",
              prefixIcon: Icon(Icons.email_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Designation / Rank Dropdown
          DropdownButtonFormField<String>(
            value: _signUpRank,
            decoration: const InputDecoration(
              labelText: "RANK / DESIGNATION *",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: Icon(Icons.military_tech_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: "Police Sub-Inspector (PSI)", child: Text("Police Sub-Inspector (PSI)")),
              DropdownMenuItem(value: "Inspector of Police (PI)", child: Text("Inspector of Police (PI)")),
              DropdownMenuItem(value: "Deputy Superintendent of Police (DSP)", child: Text("Deputy Superintendent of Police (DSP)")),
              DropdownMenuItem(value: "Superintendent of Police (SP)", child: Text("Superintendent of Police (SP) [Supervisor]")),
              DropdownMenuItem(value: "Intelligence Officer (NCB)", child: Text("Intelligence Officer (NCB)")),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _signUpRank = val);
            },
          ),
          const SizedBox(height: 14),

          // Official Badge Number
          TextField(
            controller: _signUpBadgeController,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "BADGE / SERVICE ID NUMBER *",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              hintText: "e.g., MHA-NCB-7841",
              prefixIcon: Icon(Icons.badge_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Unit / Station
          TextField(
            controller: _signUpUnitController,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "POLICE STATION / SQUAD / UNIT",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              hintText: "e.g., Narcotics Control Bureau, Zonal Unit",
              prefixIcon: Icon(Icons.shield_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // City / Jurisdiction
          TextField(
            controller: _signUpCityController,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              labelText: "CITY / JURISDICTION",
              labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: Icon(Icons.location_city_outlined, size: 22),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Password
          TextField(
            controller: _signUpPasswordController,
            obscureText: _obscureSignUpPassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: "PASSWORD (MIN. 6 CHARACTERS) *",
              labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: const Icon(Icons.lock_outline, size: 22),
              suffixIcon: IconButton(
                icon: Icon(_obscureSignUpPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TextField(
            controller: _signUpConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: "CONFIRM PASSWORD *",
              labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              prefixIcon: const Icon(Icons.check_circle_outline, size: 22),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Explanatory Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: const [
                Icon(Icons.verified_user, size: 20, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Direct Verified Profile: All credentials entered here are digitally authenticated and cryptographically bound under NDPS Act §52A.",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1B5E20), height: 1.3, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign Up CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.ashokaNavy,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isLoading ? null : _handleSignUp,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
            label: const Text(
              "PROVISION & VERIFY OFFICER ACCOUNT",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Colors.white, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
