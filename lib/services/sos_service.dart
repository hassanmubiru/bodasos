import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/rider.dart';
import 'api_service.dart';
import 'location_service.dart';

class SOSService {
  static final SOSService instance = SOSService._init();
  SOSService._init();

  bool _isActive = false;
  bool _shakeEnabled = true;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  Timer? _sosTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Shake detection parameters
  static const double _shakeThreshold = 15.0;
  static const int _shakeMinCount = 3;
  static const Duration _shakeWindow = Duration(seconds: 2);

  final List<DateTime> _shakeTimestamps = [];

  bool get isActive => _isActive;

  // SOS state stream for UI
  final StreamController<SOSState> _sosController =
      StreamController<SOSState>.broadcast();
  Stream<SOSState> get sosStream => _sosController.stream;

  // ── Shake Detection ───────────────────────────────────────────────────────────

  void startShakeDetection(Function() onShakeDetected) {
    if (!_shakeEnabled) return;

    _accelSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        _shakeTimestamps.add(now);

        // Remove timestamps outside window
        _shakeTimestamps.removeWhere(
          (t) => now.difference(t) > _shakeWindow,
        );

        if (_shakeTimestamps.length >= _shakeMinCount) {
          _shakeTimestamps.clear();
          onShakeDetected();
        }
      }
    });
  }

  void stopShakeDetection() {
    _accelSubscription?.cancel();
    _shakeTimestamps.clear();
  }

  // ── SOS Trigger ───────────────────────────────────────────────────────────────

  Future<SOSResult> triggerSOS() async {
    if (_isActive) {
      return SOSResult(
        success: false,
        message: 'SOS already active',
        alreadyActive: true,
      );
    }

    _isActive = true;
    _sosController.add(SOSState.activating);

    // Immediate haptic + audio feedback
    await _triggerAlarm();

    // Get location
    final position = await LocationService.instance.getCurrentPosition();

    if (position == null) {
      _isActive = false;
      _sosController.add(SOSState.failed);
      return SOSResult(
        success: false,
        message: 'Could not get location. Make sure GPS is enabled.',
      );
    }

    // Get rider profile
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('rider_id') ?? '';
    final riderName = prefs.getString('rider_name') ?? '';
    final riderPhone = prefs.getString('rider_phone') ?? '';
    final riderStage = prefs.getString('rider_stage') ?? '';
    final riderDistrict = prefs.getString('rider_district') ?? 'Kampala';

    _sosController.add(SOSState.sending);

    // Send SOS to server + police
    final result = await ApiService.instance.triggerSOS(
      riderId: riderId,
      riderName: riderName,
      riderPhone: riderPhone,
      latitude: position.latitude,
      longitude: position.longitude,
      stage: riderStage,
      district: riderDistrict,
    );

    try {
      if (result['success'] == true) {
        _sosController.add(SOSState.sent);
        return SOSResult(
          success: true,
          message: result['message'] ?? 'Help is on the way!',
          nearbyRidersAlerted: result['riders_alerted'] as int? ?? 0,
          policeAlerted: result['police_alerted'] as bool? ?? false,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else if (result['offline'] == true) {
        _sosController.add(SOSState.sentOffline);
        return SOSResult(
          success: true,
          message: 'SOS saved! Will be sent when connected.',
          isOffline: true,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        _sosController.add(SOSState.failed);
        return SOSResult(
          success: false,
          message: result['error']?.toString() ?? 'Failed to send SOS',
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } finally {
      // Always reset so rider can trigger SOS again
      _isActive = false;
    }
  }

  void cancelSOS() {
    _isActive = false;
    _sosController.add(SOSState.cancelled);
    _stopAlarm();
  }

  // ── Alarm ─────────────────────────────────────────────────────────────────────

  Future<void> _triggerAlarm() async {
    // Vibration pattern: long-short-short-long
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 1000, 200, 500],
        intensities: [0, 255, 0, 255, 0, 255, 0, 255],
      );
    }

    // Play alarm sound
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/sos_alarm.mp3'));
    } catch (_) {
      // Audio not available in some environments
    }
  }

  void _stopAlarm() {
    Vibration.cancel();
    _audioPlayer.stop();
  }

  void dispose() {
    stopShakeDetection();
    _sosController.close();
    _audioPlayer.dispose();
  }
}

enum SOSState {
  idle,
  activating,
  sending,
  sent,
  sentOffline,
  failed,
  cancelled,
}

class SOSResult {
  final bool success;
  final String message;
  final bool isOffline;
  final bool alreadyActive;
  final int nearbyRidersAlerted;
  final bool policeAlerted;
  final double? latitude;
  final double? longitude;

  SOSResult({
    required this.success,
    required this.message,
    this.isOffline = false,
    this.alreadyActive = false,
    this.nearbyRidersAlerted = 0,
    this.policeAlerted = false,
    this.latitude,
    this.longitude,
  });
}
