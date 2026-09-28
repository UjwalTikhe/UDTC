# SIH26231 — App Design System & Build Prompts
## Digital Companion for Field Drug Testing (NCB / NDPS Act §52A / BSA 2023 §63)
### Architectural Specification & Screen-by-Screen AI Code-Builder Prompts

---

## 1. Architectural Roles & Security Boundaries

### Does Admin Belong in the Mobile App? — NO, Deliberately.
- **Officer (Field Role)**: Needs the app constantly, offline-first, fast, and minimal. Focuses on field drug sampling, kinetic reaction timing, optical colorimetry, and initial dual-signing.
- **Supervisor (Field-Adjacent Role)**: Occasionally needs to co-sign high-stakes/commercial quantity seizures or authorize court exports while mobile. A **thin-slice** of supervisory capability belongs in the mobile app.
- **Auditor (Desk Review Role)**: Reviews chain integrity, searches historical records, inspects audit-of-audit logs, and prepares judicial certificates. **Web-Console only.**
- **Admin (Back-Office Administration)**: Device provisioning, officer roster management, hardware Keystore binding, reference-card issuance, and optical threshold recalibration. This happens at a desk on a physical keyboard. Putting administrative capabilities on a mobile device that could be seized, lost, or stolen in the field increases the attack surface unnecessarily. **Web-Console only.**

---

## 2. OOP Domain Model

Flat composition domain models with sound null safety:

```dart
enum Role { officer, supervisor, auditor, admin }

class User {
  final String userId;
  final String badgeNumber;
  final String department;
  final Role role;
  final String deviceId;          // Bound hardware apparatus
  final DateTime provisionedAt;
}

class Device {
  final String deviceId;
  final String hardwareKeyFingerprint;   // from Keystore/Secure Enclave (P-256)
  final String? assignedUserId;
  final DeviceStatus status;             // active | revoked | lost
}

enum DeviceStatus { active, revoked, lost }

class ReferenceCard {
  final String serial;
  final String qrPayload;                // Format: "NCBCARD-YYYY-ZON-XXXX"
  final String? issuedToOfficerId;
  final CardStatus status;               // active | retired | reported_lost
}

enum CardStatus { active, retired, reported_lost }

enum KitType { nddk, pcdk, kdk }

class TestSession {
  final String sessionId;
  final KitType kitType;                 // NDDK | PCDK | KDK
  final DateTime reactionStartedAt;
  final List<CapturedFrame> burstFrames; // 4-burst frames
  final CalibrationResult? calibration;
}

class CalibrationResult {
  final double deltaE;
  final double confidence;
  final bool cardDetected;
  final bool withinReactionWindow;
  final bool qualityPassed;
}

enum ResultCategory { positive, negative, inconclusive }

class ClassificationResult {
  final ResultCategory category;         // positive | negative | inconclusive
  final double confidence;
  final List<String> interferentWarnings; // e.g. Levamisole, Phenacetin, Lidocaine
}

class TestRecord {
  final String testId;
  final String prevHash;                 // H_{n-1}
  final String recordHash;               // H_n = SHA256(CanonicalData_n + PrevHash)
  final User officer;
  final Device device;
  final ReferenceCard card;
  final TestSession session;
  final ClassificationResult result;
  final GeoPoint? location;
  final bool locationConfirmed;          // Fail-closed trust flag
  final DateTime timestamp;
  final Signature deviceSignature;       // ECDSA P-256 (Keystore)
  final Signature officerSignature;      // ECDSA P-256 (PIN-derived PBKDF2)
  final SyncStatus syncStatus;
}

class Signature {
  final String signerId;
  final String algorithm;                // ECDSA-P256
  final String signatureBytes;
  final DateTime signedAt;
}

enum SyncStatus { pending, smsWitnessed, stagedSynced, fullyAnchored }

class AuditLogEntry {
  final String logId;
  final String prevLogHash;
  final String actorId;
  final AuditAction action;              // view | export | search | co-sign
  final String? targetTestId;
  final DateTime timestamp;
}

enum AuditAction { view, export, search, sign }
```

---

## 3. Official Indian Government Design System (GIGW 3.0 / WCAG 2.1 AA)

### 3.1 Color Palette
Compliant with GIGW 3.0 and WCAG 2.1 Level AA (minimum 4.5:1 text contrast):

| Token | Hex | Role / Use | Contrast Ratio |
|---|---|---|---|
| `bg.base` | `#F7F9FC` | App Background (Light, cool, authoritative) | 15.65:1 against text |
| `bg.surface` | `#FFFFFF` | Cards, Elevated Surfaces, Sheets | High elevation |
| `text.primary` | `#1A1F29` | Headings, Primary Labels, Form Text | 15.65:1 on base |
| `text.secondary` | `#5B6472` | Secondary Meta, Timestamps, Hash Fragments | ~4.6:1 on base |
| `border.default` | `#E1E5EB` | Dividers, Borders, Form Outlines | Structural framing |
| `primary` | `#1E4B8F` | Indian Govt Emblem Navy (Buttons, Active Nav) | **8.55:1** on white |
| `ashokaNavy` | `#0A2558` | Top Bar, National Insignia Headers | Sovereign Identity |
| `tricolorSaffron` | `#FF9933` | Sovereign Header Accent Stripe | National Identity |
| `tricolorGreen` | `#138808` | Sovereign Header Accent Stripe | National Identity |

### 3.2 Status Colors — Forensic Non-Traffic-Light Rule
In law enforcement drug testing, "Positive" means *contraband detected* (an alert situation, never a "good" green outcome):

| Result | Background Tint | Text / Icon Color | Meaning |
|---|---|---|---|
| **Positive** (Contraband Alert) | `#FDECEA` | `#B3261E` | Contraband Detected (High-contrast Alert) |
| **Negative** (Clear) | `#E8F5E9` | `#1B6E2F` | No Contraband Detected (Clear) |
| **Inconclusive** (Retest) | `#FFF4E0` | `#9E5B00` | Borderline / Retest / Lab Mandated |

**Strict Rule**: Never convey status by color alone. Every badge and chip pairs **Color Tint + Icon (✓ / ✕ / !) + Text Label**.

### 3.3 Typography Scale (Major Third 1.25 Ratio)
- `display`: 28sp (Weight: 800) — Major Forensic Decision Banner
- `title`: 22sp (Weight: 700) — Screen Headlines
- `subtitle`: 18sp (Weight: 600) — Section Sub-headers
- `body`: 16sp (Weight: 400) — Form Text & Descriptions
- `caption`: 13sp (Weight: 500) — Metadata, GPS, Hashes
- `codeHash`: 11sp (Monospace, Weight: 600) — SHA-256 Hashes & Signatures

### 3.4 8dp Grid Spacing & Touch Targets
- All spacing uses 8dp increments: **4, 8, 16, 24, 32, 40, 48dp**.
- Minimum interactive touch target: **48×48dp** (prevents mis-taps with gloved or one-handed field operation).
- Primary CTA buttons: Full width minus margins (`width - 32dp`), height **56dp**.
- Capture shutter button: **72dp diameter**, circular, centered, with 32dp clearance above bottom safe area.

### 3.5 Persistent Statutory Warnings
Under NDPS Act §52A & BSA 2023 §63, every test screen structurally incorporates:
- **Top Header**: "GOVERNMENT OF INDIA • NARCOTICS CONTROL BUREAU" with sovereign tricolor bar.
- **Non-Dismissible Statutory Banner**: *"Presumptive field result only — mandatory laboratory confirmation required under NDPS Act §52A & BSA 2023 §63."*

---

## 4. Complete Screen Inventory (15 Screens)

| # | Screen Name | Class / File | Role | Core Purpose |
|---|---|---|---|---|
| 1 | Splash | `SplashScreen` (`splash_screen.dart`) | All | Hardware Keystore attestation, provisioning status |
| 2 | Login | `LoginScreen` (`login_screen.dart`) | All | Badge ID + PIN, PBKDF2 key derivation, device binding |
| 3 | Home / Dashboard | `DashboardScreen` (`dashboard_screen.dart`) | Officer, Supervisor | NCB header, credentials, quick test CTA, recent tests |
| 4 | Kit Selection | `KitSelectionScreen` (`kit_selection_screen.dart`) | Officer | Select NDDK, PCDK, or KDK with chemical parameters |
| 5 | Card QR Scan | `CardScanScreen` (`card_scan_screen.dart`) | Officer | QR scan validating `NCBCARD-` serial + 3-frame debounce |
| 6 | Reaction Timer | `ReactionTimerScreen` (`reaction_timer_screen.dart`) | Officer | Chemical kinetic stabilization countdown |
| 7 | Capture Screen | `CameraCaptureScreen` (`camera_capture_screen.dart`) | Officer | ArUco reticle, blur/exposure gating, 72dp shutter, burst |
| 8 | Processing Screen | `ProcessingScreen` (`processing_screen.dart`) | Officer | CIE Lab ΔE2000 isolate computation, interferent lookup |
| 9 | Result Screen | `ResultScreen` (`result_screen.dart`) | Officer | High-contrast badge, confidence, interferents, retake |
| 10 | Record Confirm | `RecordConfirmScreen` (`record_confirm_screen.dart`) | Officer | FIR details, dual-signing (P-256 + PBKDF2), chain append |
| 11 | Test History | `HistoryScreen` (`history_screen.dart`) | Officer, Supervisor | Searchable ledger, tamper-evident verification |
| 12 | Record Detail | `RecordDetailScreen` (`record_detail_screen.dart`) | Officer, Supervisor | Evidentiary view, optical metrics, BSA §63 export |
| 13 | Sync Status | `SyncStatusScreen` (`sync_status_screen.dart`) | All | 3-tier offline mesh queue, 2G SMS witness outbox |
| 14 | Approval Queue | `ApprovalQueueScreen` (`approval_queue_screen.dart`) | Supervisor | High-stakes commercial seizure co-signing |
| 15 | Profile / Settings | `ProfileSettingsScreen` (`profile_settings_screen.dart`) | All | Officer badge, device fingerprint, ledger audit, sign out |

---

## 5. Detailed Screen-by-Screen Build Prompts

### Prompt 1: Splash Screen (`SplashScreen`)
```
Build a Flutter screen called SplashScreen that serves as the official Government apparatus
boot sequence for the Narcotics Control Bureau.
Design Requirements:
- Compliant with GIGW 3.0 / WCAG 2.1 AA.
- Header: GovHeaderBanner with Ashoka Navy background, emblem seal, and sovereign tricolor accent line.
- Center: Official gold-accented police shield badge, bold apparatus title, statutory subtext:
  "Digital Evidence Companion (SIH26231) • NDPS Act §52A • Bharatiya Sakshya Adhiniyam §63".
- Hardware attestation card: Asynchronously verifies Android Keystore StrongBox ECDSA P-256
  hardware key fingerprint and salt material without blocking UI.
- Footer: Statutory banner notifying that unauthorized access or tampering with chain ledgers
  is penalized under BNS 2023 and NDPS Act.
- Transitions automatically to LoginScreen upon successful verification.
```

### Prompt 2: Login / Authentication Screen (`LoginScreen`)
```
Build a Flutter screen called LoginScreen for a government-provisioned device app.
There is NO self-service sign up.
Requirements:
- Input 1: Badge Number (pre-registered by Admin via web console, e.g. "NCB-NZ-7841").
- Input 2: 6-digit cryptographic PIN with visibility toggle and minimum 48x48dp hit area.
- Hardware Binding Validation: Checks device hardware key fingerprint against provisioning
  record. If mismatched, show clear error: "DEVICE MISMATCH: Apparatus is not provisioned
  to Badge. Contact NCB Zonal Director."
- Ephemeral Key Derivation: On submit, derive the officer's ECDSA signing key from the PIN
  via PBKDF2 with a secure salt. Hold the key in memory ONLY for the session; never persist
  to disk or transmit raw PIN over the network.
- Include demo quick-fill buttons for "Officer Demo" and "Supervisor Demo" roles.
- 56dp height primary CTA: "AUTHENTICATE & ENTER PORTAL".
```

### Prompt 3: Home / Dashboard Screen (`DashboardScreen`)
```
Build a Flutter screen called DashboardScreen adhering to the official NCB design system.
Requirements:
- Top AppBar: Ashoka Navy with shield icon, title "NCB Field Companion", badge number,
  and profile action button.
- Header Banner: Sovereign tricolor accent with "OPERATIONAL FIELD HEADQUARTERS".
- Section 1: Officer credentials card showing badge number, unit division, bound apparatus
  ID, and green "ACTIVE" status chip.
- Section 2: Prominent 56dp CTA button: "START NEW FIELD TEST" with camera icon.
- Section 3: Operational stats row displaying Total Tests, Contraband Positive count (alert tint),
  and Pending Sync count.
- Section 4: SHA-256 Ledger Health Card displaying total verified blocks and head hash preview.
- Section 5: Navigation grid cards for "Seizure History", "Sync Mesh", and "Supervisor Approvals"
  (if current user is Supervisor).
- Section 6: Recent Field Records list with GovResultBadge (Color + Icon + Text Label).
```

### Prompt 4: Kit Selection Screen (`KitSelectionScreen`)
```
Build a Flutter screen called KitSelectionScreen for selecting the authorized field testing assay.
Requirements:
- Option 1: NDDK (Marquis Reagent - Formaldehyde/Sulfuric Acid) for Opium, Morphine, Heroin.
  Reaction window: 45 seconds. Color shift: Deep Purple/Violet.
- Option 2: PCDK (Duquenois-Levine Reagent) for Cannabis, Hashish, Ganja.
  Reaction window: 60 seconds. Color shift: Indigo-Blue/Violet.
- Option 3: KDK (Scott Reagent) for Cocaine HCl, Crack.
  Reaction window: 30 seconds. Color shift: Cobalt Blue.
- Displays reagent lot/batch number input with expiration date and quality pass indicator.
- Single-select radio/card interface with 8dp grid spacing.
- CTA: "PROCEED TO REFERENCE CARD SCAN" (height: 56dp, min 48x48dp touch targets).
```

### Prompt 5: Reference Card QR Scan Screen (`CardScanScreen`)
```
Build a Flutter screen called CardScanScreen to scan and validate the official NCB Reference Card
before optical capture begins.
Requirements:
- Live camera viewfinder with rounded reticle overlay and flashlight toggle action.
- 3-Frame Debounce: Only accepts a scan after the SAME payload string has been read on 3
  consecutive frames to eliminate motion blur misreads.
- Format Validation: Must start with official prefix "NCBCARD-", followed by serial and checksum.
  Reject invalid formats with clear red alert text.
- 3-Second Inactivity Hint: If no QR is detected within 3 seconds, show an ambient
  "Low light? Try toggling flashlight" prompt.
- Offline Tolerance: If offline, validates against cached issuance roster and flags
  "cardVerificationPending = true" for server reconciliation.
- On valid scan, navigates to ReactionTimerScreen passing validated card serial.
```

### Prompt 6: Reaction Timer Screen (`ReactionTimerScreen`)
```
Build a Flutter screen called ReactionTimerScreen that enforces the statutory kinetic reaction
stabilization window before optical capture.
Requirements:
- Circular animated countdown timer matching the selected assay duration (e.g. 45s for NDDK).
- Chemical Stage Guide: Visual indicators distinguishing between initial dissolution phase,
  chromophore formation, and stable measurement window.
- Quality Gating: The "PROCEED TO OPTICAL CAPTURE" button remains disabled and visually greyed
  until the countdown enters the valid kinetic measurement window.
- Non-dismissible statutory alert: "Forensic Rule: Tests imaged before the kinetic window are
  legally inadmissible under NDPS §52A."
```

### Prompt 7: Optical Capture Screen (`CameraCaptureScreen`)
```
Build a Flutter screen called CameraCaptureScreen with live camera preview and real-time quality gating.
Minimal Chrome: Thin black top bar with 48x48dp back button, title, card serial, and demo sample selector.
Requirements:
- CustomPainter Reticle: Draws 4-corner ArUco alignment reticle and central reaction target zone.
  Renders green outline when all checks pass, red outline with failure reason when any fail.
- Real-Time Quality Checks (every 250ms):
  1. Card detection: Verifies all 4 ArUco markers are within frame.
  2. Blur check: Computes Laplacian variance (hard threshold >= 100.0).
  3. Exposure check: Verifies histogram is not clipped at dark/bright extremes.
- Shutter Button: 72dp diameter circular button, centered horizontally, 32dp clearance above
  bottom safe area. Disabled until all 3 quality checks pass.
- Burst Capture: On tap, captures 4 frames over ~400ms, selects best frame (least specular highlight),
  and releases rejected frames immediately to conserve memory.
- Fail-Closed GPS: Fetches GPS via geolocator with 5s timeout. If unavailable or denied, do NOT
  block capture; proceed and flag record "locationConfirmed = false".
```

### Prompt 8: Processing Screen (`ProcessingScreen`)
```
Build a Flutter screen called ProcessingScreen that runs the optical calibration engine on a
dedicated background isolate (using Dart compute()) to prevent UI thread freezing.
Diagnostic Stages Displayed Sequentially:
1. "Detecting 4-Corner ArUco Markers & Card Homography..."
2. "Computing Reference Gray Step-Wedge Illumination Matrix..."
3. "Converting Reaction ROI from sRGB to CIE L*a*b* Colorspace..."
4. "Executing CIEDE2000 Distance Calculation against Standard Curve..."
5. "Cross-Referencing NDPS Reagent Interferents Table..."
6. "Finalizing Evidence Package & Tamper Pre-Hash..."
- Computes ΔE2000 distance, confidence score (weighted by ΔE margin and Laplacian blur score),
  and automatically transitions to ResultScreen.
```

### Prompt 9: Result Screen (`ResultScreen`)
```
Build a Flutter screen called ResultScreen displaying the forensic classification outcome.
Requirements:
- Large High-Contrast Status Badge at top:
  - Positive (Contraband Alert): BG #FDECEA, Text #B3261E, Warning Icon.
  - Negative (Clear): BG #E8F5E9, Text #1B6E2F, Check Circle Icon.
  - Inconclusive (Retest): BG #FFF4E0, Text #9E5B00, Help Outline Icon.
  - Strictly pair Color + Icon + Text Label together.
- Plain-text confidence percentage (e.g. 96.2%).
- Interferent Warnings Callout Box: Prominently lists known false-positive interferents
  (e.g. Levamisole, Phenacetin, Lidocaine).
- Persistent Non-Dismissible Banner:
  "PRESUMPTIVE RESULT ONLY: Mandatory confirmatory laboratory testing required under
  NDPS Act §52A and BSA 2023 §63 before submission to trial court."
- Dual Action CTAs: "RETAKE CAPTURE" (discards attempt, returns to capture) and
  "CONFIRM & DUAL-SIGN" (56dp height, proceeds to record confirmation).
```

### Prompt 10: Record Confirmation Screen (`RecordConfirmScreen`)
```
Build a Flutter screen called RecordConfirmScreen capturing statutory seizure panchnama metadata.
Requirements:
- Form Fields:
  1. FIR / Crime Number (mandatory).
  2. Exact Seizure Location / Panchnama Premises.
  3. Contraband Visual Description / Packaging.
  4. Independent Panch Witness Details.
  5. Accused Present Checkbox (mandatory statutory requirement under NDPS §52A).
- Dual-Signing Execution:
  1. Factor 1: Device Hardware Signature via Android Keystore P-256.
  2. Factor 2: Officer Signature via in-memory PIN-derived ECDSA key.
- Hash-Chain Invariant: Computes H_n = SHA256(CanonicalJson_n + H_{n-1}) and appends immutable
  record into local encrypted SQLite database.
- 2G SMS Witness: Generates 140-char GSM payload (NCB|<id>|<hash>|<officer>|<result>|<gps>) and
  dispatches over cellular SIM.
- Navigates directly to RecordDetailScreen upon sealing.
```

### Prompt 11: Seizure Test History Screen (`HistoryScreen`)
```
Build a Flutter screen called HistoryScreen providing a searchable, filterable log of all field tests.
Requirements:
- Search bar filtering by Test ID, Officer Badge, or Reference Card Serial.
- Filter chips: "All", "Positive", "Negative", "Pending Sync".
- List Items: Styled with GovTheme, showing Test ID, classification badge, assay kit, ΔE2000,
  truncated SHA-256 hash, and sync state icon.
- Chain Integrity Audit Action: AppBar icon triggers recursive verification walking all blocks
  from Genesis, displaying total verified blocks and BSA §63 compliance confirmation.
```

### Prompt 12: Record Detail Screen (`RecordDetailScreen`)
```
Build a Flutter screen called RecordDetailScreen displaying complete forensic audit parameters.
Sections:
1. Prominent GovResultBadge (Large format).
2. Optical Calibration Card: Kit type, CIEDE2000 distance, blur variance, reaction window, accused present flag.
3. Spatio-Temporal Card: UTC timestamp, Officer ID, Device ID, GPS coordinates (or location unconfirmed alert).
4. Cryptographic Ledger Card: Current block SHA-256 digest, previous block hash (H_{n-1}),
   device hardware P-256 signature, and officer session ECDSA signature.
5. Sync Mesh & Out-of-Band Card: Cloud sync status with "Sync Now" button, and 2G SMS witness status
   with "Send SMS" retry button.
6. AppBar Action: "Export BSA §63 Certificate" generating legal court-ready PDF certificate text.
```

### Prompt 13: Sync Status Screen (`SyncStatusScreen`)
```
Build a Flutter screen called SyncStatusScreen managing the 3-tier offline sync mesh.
Tiers Displayed:
- Tier 1: Local Encrypted SQLite Database (always active).
- Tier 2: 2G SMS Out-of-Band Witness (140-char GSM payload dispatched directly via cellular SIM).
- Tier 3: Staged Wi-Fi / Cellular Cloud Sync (Stage 1 Metadata -> Stage 2 Full Image).
Features:
- Tactical Mesh Status card showing BLE / Wi-Fi Direct listening state.
- Pending Cloud Sync record count and Pending 2G SMS count.
- Action Buttons: "Sync Cloud" (triggers batch upload) and "Flush 2G SMS" (dispatches all pending SIM SMS).
- List of queued records with truncated SHA-256 hashes and 140-char GSM payloads.
```

### Prompt 14: Approval Queue Screen (`ApprovalQueueScreen`)
```
Build a Flutter screen called ApprovalQueueScreen strictly for the Supervisor role.
Requirements:
- Active clearance banner: "SUPERVISOR AUTHORIZATION ACTIVE • Section 52A NDPS Approval Authority".
- Filters and displays high-stakes / commercial quantity positive seizures requiring secondary approval.
- Co-Signing Action: Generates Supervisor ECDSA P-256 digital signature over the test ID and appends
  an AuditLogEntry to the tamper-evident chain.
- Shows officer details, ΔE distance, block SHA hash, and confirmation dialog upon co-signing.
```

### Prompt 15: Profile & Security Settings Screen (`ProfileSettingsScreen`)
```
Build a Flutter screen called ProfileSettingsScreen displaying apparatus security attestation.
Requirements:
- Officer Identity Card: Badge number, unit/zonal division, assigned hardware apparatus DEV-001.
- Active Reference Card: Serial number and cryptographic issuance status.
- Architectural Security Notice: Clearly explains that Admin and Auditor capabilities are strictly
  restricted to the Web Console to eliminate field device theft attack surfaces.
- Ledger Audit Button: Executes real-time recursive SHA-256 integrity verification across local chain.
- Session Purge & Logout: Prompts confirmation, purges PIN-derived ECDSA key from memory, and returns
  to LoginScreen.
```

---

## 6. Zero-Budget & Free Package Reference

| Package | Purpose | License / Cost |
|---|---|---|
| `camera` | Live camera preview & burst frame capture | Free / Open Source |
| `geolocator` | GPS coordinate acquisition with fail-closed timeout | Free / Open Source |
| `sqflite` | Local SQLite database engine | Free / Open Source |
| `crypto` | Pure-Dart SHA-256 recursive hashing & HMAC | Free / Open Source |
| `pointycastle` | NIST P-256 ECDSA key generation & PBKDF2 derivation | Free / Open Source |
| `flutter_secure_storage` | Hardware Keystore / Keyring wrapping | Free / Open Source |
| `http` | Staged metadata & image synchronization | Free / Open Source |
| `intl` | UTC timestamping & forensic date formatting | Free / Open Source |

---

## 7. Crash-Prevention & Code Quality Standards

1. **Strict Sound Null Safety**: Do NOT use the `!` null-assertion operator anywhere in camera, GPS, or file paths. Fallback gracefully to default states or failure flags.
2. **Fail Open on Capture, Fail Closed on Trust**: If GPS times out or is denied, proceed with capture but flag `locationConfirmed = false`.
3. **Dedicated Isolates for Compute**: Never run ΔE2000 calculations or image processing on the main UI isolate; use `compute()` to prevent UI freezes.
4. **Mandatory Disposal**: Always dispose camera controllers, text controllers, and timers in `dispose()`.
5. **Global Zone Guarding**: Wrap app initialization in `runZonedGuarded()` and handle `FlutterError.onError` to log errors instead of silently crashing.
