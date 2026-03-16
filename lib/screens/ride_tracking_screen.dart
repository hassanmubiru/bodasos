import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key});
  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  Trip? _trip;
  bool _starting = false;
  bool _ending = false;
  final MapController _map = MapController();
  Timer? _locationTimer;
  LatLng? _pos;
  String _lang = 'en';
  String _riderId = '', _riderName = '', _riderPhone = '';
  final _destCtrl = TextEditingController();
  List<LatLng> _polyline = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderId   = prefs.getString('rider_id') ?? '';
      _riderName = prefs.getString('rider_name') ?? '';
      _riderPhone = prefs.getString('rider_phone') ?? '';
      _lang      = prefs.getString('lang') ?? 'en';
    });
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _pos = LatLng(pos.latitude, pos.longitude));
    }
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  Future<void> _startTrip() async {
    if (_pos == null) {
      _snack(t('GPS not available', 'GPS teyatandika'), Colors.red);
      return;
    }
    setState(() => _starting = true);
    HapticFeedback.heavyImpact();

    final tripId = const Uuid().v4();
    final token  = tripId.substring(0, 8).toUpperCase(); // short share code

    final trip = Trip(
      id: tripId,
      riderId: _riderId,
      riderName: _riderName,
      riderPhone: _riderPhone,
      startLat: _pos!.latitude,
      startLng: _pos!.longitude,
      currentLat: _pos!.latitude,
      currentLng: _pos!.longitude,
      startLabel: _destCtrl.text.trim().isEmpty
          ? 'Current Location'
          : _destCtrl.text.trim(),
      destinationLabel: null,
      startedAt: DateTime.now(),
      shareToken: token,
    );

    // Register on server
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/trips/start'),
        headers: ApiService.instance.authHeaders,
        body: jsonEncode(trip.toJson()),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    setState(() { _trip = trip; _starting = false; _polyline.add(_pos!); });
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && _trip != null && mounted) {
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _pos = ll;
          _trip!.currentLat = pos.latitude;
          _trip!.currentLng = pos.longitude;
          _polyline.add(ll);
        });
        _map.move(ll, _map.camera.zoom);
        // Push update to server
        try {
          await http.post(
            Uri.parse('${ApiService.baseUrl}/trips/update'),
            headers: ApiService.instance.authHeaders,
            body: jsonEncode({
              'trip_id': _trip!.id,
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            }),
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}
      }
    });
  }

  Future<void> _endTrip() async {
    setState(() => _ending = true);
    _locationTimer?.cancel();
    HapticFeedback.heavyImpact();

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/trips/end'),
        headers: ApiService.instance.authHeaders,
        body: jsonEncode({'trip_id': _trip!.id}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    setState(() {
      _trip = null;
      _ending = false;
      _polyline.clear();
    });
    _snack(t('Ride ended safely ✓', 'Olugendo lwavawo bulungi ✓'), Colors.green);
  }

  void _share() {
    if (_trip == null) return;
    Share.share(
      t(
        '🏍 I\'m on a boda ride with $_riderName!\n'
        'Track my live location here:\n${_trip!.shareUrl}\n\n'
        'If I don\'t message you in 30 minutes, please call me: $_riderPhone',
        '🏍 Ndi ku lugendo lwa boda na $_riderName!\n'
        'Keb\'obubeera bwange obwa kakaano wano:\n${_trip!.shareUrl}\n\n'
        'Singa sikunze messeeji mu dakiika 30, mba yita: $_riderPhone',
      ),
      subject: 'BodaSOS Live Ride Tracking',
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('🏍', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(t('Ride Tracking', 'Okukebera Olugendo'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          if (_trip != null)
            TextButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share, size: 18, color: Colors.white),
              label: Text(t('Share', 'Gabana'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Stack(children: [
        _buildMap(),
        if (_trip == null) _buildStartPanel() else _buildActivePanel(),
      ]),
    );
  }

  Widget _buildMap() {
    if (_pos == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)));
    }
    return FlutterMap(
      mapController: _map,
      options: MapOptions(initialCenter: _pos!, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ug.bodasos.app',
        ),
        if (_polyline.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: _polyline,
              color: const Color(0xFF1A237E),
              strokeWidth: 4,
            ),
          ]),
        MarkerLayer(markers: [
          if (_pos != null)
            Marker(
              point: _pos!,
              width: 56, height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: _trip != null ? const Color(0xFF1A237E) : const Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(
                    color: (_trip != null ? const Color(0xFF1A237E) : const Color(0xFFD32F2F)).withOpacity(0.5),
                    blurRadius: 12,
                  )],
                ),
                child: const Icon(Icons.two_wheeler, color: Colors.white, size: 22),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildStartPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            const Text('🏍', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Start a Tracked Ride', 'Tandika Olugendo Olukebebwa'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                t('Share your live location with your passenger.', 'Gabana obubeera bwo n\'omuwanguzi wo.'),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ])),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _destCtrl,
            decoration: InputDecoration(
              hintText: t('Destination (optional)', 'Ekifo kw\'okuyita (si kyetaagisa)'),
              prefixIcon: const Icon(Icons.place_outlined, color: Color(0xFF1A237E)),
              filled: true, fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBCCFF)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline, size: 16, color: Color(0xFF1A237E)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                t('Only people with your share link can see your location.',
                  'Abantu abalina ekiragiro kyo kyokka be bayinza okulaba obubeera bwo.'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E), height: 1.45),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _starting ? null : _startTrip,
              icon: _starting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _starting ? t('Starting…', 'Okutandika…') : t('Start Tracking', 'Tandika Okukebera'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildActivePanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // Active status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBCCFF)),
            ),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFF1A237E), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Live tracking active', 'Okukebera okwa kakaano'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A237E))),
                Text(
                  t('Duration: ${_trip!.durationText}', 'Obuwanvu: ${_trip!.durationText}'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ])),
              const Icon(Icons.radio_button_checked, color: Color(0xFF1A237E), size: 18),
            ]),
          ),
          const SizedBox(height: 12),

          // Share link box
          GestureDetector(
            onTap: _share,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(children: [
                const Icon(Icons.link, color: Color(0xFF1A237E), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_trip?.shareUrl ?? '',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF1A237E)),
                    overflow: TextOverflow.ellipsis)),
                const Icon(Icons.share, size: 16, color: Colors.grey),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share, size: 18),
                label: Text(t('Share Link', 'Gabana Ekisinze')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                  side: const BorderSide(color: Color(0xFF1A237E)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _ending ? null : _endTrip,
                icon: _ending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.stop_circle_outlined),
                label: Text(t('End Ride', 'Maliiriza Olugendo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
