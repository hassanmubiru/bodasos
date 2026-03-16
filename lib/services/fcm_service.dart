import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;

// Top-level handler for background messages (required by FCM)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  await Firebase.initializeApp();
  _FCMService._handleMessage(msg, background: true);
}

class _FCMService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static void _handleMessage(RemoteMessage msg, {bool background = false}) {
    final data = msg.data;
    final type = data['type'] ?? '';

    // Local notification for foreground / background
    final title = msg.notification?.title ?? _titleForType(type);
    final body = msg.notification?.body ?? data['body'] ?? '';

    _local.show(
      msg.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdForType(type),
          _channelNameForType(type),
          importance: type == 'sos' ? Importance.max : Importance.high,
          priority: type == 'sos' ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static String _titleForType(String type) {
    switch (type) {
      case 'sos':     return '🆘 EMERGENCY ALERT!';
      case 'repair':  return '🔧 Repair Request Nearby';
      case 'message': return '💬 New Message';
      case 'trip':    return '🏍 Ride Tracking Update';
      default:        return 'BodaSOS';
    }
  }

  static String _channelIdForType(String type) {
    switch (type) {
      case 'sos':    return 'bodasos_sos';
      case 'repair': return 'bodasos_repair';
      default:       return 'bodasos_general';
    }
  }

  static String _channelNameForType(String type) {
    switch (type) {
      case 'sos':    return 'SOS Emergencies';
      case 'repair': return 'Repair Requests';
      default:       return 'BodaSOS Notifications';
    }
  }
}

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission (iOS + Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,    // needed for SOS to sound through DND
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Init local notifications
    await _FCMService._local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Create notification channels
    await _createChannels();

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((msg) {
      _FCMService._handleMessage(msg);
    });

    // Register token with backend
    await _registerToken();

    // Refresh token when it rotates
    _fcm.onTokenRefresh.listen((token) async {
      await _sendTokenToServer(token);
    });
  }

  Future<void> _createChannels() async {
    const android = AndroidFlutterLocalNotificationsPlugin;
    final plugin = _FCMService._local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(const AndroidNotificationChannel(
      'bodasos_sos',
      'SOS Emergencies',
      description: 'Emergency SOS alerts from nearby riders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
    await plugin?.createNotificationChannel(const AndroidNotificationChannel(
      'bodasos_repair',
      'Repair Requests',
      description: 'Nearby bike repair requests',
      importance: Importance.high,
    ));
    await plugin?.createNotificationChannel(const AndroidNotificationChannel(
      'bodasos_general',
      'BodaSOS Notifications',
      description: 'General BodaSOS notifications',
      importance: Importance.defaultImportance,
    ));
  }

  Future<void> _registerToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _sendTokenToServer(token);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final riderId = prefs.getString('rider_id') ?? '';
      if (riderId.isEmpty) return;

      await http.post(
        Uri.parse('${ApiService.baseUrl}/fcm_token'),
        headers: ApiService.instance.authHeaders,
        body: jsonEncode({'rider_id': riderId, 'fcm_token': token}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<String?> getToken() => _fcm.getToken();

  /// Subscribe to topic — e.g. 'district_Kampala'
  Future<void> subscribeToTopic(String topic) =>
      _fcm.subscribeToTopic(topic.replaceAll(' ', '_').toLowerCase());

  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic.replaceAll(' ', '_').toLowerCase());
}
