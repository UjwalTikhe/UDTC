# Ministry of Home Affairs (MHA) — Digital Companion for Field Drug Testing
## Comprehensive Application Features & Technical Specification Document
**Problem Statement ID:** SIH26231  
**Statutory Compliance:** Narcotic Drugs and Psychotropic Substances (NDPS) Act, 1985 (§52A) & Bharatiya Sakshya Adhiniyam (BSA), 2023 (§63)  
**Design Standard:** Guidelines for Indian Government Websites (GIGW 3.0)  
**Target Platform:** Android (Flutter 3.x / Dart 3.x / Camera2 / SQLite)  
**Latest Release:** [GitHub Release: working apk final](https://github.com/UjwalTikhe/sih-field-drug-testing/releases/tag/working-apk-final)

---

## 1. Executive Summary

The **MHA Field Drug Testing Companion** is a mobile application engineered for field enforcement officers (Narcotics Control Bureau, State Police Anti-Narcotics Units, and Central Special Task Forces). It modernizes presumptive chemical drug testing by eliminating subjective human color interpretation, automating statutory legal compliance under **NDPS Act §52A**, and securing an unbroken, tamper-evident cryptographic digital chain of custody from seizure to laboratory submission.

The solution integrates device hardware sensors (real-time camera feed and GPS satellite receiver), edge-computed computer vision colorimetry (CIE $L^*a^*b^*$ and CIEDE2000 $\Delta E^*_{00}$), on-device cryptographic Merkle ledgers, and out-of-band 2G GSM SMS witness broadcasting for remote, zero-connectivity operations.

---

## 2. Core Functional Pillars & Features

```
+----------------------------------------------------------------------------------------------------+
|                                    MHA FIELD DRUG TESTING SYSTEM                                   |
+----------------------------------------------------------------------------------------------------+
|  1. HARDWARE SENSING         2. COMPUTER VISION COLORIMETRY      3. EVIDENCE & CHAIN OF CUSTODY   |
|  - Real Camera Sensor Stream - Laplacian Blur Gating (σ² > 100)  - SHA-256 Merkle Chain of Custody|
|  - Triple-Tier Resolution    - Bradford Chromatic Adaptation     - NDPS §52A Forensic Watermarking|
|  - Hardware Flashlight Control- sRGB -> CIE XYZ -> CIE L*a*b*     - On-Device Tamper Audit Tool    |
|  - High-Accuracy GPS Lock    - CIEDE2000 (ΔE*₀₀) Metric          - Dual-Officer ECDSA Signatures  |
|  - Auto-Focus & Auto-Exposure - Multi-Step Reagent Branching      - Offline 2G GSM SMS Witnessing  |
+----------------------------------------------------------------------------------------------------+
|  4. CHEMICAL KIT GATING      5. SECURITY & USER MANAGEMENT       6. GIGW 3.0 POLICE UI / UX       |
|  - NDDK / PCDK / KDK Assays  - PBKDF2/SHA-256 Salted Passwords   - Ashoka Navy Tactical Palette   |
|  - Kinetic Window Enforcement- Official Service ID Verification  - 100% Mobile Responsive Layout  |
|  - QR Reference Card Check   - Profile Personal Info (DOB/Gender)- 1-Tap Quick Action Shutter     |
|  - Kit Mismatch Lockout      - Device Hardware Key Binding       - 15 Distinct Purpose-Built Views|
+----------------------------------------------------------------------------------------------------+
```

---

### Feature Pillar 1: Hardware Sensing & Physical Camera Engine
- **Live Hardware Camera Stream**: Renders direct video stream from physical hardware camera sensors using the native Android Camera2 subsystem. Supports both primary rear lens and front camera with instant flip functionality.
- **Triple-Tier Automatic Resolution Negotiation**:
  1. Primary: `ResolutionPreset.high` (1080p high-resolution chromophore capture).
  2. Fallback: `ResolutionPreset.medium` (720p universal Android compatibility).
  3. Last Resort: `ResolutionPreset.low` (480p failsafe preventing hardware crashes).
- **Physical Flashlight / Torch Control**: Native flashlight toggling via hardware camera controller (`FlashMode.torch` / `FlashMode.off`) to ensure consistent lighting during night raids or low-light vehicle inspections.
- **Auto-Focus & Auto-Exposure Calibration**: Programmatic auto-focus and exposure lock calibration before shutter capture to eliminate artificial color shift from auto-white-balance hunting.
- **Live Camera Visual Feedback**: Viewfinder features a pulsing green `[● LIVE CAMERA ACTIVE]` indicator badge and real-time shutter state styling.
- **Direct System Settings Intent**: When runtime camera or location permissions are permanently denied, an in-app **"OPEN APP SETTINGS"** action immediately routes the officer to Android system settings via `openAppSettings()`.
- **1-Tap Instant Camera Launch**: The primary CTA on the Dashboard (*"START FIELD TEST (CAMERA & GPS)"*) bypasses secondary menus and launches the camera immediately.

---

### Feature Pillar 2: Forensic Real-Time GPS & Statutory Geotagging
- **High-Accuracy Real-Time GPS Tracking**: Connects to the device GPS satellite receiver, streaming high-precision latitude, longitude, and accuracy radius (e.g. `±3.2m`).
- **Permission Collision Elimination**: Camera sensor and GPS acquisitions are sequenced asynchronously to eliminate Android OS dialog clashes and prevent permission rejection.
- **NDPS §52A Statutory Forensic Watermark Burn-in**: Direct bitmap pixel-level stamping onto evidence photos:
  - Header: *MINISTRY OF HOME AFFAIRS • NDPS ACT §52A STATUTORY FORENSIC WATERMARK*
  - Test Metadata: Unique Test ID, Device ID, Officer Name & Badge Number
  - Coordinates: Latitude, Longitude, and GPS Satellite Accuracy
  - Timestamp: UTC and Indian Standard Time (IST) reaction timestamp
- **Accused Presence Witness Recording**: Toggle switch documenting whether the suspect/accused was present and witnessed the chemical reaction in accordance with statutory search and seizure mandates.

---

### Feature Pillar 3: Computer Vision & Optical Colorimetry Pipeline
- **Laplacian Focus Quality Gating**: Evaluates image sharpness using a Laplacian convolution kernel ($\sigma^2_{blur}$). Captures with $\sigma^2 < 100$ are flagged as blurry, preventing false positive identifications caused by motion blur.
- **Bradford Chromatic Adaptation**: White-point chromatic adaptation algorithm normalizes ambient lighting variations (incandescent, daylight, fluorescent) against known reference card patches.
- **Full Perceptual Color Space Conversion**:
  $$\text{sRGB} \xrightarrow{\text{Gamma Expansion}} \text{Linear RGB} \xrightarrow{\text{M Matrix}} \text{CIE XYZ (D65)} \xrightarrow{\text{Cube-Root Truncation}} \text{CIE } L^*a^*b^*$$
- **CIEDE2000 ($\Delta E^*_{00}$) Formulation**: Calculates standard color differences incorporating lightness compensation ($S_L$), chroma compensation ($S_C$), hue compensation ($S_H$), and the rotation term ($R_T$) to mirror human forensic visual perception.
- **Dynamic Multi-Spectral Confidence Formula**:
  $$\text{Confidence} = \left[ 1.0 - \frac{\Delta E^*_{00}}{35.0} \right] \times \left(1.0 - \text{BlurPenalty}\right) \times \text{KineticsFactor}$$
  Outputs realistic, legally defensible confidence percentages (typically $70\% - 98\%$).
- **Multi-Step Confirmatory Protocol Branching**: Supports sequential multi-reagent branching rules (e.g., Scott Reagent Step 1 cobalt thiocyanate $\rightarrow$ Step 2 hydrochloric acid clearing $\rightarrow$ Step 3 chloroform extraction blue layer).

---

### Feature Pillar 4: Chemical Test Kit Protocols & Assay Profiles
- **Pre-Configured Assay Profiles**:
  | Kit ID | Assay / Reagent Name | Target Substances | Kinetic Window | Expected Chromophore |
  | :--- | :--- | :--- | :--- | :--- |
  | **NDDK** | Marquis Reagent | Opium, Heroin, Morphine, Meth | 45 Seconds | Violet / Deep Purple |
  | **PCDK** | Duquenois-Levine | Cannabis, Ganja, Hashish, Charas | 60 Seconds | Indigo-Blue / Purple |
  | **KDK** | Scott Reagent (Modified) | Cocaine HCl, Freebase / Crack | 30 Seconds | Cobalt Blue |
- **Kit Mismatch Hardware Interlock**: Reference card QR scanner cross-checks card issuance serials against the selected kit assay. If an officer selects NDDK but scans a PCDK card, the app blocks the sequence with a high-visibility warning to prevent spoiled reagents.
- **Chemical Kinetic Window Timer**: Circular countdown timer that enforces chemical stabilization. Captures before the kinetic plateau are barred from submission under forensic standards.

---

### Feature Pillar 5: Cryptographic Chain of Custody & Offline SQLite Ledger
- **SHA-256 Merkle Chain**: Every test record is formatted into canonical JSON (§63 BSA standard) and hashed:
  $$\text{RecordHash} = \text{SHA-256}(\text{PrevHash} \parallel \text{CanonicalJSON} \parallel \text{ImageSHA-256})$$
- **On-Device Tamper Audit Tool**: One-tap verification scans all local database blocks from Genesis Hash (`000000...`) to the current top hash. Identifies any manual database alterations or record tampering.
- **Offline SQLite Architecture**: Zero reliance on cloud servers for critical capture operations. Records, signatures, watermarked photos, and audit logs are safely stored locally.
- **Staged Synchronization Service**: Queues records for upload to central MHA databases as soon as data connectivity is restored.

---

### Feature Pillar 6: Dual-Officer Witnessing & Offline 2G SMS Witnessing
- **Dual Digital Touch Signatures**: Touch signature pad capturing signatures from:
  1. Primary Seizing / Testing Officer
  2. Independent Witness Officer or Panch Witness
- **ECDSA Cryptographic Key Binding**: Generates digital signatures bound to officer credentials and device keystore hardware.
- **140-Character Compact 2G GSM SMS Witness Anchor**:
  - Format: `MHA|TestID|HashPrefix|BadgeNumber|ResultCode|Lat,Long`
  - Allows an officer operating in remote jungle, border, or maritime environments without 4G/5G data to transmit an out-of-band witness anchor via standard GSM SMS to the MHA dispatch server.

---

### Feature Pillar 7: Authentication, Security & Officer Profile Management
- **Salted & Hashed Local Authentication**: PBKDF2/SHA-256 password security with unique per-user salts.
- **Officer Profile Management**: Fields for Name, Badge Number, Rank, Unit, City, Department, Date of Birth (`dob`), Gender, and Contact Phone.
- **Official Service ID Verification Workflow**:
  - Officers can enter their official Department Service ID to verify credentials.
  - Updates profile status from `VERIFY NOW` (amber) to `VERIFIED` (green) across all app headers and reports.
- **Hardware Device Binding**: Records device serials and hardware fingerprints to prevent credential sharing across unauthorized devices.
- **In-App Password Modification**: Allows officers to update passwords securely on-device.

---

## 3. Screen Inventory & User Navigation Flow

```
[SplashScreen]
      |
[LoginScreen]
      |
[DashboardScreen] <---------------------------------------------+
   |           |                                                |
   | (1-Tap)   | (Guided 6-Step Protocol)                       |
   |           v                                                |
   |      [KitSelectionScreen] (Step 1: Select Assay)           |
   |           |                                                |
   |           v                                                |
   |      [CardScanScreen] (Step 2: Authenticate Reference Card)|
   |           |                                                |
   |           v                                                |
   |      [ReactionTimerScreen] (Step 3: Kinetic Stabilization) |
   |           |                                                |
   +---> [CameraCaptureScreen] (Step 4: Live Viewfinder & GPS)   |
               |                                                |
         [EvidenceReviewModal]                                  |
               |                                                |
         [ProcessingScreen] (Step 5: Colorimetry Pipeline)      |
               |                                                |
         [ResultScreen] (Step 6: Forensic Verdict)              |
               |                                                |
         [DualSigningScreen] (NDPS §52A Witness Signatures)     |
               |                                                |
         [RecordConfirmScreen] (Commit to Merkle Chain) --------+
```

### Detailed Screen Specifications

| # | Screen Name | File Path | Key Functions & Capabilities |
| :-: | :--- | :--- | :--- |
| **1** | **Splash Screen** | `lib/screens/splash_screen.dart` | Government branding, database integrity boot-check, automatic session restoration. |
| **2** | **Login Screen** | `lib/screens/login_screen.dart` | Email/password sign-in/up, salt generation, demo officer quick-fill buttons. |
| **3** | **Dashboard Screen** | `lib/screens/dashboard_screen.dart` | Profile summary with verified badge, 1-tap capture CTA, guided protocol CTA, ledger summary, recent records, manual sync trigger. |
| **4** | **Kit Selection Screen** | `lib/screens/kit_selection_screen.dart` | Step 1: Select between NDDK, PCDK, and KDK assays with details on reagents and kinetic windows. |
| **5** | **Card Scan Screen** | `lib/screens/card_scan_screen.dart` | Step 2: Live camera viewfinder scanning MHA reference card QR code with 3-frame debounce and kit mismatch blocker. |
| **6** | **Reaction Timer Screen** | `lib/screens/reaction_timer_screen.dart` | Step 3: Countdown stabilization ring; enforces optimal reaction window before capture is allowed. |
| **7** | **Camera Capture Screen** | `lib/screens/camera_capture_screen.dart` | Step 4: Hardware camera feed, live GPS lock strip, suspected drug chip selector, flashlight toggle, reticle, and shutter button. |
| **8** | **Evidence Review Modal** | `lib/screens/camera_capture_screen.dart#L367` | Pre-analysis review showing watermarked photo, coordinates, and accused presence toggle. |
| **9** | **Processing Screen** | `lib/screens/processing_screen.dart` | Step 5: Real-time animated 4-stage computer vision diagnostic inspection. |
| **10** | **Result Screen** | `lib/screens/result_screen.dart` | Step 6: Classification verdict (POS/NEG/INC), Lab coordinates, $\Delta E^*_{00}$, confidence score, legal preview. |
| **11** | **Dual Signing Screen** | `lib/screens/dual_signing_screen.dart` | Testing officer and witness touch signature pads; generates 140-char 2G SMS anchor string. |
| **12** | **Record Confirm Screen** | `lib/screens/record_confirm_screen.dart` | Review metadata and commit record into SQLite Merkle chain. |
| **13** | **Record Detail Screen** | `lib/screens/record_detail_screen.dart` | Detailed forensic audit card, watermarked image viewer, Section 52A legal certificate export. |
| **14** | **History & Audit Screen** | `lib/screens/history_screen.dart` | Filterable test log, keyword search, and on-device blockchain integrity verification. |
| **15** | **Profile Settings Screen** | `lib/screens/profile_settings_screen.dart` | Officer profile editing (DOB, Gender), Service ID verification flow, change password, device binding info, and logout. |

---

## 4. Government Design System (GIGW 3.0) & Police UX

- **National Palette**:
  - **Ashoka Chakra Navy (`#0A192F`)**: Primary app bar and structural framework.
  - **Tricolor Saffron (`#FF9933`)**: Accent alerts, reticles, and focus zones.
  - **Tiranga Green (`#138808`)**: Verified badges, locked GPS indicators, and negative result indicators.
  - **Forensic Alert Red (`#D32F2F`)**: Positive presumptive identification callouts.
- **Night-Mode High Contrast**: Deep dark slate surfaces (`#111827` / `#1E293B`) optimized for night operations, glare reduction, and battery efficiency.
- **Zero Overflow Mobile-Responsive Layout**: All containers, dialogs, and text spans use bounded constraints, scroll physics, and responsive paddings to fit mobile screen aspect ratios without layout overflow warnings.

---

## 5. Verification & Testing Artifacts

- **Optical Unit Tests (`test/optical_processing_test.dart`)**:
  - `OpticalProcessingService processes positive field sample image`: Passed ($\Delta E^*_{00} = 9.08$, Confidence: $74.1\%$).
  - `OpticalProcessingService processes negative field sample image`: Passed ($\Delta E^*_{00} = 6.4$, Confidence: $76.3\%$).
  - `OpticalProcessingService visibly reduces confidence on blurry sample image`: Passed (Sharp Laplacian: $3715.37$ vs Blurry Laplacian: $45.79$; Confidence drops from $76.3\%$ to $53.8\%$).
- **Flutter Analyzer**: 0 compilation or fatal errors across the entire codebase.
- **Release APK**: Built with release optimizations and tree-shaken icons (`65.0 MB`).
- **Download Link**: [app-release.apk on GitHub](https://github.com/UjwalTikhe/sih-field-drug-testing/releases/download/working-apk-final/app-release.apk)
