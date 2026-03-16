import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_screen.dart';
import 'invite_screen.dart';
import 'repair_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'ride_tracking_screen.dart';
import 'mechanic_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _riderName = '';
  String _riderStage = '';
  String _riderDistrict = 'Kampala';
  Position? _currentPosition;
  List<Rider> _nearbyRiders = [];
  bool _isLoadingLocation = true;
  bool _isLoadingRiders = false;
  bool _isOnline = false;
  bool _isFirstLoad = true;
  Timer? _refreshTimer;
  String _lang = 'en';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadProfile();
    _initLocation();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchNearbyRiders();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderName = prefs.getString('rider_name') ?? '';
      _riderStage = prefs.getString('rider_stage') ?? '';
      _riderDistrict = prefs.getString('rider_district') ?? 'Kampala';
      _lang = prefs.getString('lang') ?? 'en';
    });
  }

  Future<void> _initLocation() async {
    await LocationService.instance.startTracking();
    final pos = await LocationService.instance.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
    }
    await _fetchNearbyRiders();
  }

  Future<void> _fetchNearbyRiders() async {
    if (_currentPosition == null) return;
    setState(() => _isLoadingRiders = true);
    final online = await ApiService.instance.isOnline;
    final riders = await ApiService.instance.getNearbyRiders(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
    );
    if (mounted) {
      setState(() {
        _nearbyRiders = riders;
        _isOnline = online;
        _isLoadingRiders = false;
        _isFirstLoad = false;
      });
    }
  }

  bool get _hasNoRiders => !_isFirstLoad && _nearbyRiders.isEmpty;

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomNav(),
      body: RefreshIndicator(
        color: const Color(0xFFD32F2F),
        onRefresh: _initLocation,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreetingCard(),
              const SizedBox(height: 14),
              _buildSOSTile(),
              const SizedBox(height: 14),
              _buildLocationTile(),
              const SizedBox(height: 14),
              _buildPoliceTile(),
              const SizedBox(height: 14),
              _buildRepairTile(),
              const SizedBox(height: 14),
              _buildQuickActions(),
              const SizedBox(height: 14),
              _buildRidersSection(),
              if (_hasNoRiders) ...[
                const SizedBox(height: 14),
                _buildGrowNetworkBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFD32F2F),
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('🏍', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          const Text('BodaSOS',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ],
      ),
      actions: [
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.withOpacity(0.25) : Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOnline
                    ? Colors.greenAccent.withOpacity(0.6)
                    : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.greenAccent : Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            if (v == 'profile') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            } else if (v == 'history') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            } else if (v == 'mechanic') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicRegisterScreen()));
            } else if (v == 'invite') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen()));
            } else if (v == 'lang') {
              final prefs = await SharedPreferences.getInstance();
              final n = _lang == 'en' ? 'lg' : 'en';
              await prefs.setString('lang', n);
              setState(() => _lang = n);
            } else if (v == 'logout') {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(children: [
                const Icon(Icons.person_outline, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 10),
                Text(t('My Profile', 'Eprofile Yange')),
              ]),
            ),
            PopupMenuItem(
              value: 'history',
              child: Row(children: [
                const Icon(Icons.history_rounded, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 10),
                Text(t('My History', 'Ebyakolebwa')),
              ]),
            ),
            PopupMenuItem(
              value: 'mechanic',
              child: Row(children: [
                const Icon(Icons.handyman_rounded, color: Color(0xFFE65100), size: 20),
                const SizedBox(width: 10),
                Text(t('Register as Mechanic', 'Kwandika Nga Fumbi')),
              ]),
            ),
            PopupMenuItem(
              value: 'invite',
              child: Row(children: [
                const Icon(Icons.person_add, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 10),
                Text(t('Invite Riders', 'Yita Abasomi')),
              ]),
            ),
            PopupMenuItem(
              value: 'lang',
              child: Row(children: [
                const Text('🇺🇬', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(_lang == 'en' ? 'Switch to Luganda' : 'Switch to English'),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                const Icon(Icons.logout, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Text(t('Logout', 'Ggya')),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFF9A0007)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withOpacity(0.3),
            blurRadius: 18, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('🏍', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oli otya, $_riderName! 👋',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 13, color: Colors.white60),
                    const SizedBox(width: 3),
                    Text('$_riderStage · $_riderDistrict',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              const SizedBox(height: 3),
              const Text('Active',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SOSScreen()),
      ),
      child: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD32F2F).withOpacity(0.45),
                blurRadius: 24, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🆘', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('TAP FOR EMERGENCY SOS', 'KUBA SOS'),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t('Shake phone 3× to auto-trigger', 'Nyeenye simu emirundi 3'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.white60, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(
            icon: Icons.my_location,
            label: t('Your GPS Location', 'Obubeera bwo'),
            trailing: _isLoadingLocation
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFD32F2F)),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (_currentPosition != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _coordRow('LAT', _currentPosition!.latitude.toStringAsFixed(6)),
                  const Divider(height: 10, thickness: 0.5),
                  _coordRow('LNG', _currentPosition!.longitude.toStringAsFixed(6)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 13, color: Colors.green),
                const SizedBox(width: 5),
                Text(
                  '±${_currentPosition!.accuracy.toStringAsFixed(0)}m accuracy  •  Updates every 30s',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ] else
            Text(
              _isLoadingLocation
                  ? t('Getting your location…', 'Tunoonyeza obubeera bwo…')
                  : t('⚠️ GPS unavailable. Check location settings.',
                      '⚠️ GPS teyatandika.'),
              style: TextStyle(
                fontSize: 13,
                color: _isLoadingLocation ? Colors.grey[400] : Colors.orange[700],
              ),
            ),
        ],
      ),
    );
  }

  Widget _coordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, letterSpacing: 0.12,
                color: Colors.grey[500], fontFamily: 'monospace')),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(children: [
      Expanded(child: _quickTile(
        '🗺️', t('Map', 'Maapu'),
        t('See riders nearby', 'Laba abasomi'),
        const Color(0xFF1565C0), const Color(0xFFE3F2FD),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
      )),
      const SizedBox(width: 10),
      Expanded(child: _quickTile(
        '🏍', t('Track Ride', 'Kebera Olugendo'),
        t('Share live location', 'Gabana obubeera'),
        const Color(0xFF1A237E), const Color(0xFFE8EAF6),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideTrackingScreen())),
      )),
      const SizedBox(width: 10),
      Expanded(child: _quickTile(
        '🔧', t('Mechanic', 'Fumbi'),
        t('Register as mechanic', 'Kwandika nga fumbi'),
        const Color(0xFFE65100), const Color(0xFFFBE9E7),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicRegisterScreen())),
      )),
    ]);
  }

  Widget _quickTile(String emoji, String title, String sub, Color accent, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: accent)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _buildRepairTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RepairScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFCCBC), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE65100).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🔧', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Bike Repair Help', 'Obuyambi bwa Boda'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'Stuck on the road? Alert nearby riders & mechanics.',
                      'Ogumiidde mu kkubo? Tegeeza abasomi n\'abafumbi.',
                    ),
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t('GET HELP', 'SABA'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoliceTile() {
    final police = PoliceContacts.getForDistrict(_riderDistrict);
    final phone = police['phone'] ?? '+256999';
    return GestureDetector(
      onTap: () async {
        final uri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: _buildCard(
        color: const Color(0xFF0D1B5E),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🚔', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(police['name'] ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${t("Tap to call", "Kuba okuyita")} · ${police['emergency']}  •  $phone',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRidersSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tileHeader(
            icon: Icons.people_alt_rounded,
            label: t('Riders Nearby', 'Abasomi Abeggerereddwa'),
            trailing: GestureDetector(
              onTap: _fetchNearbyRiders,
              child: const Icon(Icons.refresh, size: 18, color: Color(0xFFD32F2F)),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoadingRiders)
            _buildSkeletons()
          else if (_hasNoRiders)
            _buildNoRidersEmpty()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _nearbyRiders.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.4),
              itemBuilder: (_, i) => _buildRiderTile(_nearbyRiders[i]),
            ),
        ],
      ),
    );
  }

  // ── EMPTY STATE: No riders yet ─────────────────────────────────────────────
  Widget _buildNoRidersEmpty() {
    return Column(
      children: [
        // Illustration container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Column(
            children: [
              // Animated bikes row
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🏍', style: TextStyle(fontSize: 36)),
                  SizedBox(width: 6),
                  Text('?', style: TextStyle(fontSize: 28, color: Color(0xFFEF9A9A))),
                  SizedBox(width: 6),
                  Text('?', style: TextStyle(fontSize: 28, color: Color(0xFFEF9A9A))),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                t('You\'re the first rider here!', 'Ggwe osooka ku siteeji eno!'),
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF9A0007),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'No other riders have joined BodaSOS in your area yet. '
                  'Invite your stage-mates — the more riders join, '
                  'the faster help arrives in an emergency.',
                  'Abasomi abalala tebakyayingira BodaSOS mu kitundu kyo. '
                  'Yita ab\'esiteeji yo — abasomi bangi bayingira, '
                  'obuyambi butuuka amangu.',
                ),
                style: TextStyle(
                  fontSize: 13, color: Colors.grey[600], height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // SOS still works reassurance box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBCCFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    t('SOS still works right now!', 'SOS erimu okola kaakano!'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _reassureRow('🚔',
                  t('Police are alerted instantly on SOS',
                      'Apolisi bategeezebwa amangu ku SOS')),
              _reassureRow('📍',
                  t('Your live GPS is shared with authorities',
                      'GPS yo egabanyizibwa n\'abalunzi')),
              _reassureRow('📲',
                  t('As riders join, they\'ll receive your SOS too',
                      'Nga abasomi bayingira, naabo balifuna SOS yo')),
              _reassureRow('📵',
                  t('Offline? SOS is saved and sent when reconnected',
                      'Ng\'oli offline? SOS egumizibwa n\'okutumibwa ng\'odzza mu network')),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Invite button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InviteScreen()),
            ),
            icon: const Icon(Icons.person_add, size: 20),
            label: Text(
              t('Invite Riders to BodaSOS', 'Yita Abasomi ku BodaSOS'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              shadowColor: const Color(0xFFD32F2F).withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reassureRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF37474F), height: 1.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navBtn(Icons.map_outlined, t('Map', 'Maapu'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
              _navBtn(Icons.history_rounded, t('History', 'Ebyakolebwa'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
              _navBtn(Icons.chat_bubble_outline, t('Messages', 'Obubaka'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()))),
              _navBtn(Icons.route_outlined, t('Track', 'Kebera'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideTrackingScreen()))),
              _navBtn(Icons.person_outline, t('Profile', 'Eprofile'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildGrowNetworkBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('Grow Your Safety Network', 'Yiwa Omutimbagano Ogw\'Obukuumi'),
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t(
              'Every rider you invite makes the network stronger. '
              'Share BodaSOS with your stage-mates, SACCO members, '
              'and fellow riders today.',
              'Omusirikale buli oyo oyita akola omutimbagano guwa amaanyi. '
              'Gabana BodaSOS n\'ab\'esiteeji yo, ab\'omu SACCO, '
              'n\'abasomi mukwano bo leero.',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteScreen()),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: Text(t('Share Invite Link', 'Gabana Olukalala Lw\'Okulayirira')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderTile(Rider rider) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor:
            rider.isOnline ? const Color(0xFF4CAF50) : Colors.grey[200],
        child: Text(
          rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: rider.isOnline ? Colors.white : Colors.grey[500],
            fontWeight: FontWeight.w800, fontSize: 16,
          ),
        ),
      ),
      title: Text(rider.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(rider.stage,
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            rider.formattedDistance,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rider.isOnline
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rider.isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: rider.isOnline
                    ? const Color(0xFF2E7D32)
                    : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletons() {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _skeleton(40, 40, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeleton(16, double.infinity),
                  const SizedBox(height: 6),
                  _skeleton(12, 100),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _skeleton(12, 60),
          ],
        ),
      )),
    );
  }

  Widget _skeleton(double h, double w, {double radius = 6}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        height: h, width: w,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFEEEEEE),
            const Color(0xFFDDDDDD),
            (_pulseController.value + 1) / 2,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _tileHeader({
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFD32F2F)),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }
}
