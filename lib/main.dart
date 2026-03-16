import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/database_service.dart';
import 'services/fcm_service.dart';

void main() async {
  // Catch async errors outside Flutter's widget tree
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Portrait only — more reliable for emergency use
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Initialize local database before rendering
    await DatabaseService.instance.database;

    // Initialize Firebase + FCM push notifications
    // NOTE: requires google-services.json in android/app/
    // Get it free from console.firebase.google.com
    try {
      await Firebase.initializeApp();
      await FCMService.instance.init();
      // Subscribe to district topic for push alerts
      final prefs = await SharedPreferences.getInstance();
      final district = prefs.getString('rider_district') ?? '';
      if (district.isNotEmpty) {
        await FCMService.instance.subscribeToTopic('district_$district');
      }
    } catch (_) {
      // Firebase not configured yet — app still works via SMS
    }

    runApp(const BodaSOSApp());
  }, (error, stack) {
    // Log unhandled errors in production
    debugPrint('Unhandled error: $error');
    debugPrint('Stack: $stack');
  });
}

class BodaSOSApp extends StatelessWidget {
  const BodaSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BodaSOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
          ),
        ),
      ),
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    // Brief splash so DB has time to init
    await Future.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('rider_id');
    if (mounted) {
      setState(() {
        _isLoggedIn = riderId != null && riderId.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _SplashScreen();
    return FadeTransition(
      opacity: _fadeAnim,
      child: _isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  children: [
                    // Logo mark
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.two_wheeler,     // ✅ correct icon
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'BodaSOS',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'One Tap Saves Lives',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 3),
            // Uganda flag strip
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _flagStripe(const Color(0xFF000000)),
                      _flagStripe(const Color(0xFFFCDC04)),
                      _flagStripe(const Color(0xFFD90000)),
                      _flagStripe(const Color(0xFF000000)),
                      _flagStripe(const Color(0xFFFCDC04)),
                      _flagStripe(const Color(0xFFD90000)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Made for Uganda\'s Road Warriors 🏍',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagStripe(Color color) {
    return Container(
      width: 20,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 1),
    );
  }
}
