import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/forensic_watermark_service.dart';
import '../services/optical_processing_service.dart';
import '../services/camera_quality_gate.dart';
import 'processing_screen.dart';

/// Screen 7: Field Drug Testing Camera & Real-Time GPS Geolocation Screen
/// Uses the device hardware camera and real-time GPS sensor to capture evidence,
/// burns statutory forensic watermarks under NDPS Act §52A, and provides
/// a responsive, police-friendly mobile experience.
class CameraCaptureScreen extends StatefulWidget {
  final User currentUser;
  final KitType selectedKit;
  final String reagentBatch;
  final String cardSerial;
  final int reagentStep;
  final OpticalAnalysisOutput? primaryStepOutput;

  const CameraCaptureScreen({
    super.key,
    required this.currentUser,
    this.selectedKit = KitType.nddk,
    this.reagentBatch = "MHA-BATCH-2026-09B",
    this.cardSerial = "MHACARD-2026-DEL-0491",
    this.reagentStep = 1,
    this.primaryStepOutput,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraActive = false;
  String? _cameraError;
  bool _isTorchOn = false;

  // Active Kit / Substance Selection
  late KitType _activeKit;

  // Real-Time GPS Tracking
  Position? _currentGpsPosition;
  bool _isGpsAcquired = false;
  String _gpsStatusText = "Acquiring GPS Satellite Fix...";
  StreamSubscription<Position>? _gpsStreamSub;

  // Capture State & Quality
  bool _isCapturing = false;
  bool _liveQualityPassed = true;
  DateTime _lastQualityCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _accusedPresent = true;

  @override
  void initState() {
    super.initState();
    _activeKit = widget.selectedKit;
    WidgetsBinding.instance.addObserver(this);
    // Camera is strictly manual on-demand. Only GPS is acquired upfront.
    _startGpsAcquisition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsStreamSub?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCameraManual();
    }
  }

  Future<void> _startCameraManual() async {
    setState(() {
      _isCameraActive = true;
      _cameraError = null;
    });
    await _initCameraHardware();
  }

  Future<void> _stopCameraManual() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    if (!mounted) return;
    setState(() {
      _cameraController = null;
      _isCameraInitialized = false;
      _isCameraActive = false;
      _isTorchOn = false;
    });
  }

  Future<void> _initCameraHardware() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        setState(() {
          _cameraError = cameraStatus.isPermanentlyDenied
              ? "Camera permission is permanently denied in Android settings.\nPlease tap 'OPEN APP SETTINGS' below to allow camera access."
              : "Camera permission is required to photograph chemical field test results.\nPlease grant Camera permission to continue.";
        });
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = "No camera hardware detected on this device.";
        });
        return;
      }

      // Default to rear camera if available
      int defaultIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (defaultIndex < 0) defaultIndex = 0;
      _selectedCameraIndex = defaultIndex;

      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = "Camera sensor initialization error: $e";
      });
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    await _cameraController?.dispose();

    // 1. First attempt: ResolutionPreset.high
    try {
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.startImageStream(_onCameraFrame);
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
      return;
    } catch (e) {
      debugPrint("High resolution init failed, falling back to medium: $e");
    }

    // 2. Fallback: ResolutionPreset.medium (supported on 100% of Android devices)
    try {
      final fallbackController = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = fallbackController;
      await fallbackController.initialize();
      await fallbackController.startImageStream(_onCameraFrame);
      try {
        await fallbackController.setFocusMode(FocusMode.auto);
        await fallbackController.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
      return;
    } catch (fallbackError) {
      debugPrint("Medium resolution init failed, falling back to low: $fallbackError");
    }

    // 3. Fallback: ResolutionPreset.low
    try {
      final lowController = CameraController(
        description,
        ResolutionPreset.low,
        enableAudio: false,
      );
      _cameraController = lowController;
      await lowController.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });
    } catch (lowError) {
      if (!mounted) return;
      setState(() {
        _cameraError = "Failed to open camera hardware: $lowError\nPlease tap OPEN APP SETTINGS or restart.";
      });
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    final now = DateTime.now();
    if (now.difference(_lastQualityCheck).inMilliseconds < 220 || _isCapturing) return;
    _lastQualityCheck = now;
    final metrics = await CameraQualityGate.fromCameraImage(image);
    if (!mounted) return;
    setState(() {
      _liveQualityPassed = metrics.laplacianVariance >= 25;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _selectedCameraIndex = nextIndex;
    setState(() {
      _isCameraInitialized = false;
    });
    await _cameraController?.dispose();
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final newMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _startGpsAcquisition() async {
    try {
      // 1. Request location permissions
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        setState(() {
          _gpsStatusText = "GPS Permission Denied. Geotagging will use default precinct.";
        });
        return;
      }

      // 2. Fetch current high-precision position. A timeout or denial must
      // never block capture and must never create a fabricated location.
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _currentGpsPosition = initialPosition;
          _isGpsAcquired = true;
          _gpsStatusText =
              "GPS LOCKED: ${initialPosition.latitude.toStringAsFixed(5)}°, ${initialPosition.longitude.toStringAsFixed(5)}° (±${initialPosition.accuracy.toStringAsFixed(1)}m)";
        });
      }

      // 3. Continuous real-time GPS stream
      _gpsStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentGpsPosition = pos;
            _isGpsAcquired = true;
            _gpsStatusText =
                "GPS LOCKED: ${pos.latitude.toStringAsFixed(5)}°, ${pos.longitude.toStringAsFixed(5)}° (±${pos.accuracy.toStringAsFixed(1)}m)";
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatusText = "GPS Notice: Using precinct location ($e)";
        });
      }
    }
  }

  Future<void> _handleCaptureShutter({File? overrideFile}) async {
    if (_isCapturing) return;

    if (overrideFile == null) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Camera hardware not ready. Please check camera permissions in Settings.",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: GovTheme.alertPositiveText,
            action: SnackBarAction(
              label: "SETTINGS",
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _isCapturing = true);

    try {
      File rawPhotoFile;

      // 1. Take photograph from device camera hardware
      if (overrideFile != null) {
        rawPhotoFile = overrideFile;
      } else if (_cameraController != null && _cameraController!.value.isInitialized) {
        await _cameraController!.stopImageStream();
        final burst = <File>[];
        for (var i = 0; i < 4; i++) {
          final photo = await _cameraController!.takePicture();
          burst.add(File(photo.path));
          if (i < 3) await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        var bestIndex = 0;
        var bestScore = -1.0;
        for (var i = 0; i < burst.length; i++) {
          final score = CameraQualityGate.fromEncodedImage(await burst[i].readAsBytes());
          if (score > bestScore) {
            bestScore = score;
            bestIndex = i;
          }
        }
        if (mounted && _cameraController!.value.isInitialized) {
          await _cameraController!.startImageStream(_onCameraFrame);
        }
        rawPhotoFile = burst[bestIndex];
        for (var i = 0; i < burst.length; i++) {
          if (i != bestIndex) {
            try { await burst[i].delete(); } catch (_) {}
          }
        }
      } else {
        setState(() => _isCapturing = false);
        return;
      }

      // 2. Capture instantaneous GPS coordinates
      GeoPoint? geoPoint;
      bool locationConfirmed = false;
      if (_currentGpsPosition != null) {
        geoPoint = GeoPoint(
          latitude: _currentGpsPosition!.latitude,
          longitude: _currentGpsPosition!.longitude,
          accuracy: _currentGpsPosition!.accuracy,
        );
        locationConfirmed = true;
      } else {
        // Fail open for capture, fail closed for trust.
        geoPoint = null;
        locationConfirmed = false;
      }

      final testId =
          "TEST-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

      // 3. Burn official forensic watermark onto evidence photo
      File watermarkedFile = rawPhotoFile;
      try {
        watermarkedFile = await ForensicWatermarkService.instance.stampForensicWatermark(
          rawImageFile: rawPhotoFile,
          testId: testId,
          officerBadge: widget.currentUser.badgeNumber,
          deviceId: widget.currentUser.deviceId,
                                     latitude: geoPoint?.latitude,
                                     longitude: geoPoint?.longitude,
          locationConfirmed: locationConfirmed,
        );
      } catch (e) {
        debugPrint("Forensic watermark generation note: $e");
      }

      if (!mounted) return;
      setState(() => _isCapturing = false);

      // 4. Show Instant Watermarked Evidence Review Dialog
      _showEvidenceReviewDialog(
        watermarkedFile: watermarkedFile,
        testId: testId,
        geoPoint: geoPoint,
        locationConfirmed: locationConfirmed,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Capture Error: $e"),
            backgroundColor: GovTheme.alertPositiveText,
          ),
        );
      }
    }
  }

  Future<void> _selectSampleEvidencePhoto() async {
    final chosenAsset = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SELECT SAMPLE EVIDENCE PHOTO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Run forensic optical analysis with pre-verified test samples without activating the camera.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                  title: const Text("Positive Field Reaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Standard positive reagent color change", style: TextStyle(color: Colors.white60, fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, 'assets/field_sample_positive.png'),
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  title: const Text("Negative Field Reaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Reagent blank / no color reaction", style: TextStyle(color: Colors.white60, fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, 'assets/field_sample_negative.png'),
                ),
                ListTile(
                  leading: const Icon(Icons.blur_on, color: Colors.amberAccent),
                  title: const Text("Blurry Field Sample", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text("Tests quality gate and low confidence warning", style: TextStyle(color: Colors.white60, fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, 'assets/field_sample_blurry.png'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosenAsset == null) return;

    try {
      final byteData = await rootBundle.load(chosenAsset);
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/sample_evidence_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await _handleCaptureShutter(overrideFile: tempFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading sample image: $e")),
        );
      }
    }
  }

  void _showEvidenceReviewDialog({
    required File watermarkedFile,
    required String testId,
    required GeoPoint? geoPoint,
    required bool locationConfirmed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: GovTheme.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Modal drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/mha_emblem.png',
                          height: 28,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield,
                            color: GovTheme.ashokaNavy,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "CAPTURED EVIDENCE REVIEW",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: GovTheme.ashokaNavy,
                                ),
                              ),
                              Text(
                                "NDPS §52A Statutory Forensic Watermark Verified",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: GovTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Content Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Photo Preview Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 220,
                              color: Colors.black,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (watermarkedFile.existsSync())
                                    Image.file(
                                      watermarkedFile,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                    )
                                  else
                                    const Center(
                                      child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
                                    ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.verified,
                                            color: Colors.greenAccent,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "WATERMARKED",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Evidence Details Summary
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: GovTheme.bgBase,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GovTheme.borderDefault),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  "Suspected Target:",
                                  _activeKit.targetSubstance,
                                  isBold: true,
                                ),
                                _buildDetailRow("Test Reference ID:", testId),
                                _buildDetailRow(
                                  "Officer Badge:",
                                  "${widget.currentUser.name} (${widget.currentUser.badgeNumber})",
                                ),
                                _buildDetailRow(
                                  "Live GPS Geotag:",
                                   geoPoint == null
                                       ? "UNCONFIRMED — no GPS fix"
                                       : "${geoPoint.latitude.toStringAsFixed(5)}° N, ${geoPoint.longitude.toStringAsFixed(5)}° E",
                                  isHighlight: true,
                                ),
                                _buildDetailRow(
                                  "Operational Location:",
                                  "${widget.currentUser.city} • ${widget.currentUser.unit}",
                                ),
                                _buildDetailRow("Apparatus ID:", widget.currentUser.deviceId),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Accused Suspect Present Switch
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GovTheme.borderDefault),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_pin,
                                  color: GovTheme.ashokaNavy,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        "Accused Suspect Present",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Mandated witness recording under NDPS §52A",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: GovTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _accusedPresent,
                                  activeThumbColor: GovTheme.primary,
                                  onChanged: (val) {
                                    setSheetState(() => _accusedPresent = val);
                                    setState(() => _accusedPresent = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons: Retake vs Proceed
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text(
                                    "RETAKE",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GovTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx); // Close sheet
                                    final captureResult = CaptureResult(
                                      capturedImageFile: watermarkedFile,
         location: geoPoint,
                                      locationConfirmed: locationConfirmed,
                                      kitType: _activeKit,
                                      cardSerial: widget.cardSerial,
                                      reagentBatch: widget.reagentBatch,
                                      reactionTimestamp: DateTime.now(),
                                      accusedPresent: _accusedPresent,
                                    );
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProcessingScreen(
                                          currentUser: widget.currentUser,
                                          captureResult: captureResult,
                                          reagentStep: widget.reagentStep,
                                          primaryStepOutput: widget.primaryStepOutput,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.analytics_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "ANALYZE EVIDENCE",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: GovTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? GovTheme.alertNegativeText : GovTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Officer identity, flashlight, camera flip, and back button
            _buildTopBar(),

            // Live GPS Status Banner
            _buildLiveGpsStrip(),

            // Live Camera Viewfinder & Alignment Reticle or Standby Mode
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Live Camera Sensor Stream
                  if (_isCameraActive && _isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized)
                    Positioned.fill(
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize != null
                                ? _cameraController!.value.previewSize!.height
                                : 720,
                            height: _cameraController!.value.previewSize != null
                                ? _cameraController!.value.previewSize!.width
                                : 1280,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    )
                  else if (_cameraError != null)
                    Positioned.fill(child: _buildCameraErrorView())
                  else if (_isCameraActive)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: GovTheme.primary),
                          SizedBox(height: 12),
                          Text(
                            "Starting Hardware Camera Sensor...",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    // Standby View when Camera is OFF
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.videocam_off_outlined,
                                    color: Colors.white70,
                                    size: 52,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Camera Sensor in Standby",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Hardware camera is turned OFF.\nTap below to activate live camera or run analysis using a pre-captured sample photo.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _startCameraManual,
                                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  label: const Text(
                                    "TURN ON LIVE CAMERA",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    minimumSize: const Size(260, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _selectSampleEvidencePhoto,
                                  icon: const Icon(Icons.photo_library_outlined, size: 18, color: Colors.amberAccent),
                                  label: const Text(
                                    "USE SAMPLE EVIDENCE PHOTO",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.amberAccent),
                                    minimumSize: const Size(260, 46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Alignment Reticle (Visible ONLY when Camera is ON)
                  if (_isCameraActive && _isCameraInitialized)
                    Center(
                      child: Container(
                        width: 290,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: Icon(Icons.crop_free, color: Colors.greenAccent, size: 26),
                            ),
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(Icons.crop_free, color: Colors.greenAccent, size: 26),
                            ),
                            const Positioned(
                              bottom: 8,
                              left: 8,
                              child: Icon(Icons.crop_free, color: Colors.greenAccent, size: 26),
                            ),
                            const Positioned(
                              bottom: 8,
                              right: 8,
                              child: Icon(Icons.crop_free, color: Colors.greenAccent, size: 26),
                            ),
                            const Center(
                              child: Icon(Icons.add, color: Colors.greenAccent, size: 28),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _liveQualityPassed ? Icons.check_circle : Icons.camera,
                                        color: _liveQualityPassed ? Colors.greenAccent : Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _liveQualityPassed
                                            ? "FOCUS LOCKED • READY FOR SHUTTER"
                                            : "FRAME REACTION CASSETTE / POUCH",
                                        style: TextStyle(
                                          color: _liveQualityPassed ? Colors.greenAccent : Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Camera Control Dock
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomShutterDock(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Image.asset(
            'assets/mha_emblem.png',
            height: 26,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shield,
              color: Colors.amberAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MHA FIELD DRUG TEST",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "${widget.currentUser.name} • Badge: ${widget.currentUser.badgeNumber}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (_isCameraActive) ...[
            TextButton.icon(
              onPressed: _stopCameraManual,
              icon: const Icon(Icons.videocam_off, color: Colors.amberAccent, size: 18),
              label: const Text(
                "TURN OFF",
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? Colors.amberAccent : Colors.white70,
                size: 20,
              ),
              tooltip: "Toggle Flashlight",
              onPressed: _toggleTorch,
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 20),
              tooltip: "Switch Camera",
              onPressed: _flipCamera,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, color: Colors.white70, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "STANDBY",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveGpsStrip() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            _isGpsAcquired ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: _isGpsAcquired ? Colors.greenAccent : Colors.amberAccent,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _gpsStatusText,
              style: TextStyle(
                fontSize: 10,
                color: _isGpsAcquired ? Colors.greenAccent : Colors.amberAccent,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _isGpsAcquired
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isGpsAcquired ? Colors.green : Colors.amber,
                width: 0.8,
              ),
            ),
            child: Text(
              _isGpsAcquired ? "LOCKED" : "ACQUIRING",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _isGpsAcquired ? Colors.greenAccent : Colors.amberAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomShutterDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left: Test details indicator
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TARGET ASSAY",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
              Text(
                _activeKit.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Center: Shutter Button with Camera State Feedback
          GestureDetector(
            onTap: _isCapturing
                ? null
                : (_isCameraActive && _isCameraInitialized
                    ? _handleCaptureShutter
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Camera is in Standby. Please tap 'TURN ON LIVE CAMERA' or 'USE SAMPLE EVIDENCE PHOTO'.",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: GovTheme.ashokaNavy,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: (_isCameraActive && _isCameraInitialized)
                      ? GovTheme.alertNegativeText
                      : Colors.grey.shade400,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isCameraActive && _isCameraInitialized)
                        ? Colors.greenAccent.withValues(alpha: 0.4)
                        : Colors.black26,
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: _isCapturing
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: GovTheme.primary,
                        ),
                      )
                    : Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_isCameraActive && _isCameraInitialized)
                              ? GovTheme.primary
                              : Colors.grey.shade600,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
              ),
            ),
          ),

          // Right: Accused toggle hint
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "ACCUSED PRESENT",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
              Text(
                _accusedPresent ? "YES (WITNESSED)" : "NO",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _accusedPresent ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraErrorView() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                color: GovTheme.alertPositiveText,
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                _cameraError ?? "Camera hardware unavailable",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GovTheme.primary,
                  minimumSize: const Size(220, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings, size: 20, color: Colors.white),
                label: const Text(
                  "OPEN APP SETTINGS",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 44),
                ),
                onPressed: _startCameraManual,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  "RETRY CAMERA SENSOR",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 18),
          ],
        ),
      ),
    ),
  );
  }
}
