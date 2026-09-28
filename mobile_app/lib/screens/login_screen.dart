import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../services/local_ledger_database.dart';
import '../services/crypto_signer_service.dart';
import 'dashboard_screen.dart';

/// Screen 2: Ministry of Home Affairs Authentication & Officer Onboarding Portal
/// Features:
/// 1. Tab 0: Officer Sign In with Email & Password (plus quick demo chips for SIH judges)
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

  // Sign Up Controllers (Strictly Email & Password only)
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();
  final TextEditingController _signUpConfirmPasswordController = TextEditingController();
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signUpEmailController.dispose();
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
              "Invalid email or password. Passwords are cryptographic hashes stored in SQLite.";
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
  // SIGN UP HANDLER (EMAIL & PASSWORD ONLY)
  // ====================================================
  Future<void> _handleSignUp() async {
    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;
    final confirmPassword = _signUpConfirmPasswordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter your official email address.");
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = "Please enter a valid email address (e.g., officer@mha.gov.in).");
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
      final newUser = await _db.registerUserWithEmail(
        email: email,
        password: password,
        name: null,
      );

      // Initialize crypto key
      CryptoSignerService.instance.deriveOfficerKeyFromPin(
        password,
        officerId: newUser.badgeNumber,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = "Account registered! Welcome, ${newUser.name}. Entering dashboard...";
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Officer Sign In",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            "Enter your registered email and password to enter the operational dashboard.",
            style: TextStyle(fontSize: 11.5, color: GovTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Quick Demo Credentials Chips
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SIH EVALUATION QUICK-FILL DEMO ACCOUNTS:",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text("PSI Ujwal Tikhe", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.white,
                      onPressed: () {
                        setState(() {
                          _loginEmailController.text = "ujwal.tikhe@mha.gov.in";
                          _loginPasswordController.text = "Officer@123";
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text("SP Amitabh Sharma", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.white,
                      onPressed: () {
                        setState(() {
                          _loginEmailController.text = "supervisor@mha.gov.in";
                          _loginPasswordController.text = "Supervisor@123";
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Official Email
          TextField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "OFFICIAL EMAIL ADDRESS *",
              prefixIcon: Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Password
          TextField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            decoration: InputDecoration(
              labelText: "PASSWORD *",
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureLoginPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.primary,
              minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _isLoading ? null : _handleSignIn,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open, color: Colors.white),
            label: const Text(
              "SECURE OFFICER SIGN IN",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // FORM: SIGN UP WITH EMAIL & PASSWORD ONLY
  // ====================================================
  Widget _buildSignUpForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Officer Sign Up",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
          ),
          const SizedBox(height: 4),
          const Text(
            "Sign up with your official Email and Password only. You can add personal info (Name, Gender, Date of Birth) and complete MHA Badge Verification inside your Profile.",
            style: TextStyle(fontSize: 11.5, color: GovTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Official Email
          TextField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "OFFICIAL EMAIL ADDRESS *",
              hintText: "e.g., officer@mha.gov.in",
              prefixIcon: Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Password
          TextField(
            controller: _signUpPasswordController,
            obscureText: _obscureSignUpPassword,
            decoration: InputDecoration(
              labelText: "PASSWORD (MIN. 6 CHARACTERS) *",
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureSignUpPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TextField(
            controller: _signUpConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: "CONFIRM PASSWORD *",
              prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Explanatory Info Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF3FC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 18, color: GovTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Instant Setup: After signing up, tap the top-left of the Dashboard to view your Profile, add personal details (Gender, Date of Birth), and verify your MHA Badge Number.",
                    style: TextStyle(fontSize: 11, color: GovTheme.textPrimary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sign Up CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.ashokaNavy,
              minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _isLoading ? null : _handleSignUp,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1, color: Colors.white),
            label: const Text(
              "CREATE OFFICER ACCOUNT & PROCEED",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
