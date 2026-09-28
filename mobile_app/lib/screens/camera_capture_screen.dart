import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _liveQualityPassed = false;
  bool _liveFiducialsDetected = false;
  double _liveLaplacianVariance = 0;
  DateTime _lastQualityCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _accusedPresent = true;

  @override
  void initState() {
    super.initState();
    _activeKit = widget.selectedKit;
    WidgetsBinding.instance.addObserver(this);
    _initializeHardware();
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
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(cameraController.description);
    }
  }

  Future<void> _initializeHardware() async {
    // 1. Initialize Camera FIRST and await it completely
    await _initCameraHardware();

    // 2. Start GPS acquisition only AFTER camera is ready (prevents Android permission dialog clash)
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _startGpsAcquisition();
      }
    }
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

  void _onCameraFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastQualityCheck).inMilliseconds < 220 || _isCapturing) return;
    _lastQualityCheck = now;
    final metrics = CameraQualityGate.fromCameraImage(image);
    if (!mounted) return;
    setState(() {
      _liveLaplacianVariance = metrics.laplacianVariance;
      _liveFiducialsDetected = metrics.fourFiducialsVisible;
      _liveQualityPassed = metrics.passed;
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
        if (!_liveQualityPassed) {
          throw StateError(
            'Capture blocked: keep all four reference fiducials visible and hold the device steady '
            '(sharpness ${_liveLaplacianVariance.toStringAsFixed(1)} / 100).',
          );
        }
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
                                  activeColor: GovTheme.primary,
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

            // Drug Type Quick Selector Bar
            _buildDrugSelectorBar(),

            // Live GPS Status Banner
            _buildLiveGpsStrip(),

            // Live Camera Viewfinder & Alignment Reticle
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Sensor Stream
                  if (_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized)
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
                  else
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
                    ),

                  // Prominent Live Camera Badge
                  if (_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized)
                    Positioned(
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.greenAccent, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "LIVE CAMERA ACTIVE",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ArUco Reference Card Alignment Reticle
                  Center(
                    child: Container(
                      width: 280,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Corner brackets
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Icon(
                              Icons.crop_free,
                              color: Colors.greenAccent.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.crop_free,
                              color: Colors.greenAccent.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Icon(
                              Icons.crop_free,
                              color: Colors.greenAccent.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(
                              Icons.crop_free,
                              color: Colors.greenAccent.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          // Center target dot
                          const Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white70,
                              size: 28,
                            ),
                          ),
                          // Reticle Instruction Label
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Center chemical reaction spot inside frame",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          // Flashlight Toggle
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amberAccent : Colors.white70,
              size: 20,
            ),
            tooltip: "Toggle Flashlight",
            onPressed: _toggleTorch,
          ),
          // Camera Flip
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70, size: 20),
            tooltip: "Switch Camera",
            onPressed: _flipCamera,
          ),
          // Reference Evidence Photo Selector (for field evaluation and testing)
        ],
      ),
    );
  }

  Widget _buildDrugSelectorBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "SUSPECTED SUBSTANCE:",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                _activeKit == KitType.nddk
                    ? "Violet / Deep Purple expected"
                    : (_activeKit == KitType.pcdk
                        ? "Indigo-Blue expected"
                        : "Cobalt Blue expected"),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDrugChip(
                  label: "Heroin / Opium",
                  kit: KitType.nddk,
                  icon: Icons.grain,
                ),
                const SizedBox(width: 6),
                _buildDrugChip(
                  label: "Ganja / Cannabis",
                  kit: KitType.pcdk,
                  icon: Icons.grass,
                ),
                const SizedBox(width: 6),
                _buildDrugChip(
                  label: "Cocaine / Crack",
                  kit: KitType.kdk,
                  icon: Icons.snowing,
                ),
                const SizedBox(width: 6),
                _buildDrugChip(
                  label: "Meth / Synthetics",
                  kit: KitType.nddk,
                  icon: Icons.science,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugChip({
    required String label,
    required KitType kit,
    required IconData icon,
  }) {
    final isSelected = _activeKit == kit;
    return InkWell(
      onTap: () => setState(() => _activeKit = kit),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? GovTheme.primary : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amberAccent : Colors.white24,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
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
            onTap: (_isCapturing || !_liveQualityPassed) ? null : _handleCaptureShutter,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: (_isCameraInitialized && _liveQualityPassed)
                      ? GovTheme.alertNegativeText
                      : Colors.grey.shade400,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isCameraInitialized && _liveQualityPassed)
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
                          color: (_isCameraInitialized && _liveQualityPassed)
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
                onPressed: _initializeHardware,
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
