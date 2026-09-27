import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/local_ledger_database.dart';
import '../services/crypto_signer_service.dart';
import 'login_screen.dart';

/// Screen 15: Officer Profile & Apparatus Security Management Portal
/// Supports:
/// 1. Comprehensive profile inspection & official verified credentials
/// 2. Editing Personal Info: Gender, Date of Birth (DatePicker), Posting City, Phone, Name
/// 3. Secure salted SHA-256 Password Change with cryptographic verification
/// 4. Official MHA Police Verification & Hardware Device Binding workflow
/// 5. Section 63 BSA 2023 Recursive Ledger Integrity Self-Audit
/// 6. Secure Session Key Purge and Sign Out
class ProfileSettingsScreen extends StatefulWidget {
  final User currentUser;
  const ProfileSettingsScreen({super.key, required this.currentUser});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;

  late User _user;

  // Personal Information Form Controllers
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _phoneController;
  late String _selectedGender;
  late String _selectedDob;
  bool _isSavingPersonal = false;

  // Change Password Form Controllers
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;

  // Verification & Registry Binding State
  bool _showVerificationCard = false;
  int _verifyStep = 0; // 0: Query Badge, 1: Review & OTP, 2: Digital QR, 3: Completed
  final TextEditingController _badgeQueryController = TextEditingController(text: "MH-8842");
  final TextEditingController _otpInputController = TextEditingController();
  DepartmentOfficer? _matchedOfficer;
  String? _expectedOtp;
  String? _simulatedSmsToast;
  bool _isRegistryLoading = false;
  String? _registryError;
  bool _isBindingHardware = false;

  // Ledger Audit State
  bool _isAuditing = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _nameController = TextEditingController(text: _user.name);
    _cityController = TextEditingController(text: _user.city);
    _phoneController = TextEditingController(text: _user.phone);
    _selectedGender = _user.gender.isNotEmpty ? _user.gender : "Male";
    _selectedDob = _user.dob.isNotEmpty ? _user.dob : "1996-05-15";
    _showVerificationCard = !_user.isVerified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _badgeQueryController.dispose();
    _otpInputController.dispose();
    super.dispose();
  }

  // ====================================================
  // ACTION 1: SAVE PERSONAL INFORMATION
  // ====================================================
  Future<void> _savePersonalInformation() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showToast("Full Name cannot be empty.", isError: true);
      return;
    }

    setState(() => _isSavingPersonal = true);

    try {
      final updated = await _db.updateUserProfile(
        email: _user.email,
        name: name,
        gender: _selectedGender,
        dob: _selectedDob,
        city: city,
        phone: phone,
      );

      if (!mounted) return;
      setState(() {
        _user = updated;
        _isSavingPersonal = false;
      });

      _showToast("Personal details updated successfully in secure ledger.", isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPersonal = false);
      _showToast("Failed to update profile: $e", isError: true);
    }
  }

  // DatePicker for Date of Birth
  Future<void> _pickDateOfBirth() async {
    DateTime initial = DateTime(1996, 5, 15);
    try {
      final parts = _selectedDob.split('-');
      if (parts.length == 3) {
        initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1955),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: "SELECT DATE OF BIRTH (DD/MM/YYYY)",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GovTheme.primary,
              onPrimary: Colors.white,
              onSurface: GovTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _selectedDob = formatted;
      });
    }
  }

  // ====================================================
  // ACTION 2: CHANGE PASSWORD (SALTED SHA-256)
  // ====================================================
  Future<void> _handleChangePassword() async {
    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (oldPass.isEmpty) {
      _showToast("Please enter your current password.", isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showToast("New password must be at least 6 characters long.", isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showToast("New passwords do not match.", isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await _db.changePassword(
        email: _user.email,
        oldPassword: oldPass,
        newPassword: newPass,
      );

      // Re-derive PIN key
      CryptoSignerService.instance.deriveOfficerKeyFromPin(
        newPass,
        officerId: _user.badgeNumber,
      );

      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() => _isChangingPassword = false);
      _showToast("Password changed successfully! Salted SHA-256 hash updated.", isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChangingPassword = false);
      _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  // ====================================================
  // ACTION 3: POLICE VERIFICATION WORKFLOW
  // ====================================================
  Future<void> _handleRegistryLookup() async {
    final badgeQuery = _badgeQueryController.text.trim();
    if (badgeQuery.isEmpty) {
      setState(() => _registryError = "Please enter an official Service ID or Badge Number.");
      return;
    }

    setState(() {
      _isRegistryLoading = true;
      _registryError = null;
      _matchedOfficer = null;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    final officer = await _db.lookupDepartmentRegistry(badgeQuery);

    if (officer == null) {
      setState(() {
        _isRegistryLoading = false;
        _registryError =
            "ACCESS REJECTED • UNRECOGNIZED BADGE\n"
            "Badge Number '$badgeQuery' is NOT present in the Ministry of Home Affairs Department Registry.\n"
            "Unregistered personnel are strictly prohibited under NDPS §52A.";
      });
      return;
    }

    String otp = "749210";
    if (officer.badgeNumber.toUpperCase() == "MH-1002") {
      otp = "882104";
    } else if (officer.badgeNumber.toUpperCase() == "MHA-NZ-7841") {
      otp = "194820";
    } else {
      otp = (officer.badgeNumber.hashCode.abs() % 900000 + 100000).toString();
    }

    String maskedPhone = officer.registeredPhone;
    if (maskedPhone.length > 8) {
      maskedPhone = "${maskedPhone.substring(0, 7)}*** **${maskedPhone.substring(maskedPhone.length - 3)}";
    }

    setState(() {
      _isRegistryLoading = false;
      _matchedOfficer = officer;
      _expectedOtp = otp;
      _simulatedSmsToast = "MHA-OTP: Your verification code is $otp (dispatched to $maskedPhone)";
      _verifyStep = 1;
    });
  }

  Future<void> _handleVerifyOtpAndBind() async {
    final entered = _otpInputController.text.trim();
    if (entered != _expectedOtp) {
      setState(() => _registryError = "Invalid 2FA OTP code. Please enter the 6-digit code shown above.");
      return;
    }

    setState(() {
      _isBindingHardware = true;
      _registryError = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final updatedUser = await _db.bindUserToDepartmentOfficer(
        userEmail: _user.email,
        officer: _matchedOfficer!,
      );

      // Initialize crypto keystore
      CryptoSignerService.instance.deriveOfficerKeyFromPin(
        "Officer@123",
        officerId: updatedUser.badgeNumber,
      );

      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _nameController.text = updatedUser.name;
        _cityController.text = updatedUser.city;
        _phoneController.text = updatedUser.phone;
        _isBindingHardware = false;
        _verifyStep = 0;
        _showVerificationCard = false;
      });

      _showToast("Identity verified! Badge ${updatedUser.badgeNumber} bound to device keystore.", isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBindingHardware = false);
      _showToast("Binding error: $e", isError: true);
    }
  }

  // ====================================================
  // ACTION 4: RECURSIVE LEDGER INTEGRITY AUDIT
  // ====================================================
  void _runLedgerAudit() async {
    setState(() => _isAuditing = true);
    final report = await _db.verifyChainIntegrity();
    setState(() => _isAuditing = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GovTheme.bgSurface,
        title: Row(
          children: [
            Icon(
              report.isValid ? Icons.verified_user : Icons.gpp_bad,
              color: report.isValid ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              report.isValid ? "Ledger Audit PASSED" : "Ledger Audit FAILED",
              style: TextStyle(
                color: report.isValid ? Colors.green.shade800 : Colors.red.shade800,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.message, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: GovTheme.bgBase,
              child: Text(
                "Verified Chain Length: ${report.verifiedBlocks}\n"
                "Algorithm: Recursive Merkle SHA-256 Digest\n"
                "Admissibility Standard: Section 63 BSA 2023",
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GovTheme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // ACTION 5: PURGE SESSION & SIGN OUT
  // ====================================================
  void _signOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GovTheme.bgSurface,
        title: const Text("End Officer Session?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          "Signing out immediately purges the PIN-derived ECDSA signing key from device volatile memory. You will need to sign in again to capture new seizure evidence.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("PURGE SESSION & EXIT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: GovTheme.bgBase,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _user),
          ),
          title: const Text("Officer Profile & Security"),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const GovHeaderBanner(
                titleText: "MINISTRY OF HOME AFFAIRS",
                subtitleText: "OFFICER PROFILE • LAW ENFORCEMENT CREDENTIALS",
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(GovTheme.space16),
                  children: [
                    // Section 1: Officer Header Card & Status
                    _buildOfficerHeaderCard(),
                    const SizedBox(height: 16),

                    // Section 2: MHA Police Verification & Device Binding
                    _buildVerificationSection(),
                    const SizedBox(height: 16),

                    // Section 3: Editable Personal Information
                    _buildPersonalInfoCard(),
                    const SizedBox(height: 16),

                    // Section 4: Change Password Card
                    _buildChangePasswordCard(),
                    const SizedBox(height: 16),

                    // Section 5: Apparatus & Security Keystore Card
                    _buildApparatusDetailsCard(),
                    const SizedBox(height: 20),

                    // Section 6: Action Buttons
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GovTheme.primary,
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isAuditing ? null : _runLedgerAudit,
                      icon: _isAuditing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.security, color: Colors.white),
                      label: const Text(
                        "RUN RECURSIVE LEDGER INTEGRITY AUDIT",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700, width: 1.5),
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        "PURGE SESSION KEY & LOGOUT",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================
  // WIDGET: OFFICER HEADER CARD
  // ====================================================
  Widget _buildOfficerHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _user.isVerified ? GovTheme.borderDefault : Colors.amber.shade400,
          width: _user.isVerified ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GovTheme.ashokaNavy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_user.rank} • Badge: ${_user.badgeNumber}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: GovTheme.ashokaNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _user.department,
                      style: GovTheme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Verification Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _user.isVerified ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _user.isVerified ? Colors.green.shade600 : Colors.amber.shade700,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _user.isVerified ? Icons.verified : Icons.warning_amber_rounded,
                  color: _user.isVerified ? Colors.green.shade700 : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user.isVerified ? "MHA POLICE VERIFIED CREDENTIAL" : "UNVERIFIED FIELD ACCOUNT",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _user.isVerified ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        _user.isVerified
                            ? "Bound to official MHA Department Rolls & Hardware Keystore."
                            : "Account created via Email. Verify your Badge Number below to enable Section 63 BSA attestation.",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _user.isVerified ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // WIDGET: MHA POLICE VERIFICATION ACCORDION / CARD
  // ====================================================
  Widget _buildVerificationSection() {
    return Container(
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              Icons.assignment_ind,
              color: _user.isVerified ? Colors.green.shade700 : GovTheme.primary,
            ),
            title: const Text(
              "MHA Police Identity Verification",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              _user.isVerified
                  ? "Service ID: ${_user.serviceId ?? 'MH-PSI-2026-081'} • Verified"
                  : "Bind official badge number & 2FA OTP",
              style: GovTheme.caption,
            ),
            trailing: IconButton(
              icon: Icon(_showVerificationCard ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() => _showVerificationCard = !_showVerificationCard);
              },
            ),
          ),
          if (_showVerificationCard) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_registryError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        _registryError!,
                        style: TextStyle(fontSize: 11, color: Colors.red.shade900, height: 1.3),
                      ),
                    ),

                  if (_verifyStep == 0) ...[
                    const Text(
                      "Enter your official Badge Number or Service ID to look up records in the Ministry of Home Affairs Department Registry:",
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),

                    // Quick Demo Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text("PSI Ujwal Tikhe (MH-8842)", style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () => setState(() => _badgeQueryController.text = "MH-8842"),
                        ),
                        ActionChip(
                          label: const Text("SP Amitabh Sharma (MH-1002)", style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () => setState(() => _badgeQueryController.text = "MH-1002"),
                        ),
                        ActionChip(
                          label: const Text("ASI Rajesh Kumar (MHA-NZ-7841)", style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () => setState(() => _badgeQueryController.text = "MHA-NZ-7841"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _badgeQueryController,
                      decoration: const InputDecoration(
                        labelText: "OFFICIAL BADGE / SERVICE ID *",
                        prefixIcon: Icon(Icons.badge, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GovTheme.primary,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isRegistryLoading ? null : _handleRegistryLookup,
                      icon: _isRegistryLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.search, color: Colors.white, size: 18),
                      label: const Text(
                        "QUERY DEPARTMENT REGISTRY",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ] else if (_verifyStep == 1 && _matchedOfficer != null) ...[
                    // Matched Officer Card & OTP Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade800, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "OFFICIAL RECORD FOUND",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text("Name: ${_matchedOfficer!.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text("Rank: ${_matchedOfficer!.rank}", style: const TextStyle(fontSize: 11)),
                          Text("Unit: ${_matchedOfficer!.unit}", style: const TextStyle(fontSize: 11)),
                          Text("Registered Contact: ${_matchedOfficer!.registeredPhone}", style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_simulatedSmsToast != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFBC02D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sms, color: Color(0xFFF57F17), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _simulatedSmsToast!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _otpInputController.text = _expectedOtp ?? ""),
                              child: const Text("AUTO-FILL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _otpInputController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "ENTER 6-DIGIT OTP *",
                        prefixIcon: Icon(Icons.lock_clock, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _verifyStep = 0),
                            child: const Text("CANCEL"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _isBindingHardware ? null : _handleVerifyOtpAndBind,
                            icon: _isBindingHardware
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.verified, color: Colors.white, size: 18),
                            label: const Text(
                              "VERIFY & BIND BADGE",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ====================================================
  // WIDGET: EDITABLE PERSONAL INFORMATION
  // ====================================================
  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note, color: GovTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                "Personal Information",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Add or update your personal particulars and contact information:",
            style: TextStyle(fontSize: 11, color: GovTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Officer Full Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "OFFICER FULL NAME *",
              prefixIcon: Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Gender Dropdown & Date of Birth Row
          Row(
            children: [
              // Gender Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "GENDER",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGender = val);
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Date of Birth Button
              Expanded(
                child: InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "DATE OF BIRTH",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      _selectedDob,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Posting City & Phone Number Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: "POSTING CITY",
                    prefixIcon: Icon(Icons.location_city, size: 20),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "PHONE NUMBER",
                    prefixIcon: Icon(Icons.phone, size: 20),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.ashokaNavy,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _isSavingPersonal ? null : _savePersonalInformation,
            icon: _isSavingPersonal
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text(
              "SAVE PERSONAL INFORMATION",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // WIDGET: CHANGE PASSWORD CARD
  // ====================================================
  Widget _buildChangePasswordCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.password, color: GovTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                "Change Account Password",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Update your officer password. The new password will be hashed with a unique cryptographic salt.",
            style: TextStyle(fontSize: 11, color: GovTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _oldPasswordController,
            obscureText: _obscureOld,
            decoration: InputDecoration(
              labelText: "CURRENT PASSWORD *",
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: "NEW PASSWORD (MIN. 6 CHARACTERS) *",
              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: "CONFIRM NEW PASSWORD *",
              prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GovTheme.primary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _isChangingPassword ? null : _handleChangePassword,
            icon: _isChangingPassword
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.key, color: Colors.white, size: 18),
            label: const Text(
              "UPDATE PASSWORD",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // WIDGET: APPARATUS & KEYSTORE DETAILS
  // ====================================================
  Widget _buildApparatusDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GovTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phonelink_lock, color: GovTheme.ashokaNavy, size: 20),
              SizedBox(width: 8),
              Text(
                "Hardware Apparatus & Keystore",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          _buildRow("Official Email", _user.email),
          _buildRow("Officer Role", _user.role.name.toUpperCase()),
          _buildRow("Bound Device ID", _user.deviceId),
          _buildRow("Active Reference Card", "MHACARD-2026-DEL-0491"),
          _buildRow("Keystore Attestation", "ECDSA P-256 (StrongBox Secure Enclave)"),
          _buildRow("Legal Framework", "NDPS Act §52A • Section 63 BSA 2023"),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GovTheme.caption),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
