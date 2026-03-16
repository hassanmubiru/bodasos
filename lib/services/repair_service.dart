import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../models/repair.dart';
import 'api_service.dart';
import 'database_service.dart';

class RepairService {
  static final RepairService instance = RepairService._();
  RepairService._();

  static const Duration _timeout = Duration(seconds: 15);

  /// Always use ApiService.instance.authHeaders so the X-API-Key
  /// and platform metadata are included in every request.
  Map<String, String> get _headers => ApiService.instance.authHeaders;

  // ── Submit repair request ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitRequest(RepairRequest req) async {
    // Save locally first — offline-first guarantee
    await _saveLocal(req);

    final online = await ApiService.instance.isOnline;
    if (!online) {
      return {
        'success': true,
        'offline': true,
        'message': 'Repair request saved. Will alert nearby riders when connected.',
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/repair/request'),
            headers: _headers,
            body: jsonEncode(req.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _markSynced(req.id);
        return {'success': true, ...data};
      }

      // Parse error body if available
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': false, 'offline': false, 'error': err['error']};
      } catch (_) {
        return {
          'success': false,
          'offline': false,
          'error': 'Server error ${response.statusCode}',
        };
      }
    } on SocketException {
      return {
        'success': true,
        'offline': true,
        'message': 'Saved offline. Will send when connected.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Cancel request ─────────────────────────────────────────────────────────
  // BUG FIX: backend requires both request_id AND rider_id.

  Future<bool> cancelRequest({
    required String requestId,
    required String riderId,
  }) async {
    await _updateLocalStatus(requestId, RepairStatus.cancelled);

    final online = await ApiService.instance.isOnline;
    if (!online) return true;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/repair/cancel'),
            headers: _headers,
            body: jsonEncode({
              'request_id': requestId,
              'rider_id': riderId,  // required by backend ownership check
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return true; // already cancelled locally
    }
  }

  // ── Poll status ────────────────────────────────────────────────────────────

  Future<RepairRequest?> getStatus(String requestId) async {
    final online = await ApiService.instance.isOnline;
    if (!online) return _getLocal(requestId);

    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/repair/status/$requestId'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return RepairRequest.fromJson(
            data['request'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return _getLocal(requestId);
  }

  // ── My recent requests ─────────────────────────────────────────────────────

  Future<List<RepairRequest>> getMyRequests(String riderId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'repair_requests',
      where: 'rider_id = ?',
      whereArgs: [riderId],
      orderBy: 'created_at DESC',
      limit: 20,
    );
    return rows.map((r) => RepairRequest.fromJson(r)).toList();
  }

  // ── Nearby open requests (for mechanics / helpers) ─────────────────────────

  Future<List<RepairRequest>> getNearbyRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    final online = await ApiService.instance.isOnline;
    if (!online) return [];

    try {
      final uri =
          Uri.parse('${ApiService.baseUrl}/repair/nearby').replace(
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'radius_km': radiusKm.toString(),
        },
      );
      final response =
          await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['requests'] as List)
            .map((r) => RepairRequest.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── SQLite helpers ─────────────────────────────────────────────────────────

  Future<void> _saveLocal(RepairRequest req) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'repair_requests',
      req.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RepairRequest?> _getLocal(String id) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'repair_requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RepairRequest.fromJson(rows.first);
  }

  Future<void> _updateLocalStatus(String id, RepairStatus status) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'repair_requests',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _markSynced(String id) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'repair_requests',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
