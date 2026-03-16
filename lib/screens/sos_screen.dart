import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sos_service.dart';
import '../services/location_service.dart';
import '../models/rider.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with TickerProviderStateMixin {
  SOSState _state = SOSState.idle;
  String _statusMessage = '';
  bool _sosActive = false;
  int _countdown = 5;
  Timer? _countdownTimer;
  StreamSubscription<SOSState>? _sosSubscription;   // FIX: store subscription
  String _riderDistrict = 'Kampala';
  String _lang = 'en';

  // Animations
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnim;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    // Pulse animation for SOS button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ring expansion animation
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _ringAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    // Enable shake detection
    SOSService.instance.startShakeDetection(_onShakeDetected);

    // Listen to SOS state — store subscription to cancel in dispose
    _sosSubscription = SOSService.instance.sosStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderDistrict = prefs.getString('rider_district') ?? 'Kampala';
      _lang = prefs.getString('lang') ?? 'en';
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _countdownTimer?.cancel();
    _sosSubscription?.cancel();              // FIX: cancel stream subscription
    SOSService.instance.stopShakeDetection();
    super.dispose();
  }

  void _onShakeDetected() {
    if (!_sosActive && _state == SOSState.idle) {
      HapticFeedback.heavyImpact();
      _startSOSCountdown();
    }
  }

  void _startSOSCountdown() {
    setState(() {
      _countdown = 5;
      _sosActive = true;
    });
    _ringController.repeat();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        _sendSOS();
      } else {
        setState(() => _countdown--);
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    _ringController.stop();
    _ringController.reset();
    setState(() {
      _sosActive = false;
      _countdown = 5;
      _statusMessage = '';
    });
    SOSService.instance.cancelSOS();
  }

  Future<void> _sendSOS() async {
    _ringController.stop();
    _ringController.reset();
    HapticFeedback.heavyImpact();

    setState(() {
      _state = SOSState.sending;
      _statusMessage = 'Sending SOS...\nAlerting police & nearby riders';
    });

    final result = await SOSService.instance.triggerSOS();

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _state = result.isOffline ? SOSState.sentOffline : SOSState.sent;
        _statusMessage = result.isOffline
            ? '⚠️ SOS saved offline.\nWill send when connected.\n\nCall 999 directly!'
            : '✅ Help is on the way!\n'
                '${result.nearbyRidersAlerted} riders alerted\n'
                '${result.policeAlerted ? "Police notified ✓" : ""}';
        _sosActive = false;
      });
    } else {
      setState(() {
        _state = SOSState.failed;
        _statusMessage =
            '❌ Failed to send.\n\nCALL 999 NOW!\n${PoliceContacts.getForDistrict(_riderDistrict)['phone']}';
        _sosActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = size.width * 0.72; // ~72% screen width

    return PopScope(
      canPop: !_sosActive,
      onPopInvoked: (didPop) {
        if (!didPop && _sosActive) _cancelSOS();
      },
      child: Scaffold(
        backgroundColor: _sosActive
            ? const Color(0xFF8B0000)
            : _state == SOSState.sent
                ? const Color(0xFF1B5E20)
                : const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            'SOS EMERGENCY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          actions: [
            if (_sosActive)
              TextButton(
                onPressed: _cancelSOS,
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Status message
              if (_statusMessage.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),

              // Main SOS Button
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ring animation during active SOS
                      if (_sosActive) ...[
                        Text(
                          'Sending in $_countdown...',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding ring effect
                          if (_sosActive)
                            AnimatedBuilder(
                              animation: _ringAnim,
                              builder: (_, __) => Container(
                                width: buttonSize * (1 + _ringAnim.value * 0.4),
                                height: buttonSize * (1 + _ringAnim.value * 0.4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red
                                        .withOpacity(1 - _ringAnim.value),
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),

                          // Main SOS button
                          ScaleTransition(
                            scale: _state == SOSState.idle ? _pulseAnim
                                : const AlwaysStoppedAnimation(1.0),
                            child: GestureDetector(
                              onTap: () {
                                if (_state == SOSState.idle && !_sosActive) {
                                  _startSOSCountdown();
                                } else if (_sosActive) {
                                  _cancelSOS();
                                }
                              },
                              onLongPress: () {
                                if (!_sosActive) {
                                  _sendSOS(); // Long press = immediate
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: buttonSize,
                                height: buttonSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getButtonColor(),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getButtonColor().withOpacity(0.6),
                                      blurRadius: _sosActive ? 50 : 30,
                                      spreadRadius: _sosActive ? 10 : 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_state == SOSState.sending)
                                      const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 4,
                                      )
                                    else
                                      Icon(
                                        _getButtonIcon(),
                                        size: buttonSize * 0.35,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _getButtonText(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: buttonSize * 0.1,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    if (_sosActive) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'TAP TO CANCEL',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: buttonSize * 0.055,
                                        ),
                                      ),
                                    ] else if (_state == SOSState.idle) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'HOLD for instant',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: buttonSize * 0.055,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_state == SOSState.idle) ...[
                        const SizedBox(height: 30),
                        const Text(
                          '📳 Shake phone 3× to auto-activate',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom police info
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_police,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Police Emergency: 999 • ${PoliceContacts.getForDistrict(_riderDistrict)['phone']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getButtonColor() {
    switch (_state) {
      case SOSState.sent:
        return const Color(0xFF2E7D32);
      case SOSState.sentOffline:
        return const Color(0xFFF57F17);
      case SOSState.failed:
        return const Color(0xFF6A1B9A);
      case SOSState.cancelled:
        return const Color(0xFF424242);
      default:
        return _sosActive ? const Color(0xFFB71C1C) : const Color(0xFFD32F2F);
    }
  }

  IconData _getButtonIcon() {
    switch (_state) {
      case SOSState.sent:
        return Icons.check_circle;
      case SOSState.failed:
        return Icons.error;
      case SOSState.sentOffline:
        return Icons.wifi_off;
      case SOSState.cancelled:
        return Icons.cancel;
      default:
        return Icons.sos;
    }
  }

  String _getButtonText() {
    switch (_state) {
      case SOSState.sent:
        return 'SENT ✓';
      case SOSState.sending:
        return 'SENDING';
      case SOSState.failed:
        return 'FAILED';
      case SOSState.sentOffline:
        return 'SAVED';
      case SOSState.cancelled:
        return 'CANCELLED';
      default:
        return _sosActive ? 'CANCEL' : 'SOS';
    }
  }
}
