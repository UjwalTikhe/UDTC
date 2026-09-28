import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String status; // 'GPS_CONFIRMED' or 'LOCATION_UNCONFIRMED'
  final bool isConfirmed;
  final double? accuracyMeters;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.isConfirmed,
    this.accuracyMeters,
  });
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  /// Obtains a real GPS fix. Capture remains available when this returns
  /// LOCATION_UNCONFIRMED; fabricated coordinates are never evidence.
  Future<LocationResult> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          latitude: null,
          longitude: null,
          status: "LOCATION_UNCONFIRMED",
          isConfirmed: false,
          accuracyMeters: null,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            latitude: null,
            longitude: null,
            status: "LOCATION_UNCONFIRMED",
            isConfirmed: false,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          latitude: null,
          longitude: null,
          status: "LOCATION_UNCONFIRMED",
          isConfirmed: false,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        status: "GPS_CONFIRMED",
        isConfirmed: true,
        accuracyMeters: position.accuracy,
      );
    } catch (e) {
      // Fail closed: degrade to LOCATION_UNCONFIRMED, never silently blank
      return LocationResult(
        latitude: null,
        longitude: null,
        status: "LOCATION_UNCONFIRMED",
        isConfirmed: false,
      );
    }
  }
}
