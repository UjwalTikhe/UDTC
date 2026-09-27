import 'package:flutter/material.dart';
import '../models/domain_models.dart';
import 'profile_settings_screen.dart';

/// ProvisioningScreen now routes to ProfileSettingsScreen (Screen 15)
/// Administrative provisioning is strictly restricted to the Web Console.
class ProvisioningScreen extends StatelessWidget {
  const ProvisioningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSettingsScreen(
      currentUser: User(
        userId: "OFFICER-7841",
        badgeNumber: "MH-8842",
        department: "Ministry of Home Affairs (Operations)",
        role: Role.officer,
        deviceId: "MHA-SECURE-DEV-001",
        provisionedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );
  }
}
