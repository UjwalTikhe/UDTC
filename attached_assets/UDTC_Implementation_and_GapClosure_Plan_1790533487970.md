# UDTC → SIH26231 Implementation & Gap-Closure Plan
### Turning `github.com/UjwalTikhe/UDTC` into the app described in the Unified Master Project Plan
**Prepared for:** Team UDTC (5 members) · **Problem Statement:** SIH26231 · **Budget:** ₹0

---

## 0. Read This First — How This Document Was Built (Be Honest With Yourself Too)

I compared two things:

1. **"The Sky"** — your Unified Master Project Plan (the spec you pasted: architecture, domain model, 15 screens, GIGW colours, security threat map, 8-phase roadmap).
2. **"The Ground"** — your actual repo at `github.com/UjwalTikhe/UDTC`.

What I could verify on the ground:
- Root repo structure: `backend/`, `card_assets/`, `demo_suite/`, `engine/`, `mobile_app/`, `security/`, `sync_mesh/`, `tests/`, `.github/workflows/`, plus several planning docs (`APP_FEATURES.md`, `APP_DESIGN_SYSTEM_AND_PROMPTS.md`, `UNIFIED_MASTER_PROJECT_PLAN.md`, PDFs, `requirements.txt`).
- `APP_FEATURES.md` — a detailed features doc that reads like it documents an **already-working app**, with a real file-path table (`lib/screens/*.dart`) and specific test numbers (ΔE = 9.08, Laplacian variance 3715.37 vs 45.79, etc.).
- `APP_DESIGN_SYSTEM_AND_PROMPTS.md` — your own 15-screen design system and build prompts, almost a mirror of the Master Plan.
- A **real GitHub Release**, tag `working-apk-final`, released **today**, described as containing "live hardware camera sensor integration, real-time GPS geotagging, CIE Lab colorimetric analysis, and NDPS Section 52A digital chain-of-custody."

What I **could not** verify directly: the actual contents of `.dart` files inside `mobile_app/lib/`, or the code in `engine/`, `security/`, `sync_mesh/`, `backend/`. GitHub's robots rules block automated folder crawling of `/tree/...` paths for this tool, and I can't guess file names that were never shown to me.

**What this means for you:** this plan is built on your own documentation plus sound engineering judgment about what a repo at this stage typically looks like. Section 15 (Appendix B) tells you exactly what to paste back to me so the next pass can be byte-exact instead of doc-based. Until then, **treat every 🟢 in this document as "very likely true, verify once," not "confirmed."**

### Colour-Coding Legend (used everywhere below)
| Symbol | Meaning |
|---|---|
| 🟢 **GREEN** | Strong evidence this already exists / matches the Master Plan |
| 🟡 **AMBER** | Partially there, or exists but unverified — needs an audit pass |
| 🔴 **RED** | Missing, or contradicted by evidence — must be built |
| 🔵 **BLUE** | Stretch goal — nice for judging, not required for MVP |
| ⚫ **BLACK** | Legal / compliance gate — non-negotiable, blocks demo/submission if failing |

---

## 1. The One-Paragraph Verdict

Your planning documentation is **unusually strong** — most SIH teams don't have anything close to this level of spec. The real risk isn't "we don't know what to build," it's three quieter things: (a) your own Master Plan's **"Step 0: Total Removal of Demo Logic"** exists because somewhere in the current build there is probably still a stub or two — find them before a judge does; (b) your **three internal documents disagree with each other** on colours and on which screens actually exist (details below) — that inconsistency will show up on stage; (c) two screens the Master Plan requires (**Sync Status**, **Approval Queue**) are missing from the feature doc that reads like it documents the shipped APK.

None of this is bad news. It's a short, specific punch list. Let's go through it.

---

## 2. Executive Gap Matrix — "Ground" vs "Sky"

| # | Area | Master Plan Requires ("Sky") | Repo Evidence ("Ground") | Status | Priority |
|---|---|---|---|---|---|
| 1 | Demo-stub removal | Zero code paths that fake a result | Not verifiable from docs — this is exactly what Step 0 warns about | 🟡 | 🔴 Do first |
| 2 | Camera + burst capture | `camera` plugin, 4–5 frame burst, disposal discipline | APP_FEATURES.md describes live Camera2 stream, triple-tier resolution, flashlight, auto-focus lock | 🟢 | — |
| 3 | GPS + fail-open/fail-closed rule | Geolocator, 5s timeout, `locationConfirmed=false` on failure | Explicitly described in APP_FEATURES.md ("Fail Open on Capture, Fail Closed on Trust") | 🟢 | — |
| 4 | ArUco marker detection | 4-corner fiducials via OpenCV | Not explicitly confirmed — APP_FEATURES.md talks about the *card scan QR*, but doesn't clearly confirm ArUco corner detection is wired into the *capture* screen's reticle | 🟡 | 🔴 High |
| 5 | Laplacian blur gate (σ²>100) | Hard block on capture | Confirmed in both docs and unit test numbers (3715 vs 45.79) | 🟢 | — |
| 6 | Bradford white-balance + sRGB→Lab→ΔE2000 | Full pipeline on isolate via `compute()` | Confirmed described; isolate usage (`compute()`) not directly confirmed | 🟡 | 🔴 High |
| 7 | Dynamic confidence formula | Must visibly change on blur/sharp | Confirmed with real numbers (76.3%→53.8% on blur) | 🟢 | — |
| 8 | Interferent lookup (Levamisole etc.) | Attach warnings to result | Mentioned in Master Plan; not explicitly confirmed in APP_FEATURES.md | 🟡 | 🟡 Medium |
| 9 | Kit mismatch interlock (NDDK/PCDK/KDK vs card) | Hard block | Confirmed in both docs | 🟢 | — |
| 10 | 3-frame QR debounce | Confirmed | Confirmed in both docs | 🟢 | — |
| 11 | SQLite + SQLCipher encrypted ledger | AES-256 at rest | Mentioned; SQLCipher-specific wiring not confirmed (plain `sqflite` ≠ encrypted) | 🟡 | 🔴 High |
| 12 | SHA-256 hash chain (`H[n]=SHA256(H[n-1]+Data[n])`) | Append-only, tamper-detectable | Confirmed described, incl. "Tamper Audit Tool" | 🟢 | — |
| 13 | Dual ECDSA P-256 signatures (device + officer) | Both required to seal a record | Confirmed described (Keystore + PIN-derived) | 🟢 | — |
| 14 | 140-char 2G SMS witness anchor | Real `SmsManager` dispatch | Confirmed described with exact payload format | 🟢 | — |
| 15 | Staged Firebase sync (metadata → media) | Two-stage upload | Mentioned; not confirmed wired end-to-end | 🟡 | 🟡 Medium |
| 16 | Merkle root batching (server-side) | Scheduled Cloud Function | Not confirmed anywhere in the feature doc | 🔴 | 🟡 Medium (post-MVP OK) |
| 17 | 15-screen inventory | Splash → Login → Dashboard → Kit → Card Scan → Timer → Capture → Processing → Result → Record Confirm → History → Record Detail → **Sync Status** → **Approval Queue** → Profile | APP_FEATURES.md's own screen table (which reads like it documents the shipped app) lists **Dual Signing Screen** instead of Sync Status/Approval Queue — those two are **absent** from that table | 🔴 | 🔴 **Critical — see §2a** |
| 18 | Supervisor co-signing on high-stakes seizures | Explicit screen + ECDSA co-sign + audit log entry | No evidence this exists yet | 🔴 | 🔴 High (it's also a named threat mitigation) |
| 19 | Panchanama 10-section data module | Full structured dossier | Not directly confirmed; likely partially covered by Record Confirm fields | 🟡 | 🔴 High |
| 20 | 6-page Panchanama PDF export | `pdf`/`printing` packages, court-ready | "Export BSA §63 Certificate" mentioned; full 6-page Panchanama structure not confirmed | 🟡 | 🔴 High |
| 21 | Section 63 BSA integrity certificate | Hashes + signatures + chain status, printable | Conceptually present; PDF rendering not confirmed | 🟡 | 🔴 High |
| 22 | Colour token consistency | One canonical hex set everywhere | **Three different navy hexes across 3 of your own docs** — see §2b | 🔴 | 🔴 **Fix before any more UI work** |
| 23 | WCAG 2.1 AA contrast | ≥4.5:1 body text | Numbers are asserted in docs but should be independently re-checked once the final palette is locked | 🟡 | ⚫ Gate |
| 24 | Non-dismissible legal disclaimer everywhere | On every result screen, PDF, certificate | Described as present on Result Screen; not confirmed on PDF/certificate | 🟡 | ⚫ Gate |
| 25 | Admin/Auditor kept off mobile | Web-console only | Explicitly designed this way in both docs — good | 🟢 | — |
| 26 | Backend stack | Firebase Spark free tier (or Supabase) | Repo has a `backend/` folder **and** a Python `requirements.txt` — this doesn't match a Firebase-only plan. Needs clarification — see §9 | 🟡 | 🟡 Medium |
| 27 | Offline mesh (BLE / Wi-Fi Direct) | *Not in the Master Plan you pasted at all* | Mentioned in your own `SyncStatusScreen` prompt ("Tactical Mesh Status card... BLE / Wi-Fi Direct") | 🔵 | 🔵 Stretch — don't let this eat MVP time |
| 28 | Export watermarking (LSB/DCT) + `FLAG_SECURE` | Anti-leak protection | Watermark burn-in (visible NDPS §52A stamp) confirmed; invisible tracking watermark + `FLAG_SECURE` screenshot block not confirmed | 🟡 | 🟡 Medium |
| 29 | Domain accuracy of kit naming | — | See §2c — "PCDK" labelling issue | 🟡 | ⚫ Gate (credibility risk with judges) |

### 2a. 🔴 Critical finding — screen count mismatch between your own two docs
Your `APP_DESIGN_SYSTEM_AND_PROMPTS.md` 15-screen table matches the Master Plan exactly: it includes **#13 Sync Status Screen** and **#14 Approval Queue Screen**.
Your `APP_FEATURES.md` screen table — which reads like documentation of the actual shipped APK — has **15 rows too, but swaps those two out** for a standalone **#11 Dual Signing Screen**.

Two honest possibilities:
- The shipped app folded signing into Record Confirm (fine) but **never built** Sync Status / Approval Queue as real screens, and `APP_FEATURES.md` just describes what's real.
- Or `APP_FEATURES.md` is slightly stale and those screens do exist but weren't documented.

Either way — **you don't currently know for certain**, and neither do I. This is priority #1 to resolve (see Phase 6 / Screen Checklist §8).

### 2b. 🔴 Colour drift across your own three documents
| Document | "Primary Navy" hex |
|---|---|
| Master Plan (pasted to me) | `#1E4B8F` (called just "primary") |
| `APP_FEATURES.md` | `#0A192F` (called "Ashoka Chakra Navy") |
| `APP_DESIGN_SYSTEM_AND_PROMPTS.md` | `#0A2558` (called "ashokaNavy") |

Three different hex values for what is supposed to be the *same* national-identity colour, across three documents you personally maintain. If three different screens were built by three different AI prompts on three different days, there's a real chance your app bar isn't visually consistent right now. **Section 5 below gives you one final canonical palette and a single Dart file to make this impossible to drift again.**

### 2c. 🟡 Domain-accuracy flag — worth 5 minutes with your mentor before final submission
Your Kit 2, "**PCDK — Precursor Chemicals Detection Kit**," is described everywhere as using the **Duquenois-Levine reagent**. Duquenois-Levine is conventionally documented in forensic literature as a **cannabinoid (cannabis/hashish) presumptive test**, not a precursor-chemical test (precursor testing — e.g. for acetic anhydride or safrole — normally uses different reagent chemistry entirely). Your own `APP_FEATURES.md` kit table actually lists PCDK's target substances as "Cannabis, Ganja, Hashish, Charas" — which **contradicts the kit's own name**. If an NCB domain reviewer or judge with a chemistry background looks closely, "Precursor Chemicals Detection Kit" running a cannabinoid reagent against cannabis samples will read as a labelling error, not a feature. Recommend: rename the kit to reflect what it actually detects (e.g. "Cannabinoid Detection Kit") unless your domain mentor confirms there's a specific precursor-testing protocol I'm not aware of. This is a two-line fix, but it's the kind of thing that quietly undermines credibility if left in.

---

## 3. Absolute-Beginner Environment Setup (Day 0)

If any of your 5 members haven't set up Flutter yet, do this once, together, on a call.

### Step-by-step
1. **Install Git**: [git-scm.com](https://git-scm.com) → default install.
2. **Install Flutter SDK**: follow [docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) for your OS. Add Flutter to your system PATH.
3. **Install Android Studio** (needed even if you use VS Code, because it ships the Android SDK, platform tools, and an emulator).
4. **Install VS Code** + extensions: `Flutter`, `Dart`.
5. Open a terminal and run:
   ```bash
   flutter doctor
   ```
   Fix every ❌ it shows (usually: accept Android licenses with `flutter doctor --android-licenses`, or install a missing SDK component).
6. **Clone the repo**:
   ```bash
   git clone https://github.com/UjwalTikhe/UDTC.git
   cd UDTC/mobile_app
   ```
7. **Install dependencies**:
   ```bash
   flutter pub get
   ```
8. **Connect a real Android phone** (enable Developer Options → USB Debugging) — strongly preferred over an emulator for this project, because camera + GPS + SMS are hardware-real features an emulator fakes badly.
9. **Run it**:
   ```bash
   flutter run
   ```
10. If `backend/` has a Python component (it appears to, given `requirements.txt`):
    ```bash
    cd ../backend
    python -m venv venv
    source venv/bin/activate   # venv\Scripts\activate on Windows
    pip install -r ../requirements.txt
    ```

**Don't skip this step even if you're "the PM."** Every person on the team should be able to run the app on their own phone once. It removes "works on my machine" surprises three days before demo day.

---

## 4. STEP 0 (Mandatory, Do This Before Writing Any New Feature): Self-Audit for Demo Stubs

This directly implements your own Master Plan §4 Step 0 and Guiding Principle #2 ("Fail Closed"). Run these searches inside `mobile_app/lib/` and `engine/`:

```bash
# From inside mobile_app/
grep -rn "Random(" lib/
grep -rn "Future.delayed" lib/
grep -rn -i "mock\|dummy\|fake\|stub\|placeholder" lib/
grep -rn "TODO\|FIXME" lib/
grep -rn "return true;" lib/ | grep -v test
grep -rn "0.874\|0.741\|9.08\b" lib/    # hardcoded confidence/deltaE values pasted straight into UI code instead of computed
```

**What a red flag looks like in real code:**
```dart
// 🔴 RED FLAG — fake result generator
Future<ClassificationResult> classify(...) async {
  await Future.delayed(Duration(seconds: 2));
  final rand = Random();
  return ClassificationResult(
    category: rand.nextBool() ? ResultCategory.positive : ResultCategory.negative,
    confidence: 70 + rand.nextDouble() * 20,
    interferentWarnings: [],
  );
}
```
```dart
// 🟢 GREEN — real pipeline
Future<ClassificationResult> classify(CapturedFrame frame, KitType kit) {
  return compute(_classifyOnIsolate, _ClassifyInput(frame, kit));
}
```

**Fill this in as a team, honestly, before Phase 1 starts:**

| File | Contains real CV/crypto logic? | Evidence | Colour |
|---|---|---|---|
| `lib/services/calibration_engine.dart` (or similar) | ? | ? | 🟡 until checked |
| `lib/services/hash_chain_service.dart` (or similar) | ? | ? | 🟡 until checked |
| `lib/screens/camera_capture_screen.dart` | ? | ? | 🟡 until checked |
| `lib/screens/processing_screen.dart` | ? | ? | 🟡 until checked |
| `lib/screens/result_screen.dart` | ? | ? | 🟡 until checked |

If you find even one `Random()`-based fake, that's fine — that's exactly what this step exists to catch, this early, not on stage.

---

## 5. Canonical Colour System — Fix the Drift First

Before any more screens get built or fixed, lock ONE palette. Put this in a single file so nothing can drift again.

### 5.1 Final Canonical Palette (pick this, update your docs to match)
| Token | Hex | Use | Contrast |
|---|---|---|---|
| `bg.base` | `#F7F9FC` | App background | 15.65:1 |
| `bg.surface` | `#FFFFFF` | Cards, sheets | — |
| `text.primary` | `#1A1F29` | Headings, body | 15.65:1 |
| `text.secondary` | `#5B6472` | Captions, metadata | ~4.6:1 (≥14sp) |
| `border.default` | `#E1E5EB` | Dividers, borders | non-text |
| `primary` (Ashoka Navy) | `#1E4B8F` | Buttons, app bar, headers — **pick this one, retire the other two hexes** | 8.55:1 |
| `primary.pressed` | `#163765` | Pressed state | — |
| `secondary` | `#445266` | Outlined buttons | — |
| `sovereign.saffron` | `#FF9933` | Thin tricolor accent stripe only — never body text/buttons | — |
| `sovereign.green` | `#138808` | Thin tricolor accent stripe only — never as a "success" colour (that would break the non-traffic-light rule) | — |

### 5.2 Status Colours (never colour alone — always Colour + Icon + Text)
| Result | Background | Text/Icon | Contrast | Icon |
|---|---|---|---|---|
| 🔴 Positive (Contraband Alert) | `#FDECEA` | `#B3261E` | 5.71:1 | ⚠/✕ |
| 🟢 Negative (Clear) | `#E8F5E9` | `#1B6E2F` | 5.62:1 | ✓ |
| 🟡 Inconclusive (Retest) | `#FFF4E0` | `#9E5B00` | 4.88:1 | ! |

### 5.3 Typography (Major Third, 1.25 ratio)
`display` 28sp/800 · `title` 22sp/700 · `subtitle` 18sp/600 · `body` 16sp/400 · `caption` 13sp/500 · `codeHash` 11sp monospace/600 (for hashes/signatures)

### 5.4 Spacing & Touch Targets
8dp grid (4/8/16/24/32/40/48dp) · min touch target 48×48dp · CTA height 56dp, full width minus 32dp margins · capture shutter 72dp circular, 32dp above safe area.

### 🤖 Prompt — Create the Single Source of Truth Theme File
```text
Create (or refactor if it already exists) a single Dart file at lib/theme/app_colors.dart
that is the ONLY place color hex values are ever hardcoded in this entire project.

Requirements:
1. A class AppColors with static const Color fields for every token below. Use EXACTLY
   these hex values — do not introduce new ones:
   bgBase=#F7F9FC, bgSurface=#FFFFFF, textPrimary=#1A1F29, textSecondary=#5B6472,
   borderDefault=#E1E5EB, primary=#1E4B8F, primaryPressed=#163765, secondary=#445266,
   sovereignSaffron=#FF9933, sovereignGreen=#138808,
   positiveBg=#FDECEA, positiveText=#B3261E,
   negativeBg=#E8F5E9, negativeText=#1B6E2F,
   inconclusiveBg=#FFF4E0, inconclusiveText=#9E5B00.
2. Search the entire lib/ folder for any other hardcoded hex color (Color(0x...) or
   Color.fromRGBO or literal hex strings) and replace every one of them with a reference
   to AppColors, including any occurrences of #0A192F or #0A2558 (retire both — they are
   duplicates of AppColors.primary and must not remain anywhere in the codebase).
3. Build a matching lib/theme/app_text_styles.dart with the 6-step type scale
   (display 28sp/800, title 22sp/700, subtitle 18sp/600, body 16sp/400, caption 13sp/500,
   codeHash 11sp monospace/600), and lib/theme/app_spacing.dart with named constants for
   4,8,16,24,32,40,48dp.
4. Print a list of every file you changed so I can review the diff.
```

---

## 6. Why Phases 1–2 Come First (Build Order Rule)

Straight from your own Master Plan: **the colorimetry pipeline has zero backend dependency and is the single strongest demo moment** — turning a bad-lighting photo into an objective, numeric verdict live on stage. Cryptographic ledger, sync, and SMS are all meaningless if the underlying verdict isn't trustworthy yet. So: **Capture → Colorimetry → Ledger → Sync → SMS/Merkle → Roles/Legal → Testing → Deck.**

---

## 7. Phase-by-Phase Plan

Each phase below has: 🎯 Goal · 🔎 Audit First · ✅ Definition of Done · 🤖 Prompts · 👥 Suggested Owner (per your 5-person table).

### Phase 0 — Setup & Stub Audit *(new — do this before Phase 1)*
- 🎯 Everyone can run the app; Step-0 grep audit is complete and logged.
- ✅ DoD: `flutter run` works on every team member's machine · Section 4 table filled in honestly · one shared doc/spreadsheet tracking 🟢🟡🔴 per file.
- 👥 Whole team, 1 session, before anyone touches feature code.

### Phase 1 — Capture Pipeline 🔴 High priority
- 🎯 Real camera + GPS + quality gating, no stubs.
- 🔎 Audit: does `camera_capture_screen.dart` actually run ArUco marker detection every ~200–250ms, or does it just always show a green reticle? Does the shutter button's `disabled` state genuinely depend on a live boolean, or is it hardcoded `enabled: true`?
- ✅ DoD: shutter is provably disabled on blur (test with a deliberately shaky photo) · GPS timeout at 5s sets `locationConfirmed=false` and does **not** block capture · burst of 4 frames captured, worst 3 disposed immediately (check with a memory profiler that you're not leaking `Uint8List`s).
- 🤖 Prompt:
```text
Open lib/screens/camera_capture_screen.dart. Do NOT rewrite it from scratch — audit it
against this checklist and fix only what's broken:
1. Confirm CameraController is created in initState() and disposed in dispose(). If a
   StatefulWidget holds a CameraController without disposing it, fix that first.
2. Confirm there is a real repeating Timer or camera image-stream listener running every
   200-250ms that calls into an ArUco-detection function and a Laplacian-blur function,
   and that the capture button's `onPressed` is genuinely null (disabled) unless BOTH
   checks currently pass. If the button is always enabled, or the checks are computed but
   never actually gate the button, fix that — this is a forensic requirement, not cosmetic.
3. Confirm burst capture takes exactly 4 frames over ~400ms, picks the best one (least
   specular highlight / least blur), and explicitly disposes/discards the other 3 (set
   references to null, don't just let them go out of scope if they're native buffers).
4. Confirm GPS: geolocator call wrapped in a 5-second timeout; on timeout or permission
   denial, proceed with capture but set locationConfirmed=false on the CaptureResult.
   Never let a GPS failure block the shutter.
5. Report a short list of what was already correct vs what you changed.
```
- 👥 Builder 1 + Researcher A

### Phase 2 — Colorimetry Engine 🔴 Highest priority (your strongest demo beat)
- 🎯 Deterministic sRGB→Lab→CIEDE2000 pipeline, running off the UI thread, with a confidence score that visibly reacts to image quality.
- 🔎 Audit: search for `compute(` in your engine file. If it's absent, the pipeline is running on the main isolate and **will** cause a visible UI freeze during a live demo — this alone could sink a demo.
- ✅ DoD: same chemical sample, sharp photo vs blurry photo → two different confidence numbers (you already seem to have this per your test doc — verify it's the real pipeline producing those numbers, not a lookup table) · interferent warnings actually attach to the result object, not just exist as a static list somewhere unused.
- 🤖 Prompt:
```text
Audit the colorimetry/classification engine (likely in lib/services/ or engine/).
Checklist — fix only what's missing, do not restructure what's already correct:
1. Confirm the classify() function is invoked via Dart's compute() (isolate), not awaited
   directly on the UI/main isolate. If it's on the main isolate, wrap it in compute() and
   make sure the input/output types are simple, isolate-safe objects (no closures, no
   BuildContext).
2. Confirm the pipeline genuinely does: ArUco corner detection -> grayscale patch sampling
   for a Bradford-style white-balance correction matrix -> apply correction to the reaction
   zone -> sRGB to CIE Lab (D65) -> CIEDE2000 distance against the kit's reference profile ->
   threshold into positive/negative/inconclusive. If any step is skipped and a hardcoded or
   randomly-perturbed deltaE is used instead, replace it with the real computation.
3. Confirm confidence = f(deltaE margin from threshold, Laplacian blur score, ArUco
   detection confidence) and that changing image sharpness measurably changes the output
   confidence on the same color sample. Write or update a unit test proving this with two
   images of the same color at different Laplacian variances.
4. Confirm an interferent lookup table (Levamisole, Lidocaine, Procaine, etc. per kit type)
   is actually consulted and its warnings are attached to ClassificationResult.interferentWarnings,
   not just declared and unused.
5. List every step above that was already correctly implemented vs anything you had to fix.
```
- 👥 Builder 1 + Researcher A

### Phase 3 — Cryptographic Ledger 🔴 High priority
- 🎯 Encrypted local storage, real append-only hash chain, dual ECDSA signatures.
- 🔎 Audit: is the SQLite DB actually opened with SQLCipher (encrypted), or is it plain `sqflite` (unencrypted on disk)? This matters a lot for a government submission — an unencrypted evidence DB is a real weakness, not a cosmetic one.
- ✅ DoD: deliberately editing one byte in a stored record and running your own "verify chain" function correctly reports the exact broken block index · both device-key and officer-key signatures are present and independently verifiable · genesis hash is `000...0`.
- 🤖 Prompt:
```text
Audit the local persistence and ledger layer (likely lib/services/ledger_service.dart or
similar, plus wherever the SQLite database is opened).
1. Confirm the database is opened via sqlcipher_flutter_libs with a real encryption
   passphrase (sourced from flutter_secure_storage, never hardcoded), not plain sqflite.
   If it's plain sqflite, migrate it to the encrypted variant and write a short migration
   note for existing test data.
2. Confirm every new TestRecord computes recordHash = SHA256(prevHash + canonicalJson +
   imageHash) and that prevHash is read from the actual last row in the table (not a
   constant). Confirm the very first record in a fresh database uses a genesis hash of
   64 zero characters.
3. Implement (or verify) a HashChain.verify() function that walks every row from genesis to
   head, recomputing each hash, and returns the exact index of the first mismatch if the
   chain is broken. Write a test that flips one character in one stored record and asserts
   verify() correctly names that block.
4. Confirm both a device-bound ECDSA P-256 signature (Android Keystore/StrongBox,
   non-exportable) and an officer PIN-derived ECDSA signature are computed and stored per
   record, and that creating a record with only one of the two signatures is not possible
   through the UI.
5. Report which parts were already implemented correctly vs what needed fixing.
```
- 👥 Builder 2 + Researcher B

### Phase 4 — Offline Queue & Cloud Sync 🟡 Medium priority
- 🎯 Staged sync: metadata first (small, instant), then media (large, when bandwidth allows).
- ✅ DoD: turning on airplane mode never crashes or blocks record creation · records marked `pending` sync correctly and retry when connectivity returns.
- 🤖 Prompt:
```text
Audit or build the staged sync engine. Requirements:
1. Two-stage upload: Stage 1 uploads only the small JSON metadata document to
   Firestore (tests/{testId}). Stage 2, only after Stage 1 succeeds, uploads the
   watermarked image(s) to Firebase Storage (records/{testId}/frame_{n}.jpg).
2. A connectivity listener that automatically retries pending records when the network
   returns, without user action, but also exposes a manual "Sync Now" button.
3. Never block record creation, viewing, or export on network availability. Airplane
   mode must be a fully supported operating condition, not a degraded one for anything
   except the actual upload step.
4. Add exponential backoff (not infinite rapid retry) for failed sync attempts.
```
- 👥 Builder 2

### Phase 5 — SMS Witness + Merkle Batching 🟡 Medium priority
- 🎯 Out-of-band 2G witness anchor, independent of the internet-based sync above.
- ✅ DoD: SMS payload is exactly ≤140 chars and matches the format `MHA|id|hashPrefix|badge|RESULT|lat,long` · sending SMS never depends on internet connectivity.
- 🤖 Prompt:
```text
Audit or build the 2G SMS witness anchor.
1. Confirm toGsmSmsPayload() produces a string that is verifiably <=140 characters
   for realistic data (long badge numbers, negative coordinates, etc.) — add a unit
   test with edge-case inputs, not just the happy path.
2. Confirm the SMS is dispatched via native SmsManager (telephony or flutter_sms
   plugin) directly over the SIM, with no dependency on Wi-Fi/mobile data.
3. Add a retry/outbox mechanism for SMS that fail to send (e.g. no SIM, airplane mode)
   so they are not silently lost, and surface pending SMS count somewhere visible
   (this is what the Sync Status screen is for — see Phase 6).
4. Merkle batching on the server side (Cloud Function folding recent hashes into a
   root) is lower priority than the on-device pieces above — implement only if time
   permits after Phases 1-3 and the screen gaps in Phase 6 are closed.
```
- 👥 Builder 2

### Phase 6 — Close the Screen Gap + Roles + BSA §63 + Panchanama 🔴 Critical (this is where the 2 missing screens live)
- 🎯 Resolve the Sync Status / Approval Queue / Dual Signing ambiguity from §2a. Build whichever of these is genuinely missing. Wire Panchanama PDF export.
- 🔎 Audit first: literally open the app and count the screens. Does tapping through the guided flow ever show a Supervisor co-signing queue? Is there a dedicated Sync Status screen, or is sync status just a chip on the Dashboard?
- ✅ DoD: all of Splash, Login, Dashboard, Kit Selection, Card Scan, Reaction Timer, Capture, Processing, Result, Record Confirm (with dual signing), History, Record Detail, **Sync Status**, **Approval Queue** (Supervisor-only), Profile exist as real, navigable screens · Panchanama PDF exports 5-6 pages matching the Master Plan's structure · BSA §63 certificate page includes both signatures, both hashes, and chain-verification status.
- 🤖 Prompts:
```text
PROMPT A — Approval Queue Screen (build if missing):
Build a Flutter screen ApprovalQueueScreen, visible only when the logged-in user's Role
is supervisor. Requirements:
1. Banner: "SUPERVISOR AUTHORIZATION ACTIVE - Section 52A NDPS Approval Authority".
2. Query and list all TestRecord rows with result.category == positive that are flagged
   as high-stakes/commercial-quantity (add a boolean isHighStakes to TestRecord if it
   doesn't exist yet, settable on Record Confirm).
3. Each list item shows officer badge, deltaE, confidence, truncated record hash, and a
   "Co-Sign" button.
4. Co-Sign generates a supervisor ECDSA P-256 signature over the testId, appends an
   AuditLogEntry with action=sign, and shows a confirmation dialog before committing.
5. Do not allow a supervisor to co-sign their own submitted test (compare officer.userId
   to the logged-in supervisor's userId and block with a clear message if they match).
```
```text
PROMPT B — Sync Status Screen (build if missing):
Build a Flutter screen SyncStatusScreen, visible to all roles. Requirements:
1. Three status cards: Tier 1 "Local Encrypted Database" (always green/active),
   Tier 2 "2G SMS Witness Outbox" (count of pending SMS, "Flush Now" button),
   Tier 3 "Cloud Sync" (count of pending metadata uploads and pending media uploads,
   "Sync Now" button).
2. A scrollable list of queued records with truncated SHA-256 hash and their current
   SyncStatus enum value.
3. Pull-to-refresh re-queries actual pending counts from the local database rather than
   caching a stale count.
```
```text
PROMPT C — Panchanama PDF Export:
Using the pdf and printing Flutter packages, build a PanchanamaPdfService that generates
a 5-6 page document for a given TestRecord:
Page 1: Cover - MHA/NCB header, Case ID, FIR number, seizure time, status "Draft/For
  Review", QR code encoding the record hash (use a QR-generation package, on-device only).
Page 2: Presumptive field-test page - kit serial, reagent batch, Lab coordinates, deltaE,
  confidence, and the fixed legal disclaimer text (must be pixel-present, not optional).
Page 3: Image evidence - side-by-side raw vs watermarked photo with embedded GPS/badge/
  timestamp metadata printed as captions, not just burned into the image.
Page 4: Panchanama support - witness names/IDs, accused details, gross/net weight,
  packaging markings, lac seal serial.
Page 5: Chain of custody - handover log entries, transport, lab forwarding reference.
Page 6: Section 63 BSA integrity certificate - image SHA-256, record hash, previous hash,
  device signature, officer signature, and a HashChain.verify() status line for this
  specific block.
Every page must render the non-dismissible disclaimer text somewhere visible. Return the
PDF as bytes so it can be shared, printed, or saved via the `printing` package's
Printing.layoutPdf / Printing.sharePdf.
```
- 👥 Builder 2 + Researcher B (screens), PM/Domain lead (Panchanama field accuracy — this is the one place a domain mistake really shows)

### Phase 7 — End-to-End Testing 🔴 High priority, do not skip
- 🎯 Prove the fail-closed behaviour under real adverse conditions, not just happy path.
- ✅ DoD checklist (run every one of these physically, on a real phone, not in your head):
  - [ ] Camera permission denied → clear fallback UI, no crash
  - [ ] GPS denied → capture still works, record flagged `locationConfirmed=false`
  - [ ] Airplane mode during the whole capture→sign→save flow → completes fully offline
  - [ ] Low storage → graceful error, not a silent failure
  - [ ] Rapid double-tap on shutter → does not create two records or crash
  - [ ] Backgrounding the app mid-capture → resumes or fails safely, no corrupted record
  - [ ] Deliberately blurry photo → shutter disabled / result downgraded to Inconclusive, never a confident false Positive
  - [ ] Editing one byte of one stored record → `HashChain.verify()` names the exact broken block
- 👥 Whole team

### Phase 8 — Deck & Demo Rehearsal 🟡 Medium priority (but time-boxed, don't let it slide to the last night)
- 🎯 A tight, rehearsed run of the 9-step demo script from your Master Plan, using real hardware, not slides pretending to be the app.
- 👥 PM/Editor + whole team for at least 2 full dry-runs

---

## 8. Screen-by-Screen Checklist (fill in the colour column as a team)

| # | Screen | File (per your docs) | Sky Requirement (1-line) | Colour |
|---|---|---|---|---|
| 1 | Splash | `lib/screens/splash_screen.dart` | DB integrity boot-check, session restore | 🟢 |
| 2 | Login | `lib/screens/login_screen.dart` | Badge+PIN, PBKDF2, device binding | 🟢 |
| 3 | Dashboard | `lib/screens/dashboard_screen.dart` | 1-tap CTA, ledger health, recent tests | 🟢 |
| 4 | Kit Selection | `lib/screens/kit_selection_screen.dart` | NDDK/PCDK/KDK cards | 🟢 (⚫ rename PCDK — §2c) |
| 5 | Card Scan | `lib/screens/card_scan_screen.dart` | 3-frame debounce, kit mismatch block | 🟢 |
| 6 | Reaction Timer | `lib/screens/reaction_timer_screen.dart` | Kinetic countdown gate | 🟢 |
| 7 | Capture | `lib/screens/camera_capture_screen.dart` | ArUco+blur+exposure gating, burst, GPS | 🟡 — audit Phase 1 |
| 8 | Evidence Review Modal | inside `camera_capture_screen.dart` (~L367) | Pre-analysis review | 🟡 |
| 9 | Processing | `lib/screens/processing_screen.dart` | Isolate CV pipeline, staged UI | 🟡 — audit Phase 2 |
| 10 | Result | `lib/screens/result_screen.dart` | Badge+icon+text, disclaimer, retake | 🟢 |
| 11 | Dual Signing / Record Confirm | `lib/screens/dual_signing_screen.dart` + `record_confirm_screen.dart` | Both signatures, Panchanama fields, chain append | 🟡 — audit Phase 3 & 6 |
| 12 | History | `lib/screens/history_screen.dart` | Search/filter, chain audit action | 🟢 |
| 13 | Record Detail | `lib/screens/record_detail_screen.dart` | Full audit view, BSA §63 export | 🟡 — audit Phase 6 |
| 14 | **Sync Status** | **unclear if this exists — check now** | 3-tier sync visibility | 🔴 until verified |
| 15 | **Approval Queue** | **unclear if this exists — check now** | Supervisor co-sign | 🔴 until verified |
| 16 | Profile/Settings | `lib/screens/profile_settings_screen.dart` | Service ID verify, ledger audit, logout | 🟢 |

(16 rows because your own docs disagree on whether it's a 15- or 16-screen app once Evidence Review Modal is counted separately — resolve this as part of Phase 6.)

---

## 9. Backend Track — Resolve the Firebase-vs-Python Question

Your Master Plan specifies **Firebase Spark (free tier)** as the entire backend — no server to run or maintain, which is the right call for a ₹0, 5-person hackathon team. But your repo has a `backend/` folder **and** a root `requirements.txt` (Python). Two honest possibilities:

1. `backend/` and `requirements.txt` are actually your **colorimetry research/validation lab** — a Python+OpenCV notebook where Researcher A/B validated the ΔE math and reference-card thresholds *before* porting the logic to Dart. This is good practice and not a contradiction — just rename the folder or add a `backend/README.md` saying so, so judges (and teammates) don't mistake it for a second, unmaintained production backend.
2. Or it's a real Node/Python API server that duplicates what Firebase Cloud Functions should be doing.

**Recommendation:** if it's (1), keep it, document it, done. If it's (2), **fold it into Firebase Cloud Functions** before the deadline — running and demoing two backends (Firebase + a self-hosted Python/Node server) doubles your infrastructure risk for zero judging benefit, since the Master Plan explicitly only requires Firebase's free quotas for `/anchor/merkle`, `/records/{id}/export`, and `/devices/provision`.

---

## 10. Security & Threat-Mitigation Verification (from your own Master Plan §10)

| Threat | Mitigation Required | How to verify it yourself | Colour |
|---|---|---|---|
| Record tampering | Hash chain breaks detectably | Flip one byte, run `HashChain.verify()`, confirm it names the block | 🟡 verify |
| Device theft | Dual signature required | Try to seal a record with only the device key mocked in — should fail | 🟡 verify |
| Coerced officer | Kinetic timer + optional supervisor co-sign | Try to tap "capture" before the countdown ends — should be blocked | 🟡 verify (co-sign is 🔴 — see Phase 6) |
| Card duplication | QR serial registry + ArUco corners | Photocopy a card, try scanning — should fail cryptographic/format check | 🟡 verify |
| Replay/spoofing (photo of a screen) | Burst + exposure analysis for moiré/specular patterns | Point the camera at a phone/monitor showing a fake reaction — should be flagged | 🔴 likely not built yet — this is genuinely hard; treat as 🔵 stretch if time-constrained |
| GPS spoofing | Mock-location detection | Enable a fake-GPS app, confirm record gets `locationConfirmed=false`, not a silently-accepted fake location | 🟡 verify |
| Cloud alteration | Merkle root anchoring | Server-side — lower priority, see Phase 5 | 🔴 |
| Evidence leaks | Invisible watermark + `FLAG_SECURE` + audit log | Try a screenshot on the Result/Detail screen — should be blocked if `FLAG_SECURE` is set | 🟡 verify |
| False claims of definitiveness | Disclaimer burned into every screen/PDF/certificate | Literally check every relevant screen and every PDF page | ⚫ gate — verify all, not just the Result screen |
| Threshold gaming | Versioned server-side thresholds, not hardcoded client constants | Grep for the literal ΔE threshold number in Dart source — if it's a `const` in the client, that's a real weakness worth naming honestly in your "Known Limitations" slide rather than hiding it | 🟡 verify |

---

## 11. Legal & Compliance Gate (⚫ — non-negotiable before any public demo or submission)

- [ ] The exact phrase *"Presumptive result only — laboratory confirmation required"* (or your finalized wording) appears, non-dismissibly, on: Result screen, Record Detail screen, every Panchanama PDF page, and the BSA §63 certificate.
- [ ] Contrast-check your **final, reconciled** palette (after Section 5) with an independent tool (e.g. WebAIM Contrast Checker) rather than trusting numbers copied between documents — cheap 10-minute insurance.
- [ ] Confirm your understanding of DPDP Act §17's law-enforcement exemption with your domain mentor before stating it confidently in your pitch — I'm not a lawyer and neither, probably, are you; a one-line "confirmed with mentor X" note is worth more than a confident-sounding paragraph in a slide.
- [ ] Resolve the PCDK naming issue from §2c.
- [ ] Confirm Admin/Auditor capability genuinely does not exist anywhere in the mobile APK (not even behind a hidden debug menu) — this is a core selling point of your architecture and an easy thing to accidentally leave a backdoor for during rapid prototyping.

---

## 12. 9-Step Demo Rehearsal — Readiness Cross-Check

| Demo Step | Depends On | Ready? |
|---|---|---|
| 1. Case & witness entry | Record Confirm form fields | 🟢 |
| 2. Quality-gate rejection (blurry photo) | Phase 1 audit | 🟡 |
| 3. Valid capture & watermark | Phase 1 + watermark burn-in | 🟢 |
| 4. Colorimetric verdict | Phase 2 audit | 🟡 |
| 5. Ledger commit, dual signatures | Phase 3 audit | 🟡 |
| 6. Case search & audit | History screen | 🟢 |
| 7. Panchanama PDF export | Phase 6 | 🔴 until built |
| 8. Tamper detection live | `HashChain.verify()` | 🟡 verify |
| 9. Statutory disclaimer closing | Section 11 | ⚫ gate |

**Do not rehearse this on stage for the first time.** Run it twice, start to finish, on the actual demo phone, at least 48 hours before presentation day.

---

## 13. Team Allocation & Suggested Weekly Cadence

| Phase | Owner(s) | Suggested Week |
|---|---|---|
| 0 — Setup & Audit | Whole team | Week 1, Day 1 |
| 1 — Capture Pipeline | Builder 1, Researcher A | Week 1 |
| 2 — Colorimetry Engine | Builder 1, Researcher A | Week 1–2 |
| 3 — Cryptographic Ledger | Builder 2, Researcher B | Week 2 |
| 4 — Offline Queue & Sync | Builder 2 | Week 3 |
| 5 — SMS & Merkle | Builder 2 | Week 3 |
| 6 — Screen Gap + Panchanama + BSA §63 | Builder 2, Researcher B, PM/Domain | Week 3–4 |
| 7 — End-to-End Testing | Whole team | Week 4 |
| 8 — Deck & Demo Rehearsal | PM/Editor, whole team | Week 4–5 |

---

## 14. Appendix A — Quick Prompt Index

All copy-paste prompts in this document, in one place for fast reuse:
- §5.4 Canonical theme file
- §7 Phase 1 Prompt — Capture pipeline audit
- §7 Phase 2 Prompt — Colorimetry engine audit
- §7 Phase 3 Prompt — Ledger/crypto audit
- §7 Phase 4 Prompt — Staged sync
- §7 Phase 5 Prompt — SMS witness + outbox
- §7 Phase 6 Prompt A — Approval Queue Screen
- §7 Phase 6 Prompt B — Sync Status Screen
- §7 Phase 6 Prompt C — Panchanama PDF Service

---

## 15. Appendix B — What To Send Me Next For a Byte-Exact Pass

This document is built from your own documentation plus engineering judgment, clearly flagged 🟡 wherever unverified. To turn every 🟡 into a real 🟢 or 🔴, share any of the following and I'll do a line-by-line review against this exact plan:

1. `mobile_app/lib/screens/camera_capture_screen.dart`
2. Your colorimetry/classification engine file (wherever `classify()` or `ClassificationResult` is implemented)
3. Your hash-chain / ledger service file
4. `mobile_app/lib/screens/` — full folder listing (even just filenames) to settle the Sync Status / Approval Queue / Dual Signing question from §2a
5. `security/` and `sync_mesh/` folder contents

You can paste code directly in chat, upload files here, or share a zip — whichever's fastest for you.
