# SIH26231 — Unified Master Project Plan & Complete Engineering Specification
## Digital Companion for Field Drug Testing: Mobile-First Presumptive Testing, Tamper-Evident Records, Panchanama-Ready Documentation, and End-to-End System Architecture

---

## Document Control & Executive Summary
- **Problem Statement ID:** SIH26231
- **Project Title:** Digital Companion for Field Drug Testing
- **Target Agency:** Ministry of Home Affairs (MHA) / Narcotics Control Bureau (NCB) / State Police Anti-Narcotics Task Forces
- **Statutory Framework:** 
  - Narcotic Drugs and Psychotropic Substances (NDPS) Act, 1985 (§52A)
  - NDPS (Seizure, Storage, Sampling and Disposal) Rules, 2022
  - Bharatiya Sakshya Adhiniyam (BSA), 2023 (§63 — Admissibility of Electronic Records)
  - Digital Personal Data Protection (DPDP) Act, 2023 (§17 — Law Enforcement Exemption)
  - Bharatiya Nagarik Suraksha Sanhita (BNSS), 2023 (Search, Seizure & Witness Documentation)
- **UI/UX & Accessibility Standard:** Guidelines for Indian Government Websites (GIGW 3.0) / WCAG 2.1 Level AA
- **Target Platforms:** 
  1. **Primary Field App:** Flutter (Android-first, iOS ready) for field officers and mobile supervisors
  2. **Back-Office Web Console:** React / Node.js web dashboard for Admin, Auditor, and Lab review
- **Team Structure & Budget:** 5 Members (2 Build, 2 Research, 1 PM / Domain / PPT) | **Budget: ₹0** (All components use free-tier, open-source, or native OS capabilities).

---

## 1. Guiding Principles & Core Design Rules

1. **Deterministic Before ML**: The primary classification (Positive / Negative / Inconclusive) must use mathematically transparent, courtroom-defensible colorimetry (CIE $L^*a^*b^*$ and CIEDE2000 $\Delta E^*_{00}$). Machine Learning (e.g., TFLite) acts only as an auxiliary/comparison model and never as an unexplainable "black-box" decision maker.
2. **Fail Closed**: Any uncertainty (poor image, missing reference card, blur, glare, lighting clipping, clock mismatch, location discrepancy, uncalibrated reagent kinetics, or missing witness signature) strictly degrades to **"Flagged / Inconclusive"** with explicit reasons and retake instructions—never to a confident-looking false result.
3. **Zero Paid Dependency**: 100% of sensitive operations (cryptographic hashing, ECDSA signing, barcode scanning, computer vision, and local database storage) execute on-device without third-party cloud API costs, subscription gateways, or credit card requirements.
4. **Administrative Capability Kept Off Mobile Devices**: The mobile client is restricted to field-operational roles (Officer and mobile Supervisor). Admin functions (device provisioning, officer roster management, key revocation, and threshold recalibration) and Auditor functions are isolated to the secure Web Console to prevent unauthorized administrative escalation if a phone is lost or stolen in the field.

---

## 2. Technical Stack Matrix (₹0 Budget / Open-Source)

| Layer | Technology Choice | Architectural Justification | Cost |
| :--- | :--- | :--- | :--- |
| **Mobile App Framework** | Flutter (Dart 3.x) | Single cross-platform codebase, direct camera/sensor control, high-performance platform channels | Free (Open-Source) |
| **Camera Capture** | `camera` Flutter plugin | Direct access to raw camera frame stream for multi-frame burst and real-time quality gating | Free (Open-Source) |
| **Computer Vision Engine** | OpenCV (`opencv_dart` / native C++ via NDK) | ArUco reference card detection, Laplacian blur variance calculation, perspective warp, RGB $\rightarrow$ Lab conversion | Free (Apache 2.0) |
| **Card Corner Detection** | OpenCV ArUco Markers | 4 corner fiducial markers printed on card; resilient to rotation, tilt, and field perspective distortion | Free |
| **QR & Barcode Scanning** | Google ML Kit (Barcode Scanning) | High-speed, 100% on-device offline reading of reference card serials and officer credentials; zero API keys | Free |
| **Encrypted Local Storage** | SQLite via `sqflite` + `sqlcipher_flutter_libs` | Embedded AES-256 encrypted database; supports offline hash-chain ledger without internet | Free (Open-Source) |
| **Local Secret Keystore** | `flutter_secure_storage` | Wraps Android Keystore / iOS Keychain hardware-backed Keystore; never exposes raw key material to disk | Free (OS-native) |
| **Cryptographic Hashing** | SHA-256 via Dart `crypto` package | Standard cryptographic primitive matching Section 63 BSA legal certificate requirements | Free |
| **Asymmetric Signatures** | ECDSA P-256 via Android Keystore / StrongBox | Hardware-backed non-exportable private key bound to the physical device | Free (OS-native) |
| **Officer Key Derivation** | PBKDF2 / Argon2 via `pointycastle` | Derives officer signing credential dynamically from PIN + unique per-officer salt; held in volatile memory only | Free |
| **Backend & Cloud Database** | Firebase Spark (Free Tier) | Always-on Firestore, Cloud Storage, Authentication, and Cloud Functions; generous free quotas | Free |
| **Alternative Backend** | Supabase Free Tier (PostgreSQL) | Relational SQL schema with Row-Level Security (RLS) (kept alive with free UptimeRobot pings) | Free |
| **Out-of-Band SMS Anchor** | Native Android `SmsManager` via `telephony` / `flutter_sms` | Broadcasts 140-char SHA-256 hash anchor over 2G cellular network using device SIM; zero SMS gateway costs | Free (SIM SMS plan) |
| **GPS & Geolocation** | `geolocator` plugin | High-precision satellite GPS coordinates, altitude, provider, accuracy radius, and mock-location detection | Free |
| **Reverse Geocoding** | OpenStreetMap Nominatim | Translates raw GPS coordinates to human-readable district/state location strings | Free (Fair-use) |
| **Push Notifications** | Firebase Cloud Messaging (FCM) & `flutter_local_notifications` | Background sync alerts and on-device offline result readiness alerts | Free |
| **Panchanama PDF Engine** | Flutter `pdf` & `printing` packages | Generates pagination-safe, high-resolution Panchanama support documents and Section 52A certificates | Free |

---

## 3. End-to-End System Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               OFFICER'S PHONE (FLUTTER)                                │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
    ┌───────────────────────────────────────┼────────────────────────────────────────┐
    ▼                                       ▼                                        ▼
CAPTURE LAYER                         CALIBRATION & CLASSIFY                   EVIDENCE LAYER
- Native camera viewfinder            - Detect 4 ArUco card markers            - Canonical JSON (BSA §63)
- Laplacian blur check (σ² > 100)     - White-patch illumination calibration   - Raw & stamped SHA-256 hashes
- Guide overlay (CustomPainter)       - sRGB -> CIE XYZ -> CIE L*a*b*          - Append to local hash chain
- Chemical kinetic window countdown   - CIEDE2000 (ΔE*₀₀) vs reference table   - Dual digital signatures:
- Multi-frame burst (3–5 frames)      - Threshold -> Pos/Neg/Inconclusive        * Device key (Keystore)
- Real-time GPS coordinate fix        - Confidence = f(ΔE, blur, card quality)   * Officer key (PIN-derived)
    │                                       │                                        │
    └───────────────────────────────────────┴────────────────────────────────────────┘
                                            │
                                            ▼
                           LOCAL ENCRYPTED STORE (SQLCipher)
                           - Full record + watermarked image encrypted at rest
                           - Append-only hash chain: H[n] = SHA-256(H[n-1] + Data[n])
                           - Instant 140-char out-of-band GSM SMS witness anchor (2G)
                                            │
                                 [ When internet returns ]
                                            │
                                            ▼
                           STAGED SYNC ENGINE (Firebase / REST)
                           1. Metadata + Hash sync (instant small payload)
                           2. Full watermarked media sync (when bandwidth permits)
                                            │
                                            ▼
                       CENTRAL SERVER & SUPERVISOR WEB CONSOLE
                       - Periodically folds synced hashes into Merkle Tree root
                       - Role-based access: Officer, Supervisor, Auditor, Admin
                       - Searchable ledger (Test ID, Case, Date, Drug, Location)
                       - Formal Panchanama draft review & supervisor co-signing
```

---

## 4. Consolidated Test Flow: Replacing Demo Stubs With Real Processing

### Step 0: Total Removal of Demo Logic
- Locate and permanently delete all hardcoded booleans, random output generators, mock classification stubs, and "test mode" fallback switches.
- Under forensic rules, no code path other than the deterministic computer vision pipeline (Steps 3–4) may ever produce or return a test outcome.

### Step 1: "Start Test" $\rightarrow$ Kit Selection Screen
- Present 3 equal-width, vertically stacked cards (satisfies GIGW 48dp minimum touch target; horizontal columns violate phone-width accessibility):
  1. **Card 1 — "NDDK" (Narcotic Drugs Detection Kit)**: Subtitle: *"Opiates, cannabis, cocaine, amphetamines"* (Marquis Reagent, 45s kinetic window, Violet/Purple expected).
  2. **Card 2 — "PCDK" (Precursor Chemicals Detection Kit)**: Subtitle: *"Precursor chemicals used in synthesis"* (Duquenois-Levine Reagent, 60s kinetic window, Indigo-Blue expected).
  3. **Card 3 — "KDK" (Ketamine Detection Kit)**: Subtitle: *"Ketamine"* (Scott Modified Reagent, 30s kinetic window, Cobalt Blue expected).
- UI Specs: Surface `#FFFFFF`, 16dp padding, 16dp corner radius, icon, title, subtitle, full-card touch target.
- Action: Tapping sets the `KitType` enum and navigates forward, passing `KitType` to all downstream screens.

### Step 2: Reference Card QR Scan & Kit Mismatch Interlock
- Uses on-device `google_mlkit_barcode_scanning` (offline, no API key).
- **3-Frame Debounce Rule**: The exact same QR payload must be successfully read across 3 consecutive frames to prevent motion-blur misreads.
- **Prefix & Serial Validation**: Checks for official prefix (`MHACARD-` / `NCBCARD-`) followed by serial and checksum.
- **Kit Mismatch Interlock**: If the officer selected **NDDK** in Step 1 but scans a card provisioned for **KDK**, the system immediately displays a high-visibility warning and blocks the flow. This stops officers from running reagent sequences against the wrong reference scale.
- **Flashlight Assist**: Automatically prompts *"Try toggling flashlight"* if no QR code is detected within 3 seconds.

### Step 3: Hardware Capture (Camera & GPS Packager)
- Reuses physical camera and GPS engines without rebuilding.
- Bundles all sensor outputs into a single immutable `CaptureResult` transfer object:
  ```dart
  class CaptureResult {
    final List<CapturedFrame> burstFrames;
    final File capturedImageFile;
    final GeoPoint? location;
    final bool locationConfirmed;
    final KitType kitType;
    final String cardSerial;
    final String reagentBatch;
    final DateTime reactionTimestamp;
    final bool accusedPresent;
  }
  ```
- **Fail Open on Capture, Fail Closed on Trust**: If GPS fails or times out after 5 seconds, capture proceeds but sets `locationConfirmed = false` and flags the record for officer attestation.

### Step 4: Real Computer Vision & Colorimetry Pipeline
Runs on a background Dart isolate (`compute()`) to prevent UI thread freezing:
1. **Reagent Config Loading**: Loads target chemical spectral profiles based on `KitType`.
2. **ArUco Marker Extraction**: Detects the 4 corner ArUco fiducials to rectify perspective tilt.
3. **White-Balance Illumination Correction**: Samples known grayscale patches on the card to calculate a Bradford chromatic adaptation matrix, normalizing ambient lighting.
4. **Color Space Conversion**: Converts corrected reaction-zone pixels from sRGB to standard CIE $L^*a^*b^*$ coordinates under D65 illuminant.
5. **CIEDE2000 Calculation**: Measures chromatic distance ($\Delta E^*_{00}$) against candidate outcomes in the versioned kit configuration.
6. **Multi-Step Reagent Sequences**: If the matched outcome triggers a follow-up step (e.g. NDDK Marquis $\rightarrow$ Nitric Acid, or Scott Reagent Steps 1 $\rightarrow$ 2 $\rightarrow$ 3), prompts the officer via `StepIndicator UI` to apply the next reagent and repeats capture.
7. **Dynamic Forensic Confidence Formula**:
   - Must visibly change between sharp and degraded photos of the exact same sample.
   - Combines chromatic closeness ($\Delta E$ margin from threshold) with capture quality (Laplacian blur variance, exposure balance, ArUco detection confidence).
8. **Interferent Lookup**: Cross-references detected drug signatures against known false-positive cutting agents (e.g., Levamisole, Lidocaine, Procaine) and attaches warnings.

### Step 5: Result Screen & Statutory Notice
- Displays large status badge paired with icon + text label (never color alone):
  - **Positive (Drug Detected — Alert)**: Background `#FDECEA`, Text/Icon `#B3261E` (Contrast 5.71:1)
  - **Negative (None Detected — Clear)**: Background `#E8F5E9`, Text/Icon `#1B6E2F` (Contrast 5.62:1)
  - **Inconclusive (Needs Retest / Lab)**: Background `#FFF4E0`, Text/Icon `#9E5B00` (Contrast 4.88:1)
- Confidence displayed as explicit percentage (e.g., `87.4%`).
- Persistent non-dismissible banner: *"Presumptive result only — laboratory confirmation required."*
- Action buttons: *"Retake"* (discards attempt) and *"Confirm & Record"* (proceeds to signing).

### Step 6: Local Save & Staged Cloud Sync
- **Local Commit**: Saves to SQLite encrypted ledger, appends to hash chain, binds dual signatures.
- **Out-of-Band SMS Anchor**: Automatically sends 140-char hash anchor over 2G SIM.
- **Cloud Sync**: Uploads metadata to Firestore (`tests/{testId}`) and watermarked photos to Firebase Storage (`records/{testId}/frame_{n}.jpg`).
- **Web Console Accessibility**: Enables supervisor/auditor viewing via Firebase JS SDK without custom intermediate backends.

---

## 5. Object-Oriented Domain Model (Section 2)

```dart
enum Role { officer, supervisor, auditor, admin }
enum DeviceStatus { active, revoked, lost }
enum CardStatus { active, retired, reported_lost }
enum KitType { nddk, pcdk, kdk }
enum ResultCategory { positive, negative, inconclusive }
enum SyncStatus { pending, smsWitnessed, stagedSynced, fullyAnchored }
enum AuditAction { view, export, search, sign }

class User {
  final String userId;
  final String name;
  final String email;
  final String badgeNumber;
  final int age;
  final String gender;
  final String city;
  final String department;
  final Role role;
  final String deviceId; // Bound hardware device
  final DateTime provisionedAt;
  final String rank;
  final String unit;
  final bool isVerified;
  final String? serviceId;
  final String dob;
  final String phone;

  User({
    required this.userId,
    required this.name,
    required this.email,
    required this.badgeNumber,
    required this.age,
    required this.gender,
    required this.city,
    required this.department,
    required this.role,
    required this.deviceId,
    required this.provisionedAt,
    required this.rank,
    required this.unit,
    this.isVerified = true,
    this.serviceId,
    this.dob = "1996-05-15",
    this.phone = "+91 98765 43210",
  });
}

class Device {
  final String deviceId;
  final String hardwareKeyFingerprint; // From Keystore / StrongBox
  final String? assignedUserId;
  final DeviceStatus status;

  Device({
    required this.deviceId,
    required this.hardwareKeyFingerprint,
    this.assignedUserId,
    this.status = DeviceStatus.active,
  });
}

class ReferenceCard {
  final String serial;
  final String qrPayload;
  final String? issuedToOfficerId;
  final CardStatus status;

  ReferenceCard({
    required this.serial,
    required this.qrPayload,
    this.issuedToOfficerId,
    this.status = CardStatus.active,
  });
}

class TestSession {
  final String sessionId;
  final KitType kitType;
  final DateTime reactionStartedAt;
  final List<CapturedFrame> burstFrames;
  CalibrationResult? calibration;

  TestSession({
    required this.sessionId,
    required this.kitType,
    required this.reactionStartedAt,
    this.burstFrames = const [],
    this.calibration,
  });

  /// Key method: computes calibration without mutating raw captured frames
  CalibrationResult runCalibration() { /* ... */ }
}

class CapturedFrame {
  final String frameId;
  final List<int> imageBytes;
  final DateTime capturedAt;
  final double laplacianVariance;
  final double exposureScore;
  final bool arucoDetected;

  CapturedFrame({
    required this.frameId,
    required this.imageBytes,
    required this.capturedAt,
    required this.laplacianVariance,
    required this.exposureScore,
    required this.arucoDetected,
  });
}

class CalibrationResult {
  final double deltaE;
  final double confidence;
  final bool cardDetected;
  final bool withinReactionWindow;
  final bool qualityPassed;

  CalibrationResult({
    required this.deltaE,
    required this.confidence,
    required this.cardDetected,
    required this.withinReactionWindow,
    required this.qualityPassed,
  });
}

class ClassificationResult {
  final ResultCategory category;
  final double confidence;
  final List<String> interferentWarnings;

  ClassificationResult({
    required this.category,
    required this.confidence,
    required this.interferentWarnings,
  });
}

class GeoPoint {
  final double latitude;
  final double longitude;
  final double accuracy;

  GeoPoint({required this.latitude, required this.longitude, required this.accuracy});
}

class Signature {
  final String signerId;
  final String algorithm; // ECDSA-P256
  final String signatureBytes;
  final DateTime signedAt;

  Signature({
    required this.signerId,
    this.algorithm = 'ECDSA-P256',
    required this.signatureBytes,
    required this.signedAt,
  });
}

class TestRecord {
  final String testId;
  final String prevHash;
  final String recordHash;
  final User officer;
  final Device device;
  final ReferenceCard card;
  final TestSession session;
  final ClassificationResult result;
  final GeoPoint? location;
  final bool locationConfirmed;
  final DateTime timestamp;
  final Signature deviceSignature;
  final Signature officerSignature;
  SyncStatus syncStatus;

  TestRecord({
    required this.testId,
    required this.prevHash,
    required this.recordHash,
    required this.officer,
    required this.device,
    required this.card,
    required this.session,
    required this.result,
    this.location,
    required this.locationConfirmed,
    required this.timestamp,
    required this.deviceSignature,
    required this.officerSignature,
    this.syncStatus = SyncStatus.pending,
  });

  /// Canonical JSON for Bharatiya Sakshya Adhiniyam (BSA) §63 compliance
  String toCanonicalJson() { /* ... */ }

  /// Strict 140-char GSM SMS payload for 2G out-of-band anchor
  String toGsmSmsPayload() {
    return 'MHA|${testId.replaceAll("TEST-", "")}|${recordHash.substring(0, 32)}|${officer.badgeNumber}|${result.category.name.toUpperCase()}|${location?.latitude ?? 0},${location?.longitude ?? 0}';
  }

  /// Appends record to local SQLite ledger and enforces hash-chain invariant
  static Future<TestRecord> appendToChain(TestRecord record) async { /* ... */ }
}

class AuditLogEntry {
  final String logId;
  final String prevLogHash;
  final String actorId;
  final AuditAction action; // view | export | search | sign
  final String? targetTestId;
  final DateTime timestamp;

  AuditLogEntry({
    required this.logId,
    required this.prevLogHash,
    required this.actorId,
    required this.action,
    this.targetTestId,
    required this.timestamp,
  });
}
```

---

## 6. GIGW 3.0 Government Design System & UI Specifications

### 6.1 Color Palette & Contrast Compliance (WCAG 2.1 Level AA)
All color pairings have mathematically verified contrast ratios $\ge 4.5:1$ for normal text and $\ge 3:1$ for large UI text.

| Token | Hex | Use / Context | Computed Contrast |
| :--- | :--- | :--- | :--- |
| `bg.base` | `#F7F9FC` | Main application background (cool light tint) | 15.65:1 against text |
| `bg.surface` | `#FFFFFF` | Cards, modal sheets, container backgrounds | — |
| `text.primary` | `#1A1F29` | Primary headings, body copy, active labels | 15.65:1 on `bg.base` |
| `text.secondary` | `#5B6472` | Subtitles, supporting text, metadata labels | ~4.6:1 on `bg.base` ($\ge 14\text{sp}$) |
| `border.default` | `#E1E5EB` | Dividers, bounding reticles, card borders | Non-text UI border |
| `primary` | `#1E4B8F` | Government Ashoka Navy primary buttons & headers | 8.55:1 against white text |
| `primary.pressed`| `#163765` | Active / pressed state of primary buttons | Darker, fail-safe |
| `secondary` | `#445266` | Secondary outlined buttons and controls | — |

#### Status Colors (Non-Traffic-Light Compliant)
In forensic enforcement, "Positive" signifies drug presence (alert condition), not a green "success":
| Result Verdict | Background Tint | Text & Icon Color | Computed Contrast | Meaning |
| :--- | :--- | :--- | :--- | :--- |
| **Positive** (Drug Detected) | `#FDECEA` | `#B3261E` | 5.71:1 | High Alert / Seizure |
| **Negative** (None Detected) | `#E8F5E9` | `#1B6E2F` | 5.62:1 | Clear / Non-Reactive |
| **Inconclusive** (Retest) | `#FFF4E0` | `#9E5B00` | 4.88:1 | Caution / Retest Required |

*Rule:* Never convey status by color alone. Every result badge strictly pairs Color + Glyph Icon (`✕`, `✓`, `!`) + Bold Text Label.

### 6.2 Typography Scale (Major Third Modular Scale: Ratio 1.25)
- `display`: **28sp** — Primary verdict headline (`POSITIVE`, `NEGATIVE`, `INCONCLUSIVE`)
- `title`: **22sp** — Screen titles and modal headers
- `subtitle`: **18sp** — Section headers, card titles, officer credentials
- `body`: **16sp** — General body copy, form inputs, dialog text
- `caption`: **13sp** — Timestamps, GPS coordinates, hash fragments, version numbers

### 6.3 Spacing Grid & Touch Target Mathematics
- **8dp Base Grid**: All spacing values are strict multiples of 8dp (`4dp`, `8dp`, `16dp`, `24dp`, `32dp`, `40dp`, `48dp`).
- **Screen Margins**: 16dp outer screen margin.
- **Inter-Element Gaps**: 16dp default; 8dp for tightly related pairs (label + input); 32dp between major sections.
- **Minimum Touch Target**: **48×48dp** across all buttons and icon triggers (accommodates gloved officers).
- **Capture Shutter Button**: **72dp** circular diameter, horizontally centered, elevated **32dp** above the bottom safe-area inset.
- **CTA Buttons**: Full screen width minus margins ($\text{Screen Width} - 32\text{dp}$), fixed height **56dp**.

---

## 7. Complete 15-Screen Inventory & Role Access Matrix

| # | Screen Name | Role | Primary Purpose & Features |
| :-: | :--- | :--- | :--- |
| **1** | **Splash** | All | Brief startup screen; checks device provisioning status and local SQLite database integrity. |
| **2** | **Login** | All | Government-provisioned device login via Badge ID + PIN (+ optional biometric unlock). |
| **3** | **Home / Dashboard** | Officer, Supervisor | Real-time officer credentials, verified status pill, 1-tap capture CTA, guided protocol CTA, recent tests list, and sync status. |
| **4** | **Kit Selection** | Officer | Step 1 of 6: 3 vertically stacked cards selecting between NDDK, PCDK, and KDK assays. |
| **5** | **Reference Card Scan** | Officer | Step 2 of 6: Scans QR code on reference card with 3-frame debounce; blocks kit mismatches. |
| **6** | **Reaction Timer** | Officer | Step 3 of 6: Countdown ring enforcing chemical kinetic stabilization before capture is allowed. |
| **7** | **Capture** | Officer | Step 4 of 6: Live camera preview, real-time ArUco detection, Laplacian blur check, GPS lock, and 72dp shutter. |
| **8** | **Processing** | Officer | Step 5 of 6: Animated 4-stage diagnostic displaying real-time CV colorimetry and $\Delta E^*_{00}$ extraction. |
| **9** | **Result** | Officer | Step 6 of 6: Result category, confidence %, Lab values, interferent warnings, and presumptive disclaimer banner. |
| **10**| **Record Confirm** | Officer | Case metadata entry, witness details, accused presence flag; triggers dual digital signing and hash chain append. |
| **11**| **Test History** | Officer | Searchable and filterable ledger of officer's historical records. |
| **12**| **Record Detail** | Officer, Supervisor | Full forensic audit view: watermarked evidence image, metadata, hash verification, chain links, and sync status. |
| **13**| **Sync Status** | All | Displays pending sync queue, retry counters, and manual sync trigger. |
| **14**| **Approval Queue** | Supervisor only | Allows supervisors to co-sign high-stakes cases, review district tests, and authorize bulk evidence exports. |
| **15**| **Profile / Settings** | All | Officer details (DOB, Gender, Phone), Service ID verification workflow, password change, hardware key fingerprint, and logout. |

---

## 8. Complete Panchanama-Ready Data Module (10 Sections)

The application compiles a comprehensive Panchanama support draft for investigating officers:

```
+----------------------------------------------------------------------------------------------------+
|                                    PANCHANAMA EVIDENCE DOSSIER                                     |
+----------------------------------------------------------------------------------------------------+
|  1. CASE IDENTITY              2. PLACE AND TIME                 3. SEARCH CONTEXT                 |
|  - Department & Unit           - Landmark & Seizure Address      - Statutory Warrant Authority     |
|  - Case / FIR / NCB Crime No.  - Real-Time Latitude & Longitude  - Premises / Vehicle Searched     |
|  - Seizing Officer ID & Rank   - GPS Satellite Accuracy Radius   - Owner / Occupier Particulars    |
|  - Document Version & Model    - UTC & Network Time-Source       - Legal SOP Reference Checklist   |
+----------------------------------------------------------------------------------------------------+
|  4. PANCH WITNESSES            5. POSSESSOR DETAILS              6. SEIZED INVENTORY               |
|  - Panch Witness 1 (Name, ID)  - Accused / Suspect Full Name     - Item Number & Markings          |
|  - Panch Witness 2 (Name, ID)  - Recovery Location / Concealment - Gross, Net, and Tare Weights    |
|  - Independent Declaration     - Presence During Chemical Test   - Form (Powder, Resin, Tablets)   |
|  - Digital Touch Signatures    - Suspect Refusal / Ack Note      - Container Barcode / QR Label    |
+----------------------------------------------------------------------------------------------------+
|  7. FIELD CHEMICAL TEST        8. SAMPLING AND SEALING           9. CUSTODY & FORWARDING           |
|  - Kit Type & Lot / Batch No.  - Duplicate Samples (S1, S2)      - Handover Sender & Receiver      |
|  - Reagent Expiry & Window     - Brass Seal / Lac Seal Number    - Malkhana / Godown Safe Ref      |
|  - Calibrated CIE L*a*b* & ΔE  - Seal Description & Image Ref    - Transit Log & Forwarding Memo   |
|  - Presumptive Result Category - Seal Intact Witness Signatures  - Chemical Examiner Lab Route     |
+----------------------------------------------------------------------------------------------------+
|  10. ATTACHMENTS & CERTIFICATES                                                                    |
|  - Raw Evidence Photo (SHA-256)                                                                    |
|  - Stamped Forensic Watermarked Photo (NDPS §52A Burn-in)                                          |
|  - Section 63 BSA Digital Integrity Certificate with Hash Chain Verification Status                |
+----------------------------------------------------------------------------------------------------+
```

---

## 9. Comprehensive Panchanama Support PDF Report Structure

The system compiles a 5-to-6 page formal PDF document formatted for court submission:
1. **Cover Page**: Official MHA header, Case ID, FIR number, Seizure time, Status (`Draft / For Review`), and top QR verification code.
2. **Presumptive Field-Test Page**: Kit serial, reagent batch, calibrated color change, measured Lab coordinates, Delta E distance, confidence score, and mandatory legal disclaimer.
3. **Image Evidence Page**: Side-by-side comparison of raw reference image and forensic watermarked evidence photo with embedded GPS, officer badge, and timestamp metadata.
4. **Panchanama Support Pages**: Structured records of Panch search witnesses, accused possessor details, gross/net seizure weights, packaging markings, and official lac seal serial numbers.
5. **Chain of Custody & Malkhana Handover Page**: Officer custody logs, transport details, and laboratory forwarding dispatch references.
6. **Integrity Certificate (Section 63 BSA)**: Complete cryptographic certificate containing image SHA-256 hash, record hash, previous hash, device ECDSA signature, officer signature, and on-device hash chain validation status.

---

## 10. Security Measures & Threat Mitigation Map

| Attack Vector | Threat Scenario | Implemented Mitigation |
| :--- | :--- | :--- |
| **Record Tampering** | Officer or external actor attempts to edit/delete a historical seizure record. | **Append-Only SHA-256 Hash Chain**: Modifying any past record breaks every subsequent hash, instantly detectable by the built-in `HashChain.verify()` audit tool. |
| **Device Theft** | Device is stolen in the field and used to fabricate fraudulent drug test records. | **Dual-Bound Signatures**: Device key is locked in Android Keystore/StrongBox; fabricating a test requires the officer's secret PIN. Neither key alone can create a valid record. |
| **Coerced Officer** | Officer is coerced into fabricating a positive result under duress. | **Kinetic Reaction Window Enforcement**: Shutter is physically gated by the chemical reaction timer; cannot be bypassed. Optional supervisor co-signature on high-stakes seizures. |
| **Card Duplication** | Suspect presents a photocopied or fraudulent reference card. | **Cryptographic QR Serial Registry**: Card serials are verified against issuance logs, and 4 corner ArUco markers are checked for physical perspective distortion. |
| **Replay / Spoofing** | Officer captures a photo of a computer screen or printed photograph. | **Multi-Frame Burst & Exposure Analysis**: 3–5 frame burst detects screen moiré patterns, specular highlights, and lack of micro-parallax. |
| **GPS Spoofing** | Officer uses fake GPS / mock-location apps to falsify seizure coordinates. | **Cross-Check & Attestation**: Geolocator detects mock-location providers; flags records as `location_unconfirmed` rather than silently accepting spoofed locations. |
| **Cloud Alteration** | Malicious insider modifies records directly in the central database. | **Periodic Merkle Root Anchoring**: Synced hashes are batched into Merkle roots anchored to external ledgers or out-of-band SMS logs. |
| **Evidence Leaks** | Unauthorized officer exports and leaks seizure photographs to media. | **Export Watermarking & Audit Trails**: Every export embeds an imperceptible LSB/DCT tracking watermark and logs the actor ID into an immutable audit chain. `FLAG_SECURE` blocks mobile screenshots. |
| **False Claims** | Police department claims presumptive field test is definitive court proof. | **Structural Legal Disclaimers**: *"Presumptive result only — laboratory confirmation required"* is structurally burned into every screen, PDF export, and certificate. |
| **Threshold Gaming** | Smugglers attempt to calibrate cutting agents to fall just outside the detection threshold. | **Versioned Reagent Configs**: Exact $\Delta E$ numerical thresholds are versioned on secure servers and periodically recalibrated rather than exposed as hardcoded client constants. |

---

## 11. Backend API & Firestore Data Model Specification

### 11.1 Firestore Collections
- **`users`**: `{ user_id, role, unit_id, badge_number, assigned_device_ids, status }`
- **`devices`**: `{ device_id, officer_id, public_key_fingerprint, status, last_seen }`
- **`reference_cards`**: `{ card_serial, qr_code, issued_to, calibration_version, status }`
- **`tests` (Hash Chain Ledger)**:
  ```json
  {
    "test_id": "TEST-2026-DEL-0491",
    "case_id": "FIR-2026-STF-881",
    "prev_hash": "a8f3b2c1...",
    "record_hash": "4e1d99a0...",
    "officer_id": "MHA-NZ-7841",
    "device_id": "MHA-SECURE-DEV-001",
    "kit_type": "NDDK",
    "timestamp_utc": "2026-09-27T18:13:38Z",
    "geo": { "latitude": 28.5355, "longitude": 77.2410, "accuracy": 4.5 },
    "result": "POSITIVE",
    "confidence": 0.874,
    "delta_e": 9.08,
    "image_hash": "e3b0c442...",
    "card_serial": "MHACARD-NDDK-2026-0491",
    "device_sig_hex": "3045022100...",
    "officer_sig_hex": "304402201b...",
    "panchanama_status": "DRAFT",
    "sync_status": "FULLY_ANCHORED"
  }
  ```
- **`test_media`**: `{ test_id, original_image_path, stamped_image_path, generated_pdf_path }`
- **`custody_events`**: `{ event_id, test_id, sender, receiver, timestamp, seal_status }`
- **`audit_logs`**: `{ actor_id, action, target_test_id, timestamp, prev_audit_hash, audit_hash }`

### 11.2 API Endpoints
- `POST /sync/records`: Uploads batch of signed, chained metadata records.
- `POST /sync/media/{test_id}`: Uploads high-resolution evidence photos after metadata is anchored.
- `GET /records?query=`: Role-gated search (Officer: own records; Supervisor: district records; Auditor: read-only).
- `POST /records/{id}/export`: Generates Section 63 BSA certificate and watermarked PDF package.
- `POST /anchor/merkle`: Scheduled Cloud Function folding recent record hashes into a Merkle root.
- `POST /devices/provision`: Admin-only device registration and cryptographic key enrollment.

---

## 12. Complete Code-Builder Prompts (Sections 5.1 – 5.7)

### Prompt 5.1 — Project Setup & Safety
```text
Create a new Flutter project named "field_test_companion" targeting Android and iOS.
Use Riverpod for compile-time state safety.
Add dependencies: camera, geolocator, google_mlkit_barcode_scanning, sqflite,
sqlcipher_flutter_libs, flutter_secure_storage, crypto, pointycastle, 
flutter_local_notifications, telephony, cloud_firestore, firebase_auth, firebase_storage.
Set up sound null safety strictly. Do NOT use the `!` null-assertion operator in camera, 
GPS, or file I/O code paths. Wrap app startup in runZonedGuarded() and set 
FlutterError.onError to log uncaught exceptions to a local file instead of silent crashes.
```

### Prompt 5.2 — Capture Screen (Camera + GPS)
```text
Build a Flutter screen called CaptureScreen with full-screen camera preview using the camera package.
Minimal chrome: thin top bar with a 48x48dp back button.
Requirements:
1. Initialize CameraController in initState(), dispose in dispose(). Show full-screen fallback with 
   "Grant Camera Permission" button if permission is denied.
2. Draw a semi-transparent overlay frame using CustomPainter showing reference card placement.
3. Every ~200ms, run real checks:
   - OpenCV ArUco detection finding all 4 corner markers of the card.
   - Blur check: Laplacian variance (threshold > 100).
   - Exposure check: flag if histogram is clipped.
   Update overlay in real time: green outline + checkmark when all pass; red outline + reason when any fail.
4. Capture button (72dp circular, centered, 32dp above safe area) is DISABLED until checks pass.
5. On tap, capture a BURST of 4 frames over ~400ms. Select the best frame (least glare/specular highlight)
   and dispose the rest immediately to prevent memory leaks.
6. Fetch GPS simultaneously with a 5s timeout. Fail open on capture, fail closed on trust 
   (set locationConfirmed = false if GPS fails; never block capture).
```

### Prompt 5.3 — Reference Card QR Scan Screen
```text
Build a Flutter screen called CardScanScreen that scans the QR code on the reference card BEFORE 
capture starts. Use google_mlkit_barcode_scanning (on-device, fully offline).
Requirements:
1. Live camera preview with detected QR bounding-box overlay.
2. 3-Frame Debounce: accept scan only after the SAME payload is read on 3 consecutive frames.
3. Validate payload format: must start with official prefix (e.g. "MHACARD-"). Show clear error 
   on invalid format.
4. Cross-check against selected KitType: if officer selected NDDK but card is KDK, block proceeding 
   with an explicit kit mismatch warning.
5. If no QR is detected within 3s, show "Try toggling flashlight" prompt with torch toggle button.
6. On success, navigate to Reaction Timer screen, passing card serial forward.
```

### Prompt 5.4 — Calibration & Classification Engine
```text
Build a pure-Dart service class called CalibrationEngine with method:
Future<ClassificationResult> classify(CapturedFrame frame, KitType kit)
MUST run on a separate isolate using compute() to avoid freezing the UI thread.
Steps:
1. Locate 4 ArUco markers on the captured frame.
2. Compute white-balance/illumination correction matrix from grayscale reference patches.
3. Apply correction to reaction-zone pixels.
4. Convert corrected reaction color from sRGB to CIE Lab.
5. Compute CIEDE2000 (ΔE) distance between corrected color and reagent reference profile.
6. Apply versioned threshold to output: ResultCategory.positive / .negative / .inconclusive.
7. Compute confidence score combining ΔE threshold margin and image quality score.
8. Lookup known interferents (e.g., Levamisole/Lidocaine) and attach warnings.
Write a unit test feeding two visibly different colored images and asserting two different ΔE values.
```

### Prompt 5.5 — Result Screen & Alert Handling
```text
Build a Flutter screen called ResultScreen shown immediately after classification completes.
Layout:
- Large status badge at top using exact tokens (Positive: #FDECEA / #B3261E, Negative: #E8F5E9 / #1B6E2F, 
  Inconclusive: #FFF4E0 / #9E5B00) pairing color + glyph + text label.
- Confidence percentage displayed as plain text.
- Interferent warnings in a distinct callout box below badge.
- Persistent, non-dismissible banner: "Presumptive result only — laboratory confirmation required."
- Two buttons: "Retake" (discards attempt) and "Confirm & Record" (proceeds to signing).
Alert handling:
- If app is in foreground, show ResultScreen directly.
- If backgrounded, fire a LOCAL notification via flutter_local_notifications deep-linking back to screen.
- If engine throws, show specific "Could not process image, please retake" screen with Retake button.
```

### Prompt 5.6 — Login & Sign-In Screen
```text
Build a Flutter screen called LoginScreen for government-provisioned devices (no self-service sign-up).
Fields:
- Badge Number (pre-registered by Admin via web console).
- Numeric PIN (minimum 6 digits; hashed with PBKDF2 before storing).
- Optional biometric unlock via local_auth as a convenience layer on top of PIN.
On submit:
1. Check device hardware key fingerprint against badge number's local provisioning cache.
2. If device is not registered to officer, block login: "This device is not registered to your badge number."
3. On success, derive officer signing key from PIN via PBKDF2 with per-officer salt stored in 
   flutter_secure_storage. Hold in volatile memory for the session only; never persist derived key to disk.
```

### Prompt 5.7 — Universal Crash-Prevention Checklist
```text
Apply across the entire codebase:
1. Every camera/GPS/file-I/O call must be wrapped in try/catch with user-visible fallback UI. 
   No bare catch (e) {} blocks.
2. Every StatefulWidget opening a resource (CameraController, stream subscription, AnimationController) 
   MUST dispose it in dispose().
3. Never run ΔE calibration, ArUco detection, or image processing on the main isolate — use compute().
4. Set FlutterError.onError and runZonedGuarded at startup to catch and log uncaught exceptions.
5. Test explicitly for: camera permission denied, GPS denied, airplane mode during sync, low storage, 
   rapid double-tap on shutter, and backgrounding mid-capture.
```

---

## 13. Build Roadmap & 8-Phase Team Allocation

| Phase | Milestone / Focus | Primary Owners | Deliverables |
| :---: | :--- | :--- | :--- |
| **Phase 1** | **Capture Pipeline** | Builder 1, Researcher A | Camera preview, ArUco detection, Laplacian blur check, GPS lock strip |
| **Phase 2** | **Colorimetry Engine** | Builder 1, Researcher A | White-patch calibration, sRGB $\rightarrow$ Lab, CIEDE2000 $\Delta E$, confidence math |
| **Phase 3** | **Cryptographic Ledger** | Builder 2, Researcher B | SQLite + SQLCipher, SHA-256 Merkle chain, dual ECDSA signatures |
| **Phase 4** | **Offline Queue & Sync** | Builder 2 | Staged Firebase sync, offline storage resilience, network reconnect listeners |
| **Phase 5** | **SMS & Merkle Batching** | Builder 2 | 140-char GSM 2G SMS anchor, cloud Merkle root batching functions |
| **Phase 6** | **Audit, Roles & BSA-63** | Builder 2, Researcher B | Role permissions, audit log hashing, export watermarks, Section 63 BSA generator |
| **Phase 7** | **End-to-End Testing** | Whole Team | Sunlight/indoor/flash matrix, blurred sample gating, unit test validation |
| **Phase 8** | **Deck & Demonstration** | Editor / PPT, Whole Team | Presentation deck, system architecture diagrams, live demo video |

*Build Order Rule:* Phases 1–2 must be completed first. Demonstrating live optical calibration converting a poor-lighting photograph into an accurate, objective chemical verdict is the single strongest stage demonstration and has zero backend dependencies.

---

## 14. 9-Step Live Demonstration Script

1. **Case & Witness Entry**: Launch app, authenticate as Officer, create new seizure case, input 2 independent Panch search witnesses, and enter package net weight.
2. **Quality Gate Rejection Demo**: Deliberately present an out-of-focus or angled camera view. Show the live viewfinder dynamically highlight red and disable the shutter (*"Image too blurry — Laplacian variance below 100"*).
3. **Valid Capture & Watermark**: Present reference card under proper illumination. Viewfinder reticle locks green; tap shutter. Show instant automated NDPS §52A watermark burn-in with live GPS satellite coordinates.
4. **Objective Colorimetric Verdict**: Display real-time CIEDE2000 classification showing measured Lab values vs reference standards, confidence score ($87.4\%$), and chemical kinetic status.
5. **Tamper-Evident Ledger Commit**: Show the generated SHA-256 block hash, previous block link, and dual touch-screen signatures (Officer + Panch witness).
6. **Case Search & Audit**: Search local SQLite ledger by Case FIR number; retrieve full historical test record immediately.
7. **Panchanama PDF Generation**: Tap *"Export Panchanama Package"*; render the 6-page formal PDF containing search narrative, witness details, inventory weights, watermarked evidence photos, and Section 63 BSA certificate.
8. **Tamper Detection Demonstration**: Alter a single byte in an exported database record or image. Run `HashChain.verify()` and visibly show the app flag the exact broken block index (*"Cryptographic Chain Broken: Block #14 Modified"*).
9. **Legal Boundary Closing**: Conclude presentation with the mandatory statutory disclaimer: *"Presumptive field test result only. Formal laboratory confirmatory testing remains mandatory under NDPS Act procedure."*

---

## 15. Known Technical Limitations & Final Pitch

### Transparent Engineering Disclosures
- **Watermark Recompression**: Basic LSB spatial watermarking detects naive leaks but can degrade under aggressive social media lossy recompression (JPEG quality $< 50\%$).
- **Device Color Calibration**: Camera sensor white-balance profiles are calibrated against a starter reference phone matrix and will require extended device profiling for nationwide fleet rollouts.
- **Proprietary Batch Variance**: Reagent thresholds are established from published peer-reviewed colorimetric literature and will require batch calibration against the Narcotics Control Bureau’s specific chemical supplier lots.

### Final Pitch Statement
> *"The MHA Field Drug Testing Digital Companion is a calibration-first, offline-capable forensic evidence platform that transforms subjective chemical color changes into calibrated, mathematically verifiable presumptive test verdicts. By uniting live computer vision colorimetry, hardware-bound cryptographic chain of custody, out-of-band 2G SMS witnessing, and automated Panchanama document generation, the system ensures that field narcotics seizures withstand rigorous judicial scrutiny from the moment of interception to the final courtroom verdict."*
