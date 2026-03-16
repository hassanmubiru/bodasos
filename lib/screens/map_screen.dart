import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  List<Rider> _riders = [];
  LatLng? _myPos;
  bool _loading = true;
  Rider? _selected;
  String _lang = 'en';
  Timer? _refreshTimer;
  double _radius = 5.0; // km

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRiders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('lang') ?? 'en';

    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _myPos = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
      _mapCtrl.move(_myPos!, 14);
      await _fetchRiders();
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchRiders() async {
    if (_myPos == null) return;
    final riders = await ApiService.instance.getNearbyRiders(
      latitude: _myPos!.latitude,
      longitude: _myPos!.longitude,
      radiusKm: _radius,
    );
    if (mounted) setState(() => _riders = riders);
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('🗺️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(t('Nearby Riders', 'Abasomi Abeggerereddwa'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_riders.where((r) => r.isOnline).length} ${t("online", "omukuumi")}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : Stack(children: [
              _buildMap(),
              _buildRadiusChips(),
              if (_selected != null) _buildRiderCard(),
              _buildLegend(),
            ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD32F2F),
        onPressed: () {
          if (_myPos != null) {
            _mapCtrl.move(_myPos!, 14);
            setState(() => _selected = null);
          }
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildMap() {
    if (_myPos == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.location_off, size: 56, color: Colors.white38),
        const SizedBox(height: 16),
        Text(t('Could not get your location.\nMake sure GPS is on.',
            'Tunafiirwa obubeera bwo.\nKebera nti GPS etandise.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 15),
        ),
      ]));
    }

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _myPos!,
        initialZoom: 14,
        onTap: (_, __) => setState(() => _selected = null),
      ),
      children: [
        // OpenStreetMap tiles — no API key required
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ug.bodasos.app',
        ),

        // Radius circle
        CircleLayer(circles: [
          CircleMarker(
            point: _myPos!,
            radius: _radius * 1000,   // metres
            useRadiusInMeter: true,
            color: const Color(0xFFD32F2F).withOpacity(0.06),
            borderColor: const Color(0xFFD32F2F).withOpacity(0.25),
            borderStrokeWidth: 1.5,
          ),
        ]),

        // Rider markers
        MarkerLayer(
          markers: [
            // My position
            Marker(
              point: _myPos!,
              width: 56, height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFD32F2F).withOpacity(0.5),
                        blurRadius: 10,
                      )],
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            // Other riders
            ..._riders.map((rider) => Marker(
              point: LatLng(rider.latitude ?? 0, rider.longitude ?? 0),
              width: 48, height: 60,
              child: GestureDetector(
                onTap: () => setState(() => _selected = rider),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _selected?.id == rider.id
                            ? const Color(0xFF1565C0)
                            : rider.isOnline
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
                      ),
                      child: Center(
                        child: Text(
                          rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rider.name.split(' ').first,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildRadiusChips() {
    return Positioned(
      top: 12, left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('Radius:', 'Eddungu:'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            ...[2.0, 5.0, 10.0].map((r) => GestureDetector(
              onTap: () {
                setState(() => _radius = r);
                _fetchRiders();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _radius == r ? const Color(0xFFD32F2F) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${r.toInt()}km',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _radius == r ? Colors.white : Colors.grey[700],
                    )),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderCard() {
    final r = _selected!;
    return Positioned(
      bottom: 90, left: 16, right: 16,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: r.isOnline ? const Color(0xFF2E7D32) : Colors.grey[300],
                child: Text(
                  r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20,
                    color: r.isOnline ? Colors.white : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(r.stage, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: r.isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      r.isOnline ? t('Online now', 'Omukuumi kaakano') : t('Offline', 'Simukyali'),
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: r.isOnline ? const Color(0xFF2E7D32) : Colors.grey,
                      ),
                    ),
                    if (r.formattedDistance.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text('• ${r.formattedDistance}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ]),
                ],
              )),
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 16, left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendItem(const Color(0xFFD32F2F), t('You', 'Ggwe')),
            const SizedBox(height: 4),
            _legendItem(const Color(0xFF2E7D32), t('Online rider', 'Omuvuzi omukuumi')),
            const SizedBox(height: 4),
            _legendItem(Colors.grey, t('Offline rider', 'Omuvuzi simukyali')),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ],
  );
}
