import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/rider.dart';
import 'database_service.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

  // ── CONFIGURE YOUR FLASK BACKEND URL HERE ──────────────────────────────────
  static const String baseUrl = 'https://your-flask-backend.com';
  // For local dev: 'http://192.168.1.100:5000'
  // For production: 'https://bodasos-api.your-domain.com'
  // ──────────────────────────────────────────────────────────────────────────

  static const Duration timeout = Duration(seconds: 15);

  final Connectivity _connectivity = Connectivity();

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Set this to your API_SECRET_KEY from .env
  static const String _apiKey = String.fromEnvironment(
    'API_SECRET_KEY',
    defaultValue: '',
  );

  // Public so other services (RepairService) can share the same auth headers
  Map<String, String> get authHeaders => _buildHeaders();
  Map<String, String> get _headers => _buildHeaders();

  Map<String, String> _buildHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': '1.0.0',
        'X-Platform': Platform.isAndroid ? 'android' : 'ios',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
      };

  // ── Registration ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerRider({
    required String id,
    required String name,
    required String phone,
    required String stage,
    required String area,
    required String district,
  }) async {
    if (!await isOnline) {
      return {'success': false, 'error': 'No internet connection', 'offline': true};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'name': name,
              'phone': phone,
              'stage': stage,
              'area': area,
              'district': district,
            }),
          )
          .timeout(timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...data};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } on SocketException {
      return {'success': false, 'error': 'Network error', 'offline': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Location Update ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateLocation({
    required String riderId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    // Always cache locally first
    await DatabaseService.instance.cacheLocation(latitude, longitude, accuracy);

    if (!await isOnline) {
      return {'success': false, 'offline': true};
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/update_location'),
            headers: _headers,
            body: jsonEncode({
              'rider_id': riderId,
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Server error ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'offline': true};
    }
  }

  // ── SOS Trigger ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> triggerSOS({
    required String riderId,
    required String riderName,
    required String riderPhone,
    required double latitude,
    required double longitude,
    required String stage,
    required String district,
  }) async {
    // Save locally immediately (critical for offline)
    final localId = await DatabaseService.instance.saveSOS(latitude, longitude);

    final alert = SOSAlert(
      riderId: riderId,
      riderName: riderName,
      riderPhone: riderPhone,
      latitude: latitude,
      longitude: longitude,
      stage: stage,
      district: district,
      timestamp: DateTime.now(),
      message:
          'EMERGENCY! Boda rider $riderName needs help at $stage! Call $riderPhone immediately!',
    );

    if (!await isOnline) {
      return {
        'success': false,
        'offline': true,
        'local_id': localId,
        'message': 'SOS saved offline. Will sync when connected.',
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/sos'),
            headers: _headers,
            body: jsonEncode(alert.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await DatabaseService.instance.markSOSSynced(
          localId,
          data['message'] ?? 'Sent',
        );
        return {'success': true, ...data};
      }
      return {'success': false, 'local_id': localId, 'error': data['error']};
    } catch (e) {
      return {
        'success': false,
        'offline': true,
        'local_id': localId,
        'error': e.toString(),
      };
    }
  }

  // ── Nearby Riders ─────────────────────────────────────────────────────────────

  Future<List<Rider>> getNearbyRiders({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    if (!await isOnline) {
      // Return cached riders
      return await DatabaseService.instance.getCachedRiders();
    }

    try {
      final uri = Uri.parse('$baseUrl/nearby_riders').replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radius_km': radiusKm.toString(),
        },
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final riders = (data['riders'] as List<dynamic>)
            .map((r) => Rider.fromJson(r as Map<String, dynamic>))
            .toList();

        // Cache for offline use
        await DatabaseService.instance.cacheNearbyRiders(riders);
        return riders;
      }
    } catch (e) {
      // Fall through to cache
    }

    return await DatabaseService.instance.getCachedRiders();
  }

  // ── Sync Offline Data ─────────────────────────────────────────────────────────

  Future<void> syncOfflineData(String riderId) async {
    if (!await isOnline) return;

    final locations = await DatabaseService.instance.getUnsyncedLocations();
    for (final loc in locations) {
      try {
        final result = await updateLocation(
          riderId: riderId,
          latitude: loc['latitude'] as double,
          longitude: loc['longitude'] as double,
          accuracy: loc['accuracy'] as double? ?? 0,
        );
        if (result['success'] == true) {
          await DatabaseService.instance.markLocationSynced(loc['id'] as int);
        }
      } catch (_) {}
    }
  }

  // ── Mechanic Registration ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerMechanic({
    required String id,
    required String name,
    required String phone,
    required String stage,
    required String district,
    String? shopName,
    required List<String> specialties,
  }) async {
    if (!await isOnline) {
      return {'success': false, 'offline': true,
          'error': 'No connection — saved locally'};
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/mechanic/register'),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'name': name,
              'phone': phone,
              'stage': stage,
              'district': district,
              'shop_name': shopName ?? '',
              'specialties': specialties.join(','),
            }),
          )
          .timeout(timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...data};
      }
      return {'success': false, 'error': data['error'] ?? 'Registration failed'};
    } on SocketException {
      return {'success': false, 'offline': true, 'error': 'No connection'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── FCM Token ─────────────────────────────────────────────────────────────

  Future<void> sendFcmToken(String riderId, String token) async {
    if (!await isOnline) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/fcm_token'),
            headers: _headers,
            body: jsonEncode({'rider_id': riderId, 'fcm_token': token}),
          )
          .timeout(timeout);
    } catch (_) {}
  }
}

