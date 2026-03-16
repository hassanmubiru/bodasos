import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'database_service.dart';

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  Position? _lastPosition;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _syncTimer;
  bool _isTracking = false;

  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  // Stream for UI updates
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        // Try to return last cached position
        return await _getLastCachedPosition();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = position;
      await DatabaseService.instance.cacheLocation(
        position.latitude,
        position.longitude,
        position.accuracy,
      );

      return position;
    } catch (e) {
      // Return last known position if GPS fails
      return await _getLastCachedPosition();
    }
  }

  Future<Position?> _getLastCachedPosition() async {
    final cached = await DatabaseService.instance.getLastKnownLocation();
    if (cached != null) {
      return Position(
        latitude: cached['latitude'] as double,
        longitude: cached['longitude'] as double,
        timestamp: DateTime.parse(cached['timestamp'] as String),
        accuracy: cached['accuracy'] as double? ?? 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    return null;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;

    // Real-time position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen(
      (position) {
        _lastPosition = position;
        _positionController.add(position);
        _cachePosition(position);
      },
      onError: (error) {
        // Continue silently - use cache
      },
    );

    // Sync to server every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _syncCurrentPosition();
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _syncTimer?.cancel();
    _isTracking = false;
  }

  Future<void> _cachePosition(Position position) async {
    await DatabaseService.instance.cacheLocation(
      position.latitude,
      position.longitude,
      position.accuracy,
    );
  }

  Future<void> _syncCurrentPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('rider_id');
    if (riderId == null || _lastPosition == null) return;

    await ApiService.instance.updateLocation(
      riderId: riderId,
      latitude: _lastPosition!.latitude,
      longitude: _lastPosition!.longitude,
      accuracy: _lastPosition!.accuracy,
    );
  }

  double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
