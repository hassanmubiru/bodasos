import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/repair_service.dart';
import '../models/repair.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _sosHistory = [];
  List<RepairRequest> _repairHistory = [];
  bool _loading = true;
  String _lang = 'en';
  String _riderId = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _riderId = prefs.getString('rider_id') ?? '';
    _lang = prefs.getString('lang') ?? 'en';

    final sos = await DatabaseService.instance.getSOSHistory();
    final repairs = await RepairService.instance.getMyRequests(_riderId);

    if (mounted) {
      setState(() {
        _sosHistory = sos;
        _repairHistory = repairs;
        _loading = false;
      });
    }
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM y · HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Text(t('My History', 'Ebyakolebwa'), style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: t('SOS Events', 'Obuyambi bwa SOS')),
            Tab(text: t('Repair Requests', 'Okusaba Okuddaabiriza')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : TabBarView(
              controller: _tabs,
              children: [_buildSOSTab(), _buildRepairTab()],
            ),
    );
  }

  // ── SOS Tab ──────────────────────────────────────────────────────────────

  Widget _buildSOSTab() {
    if (_sosHistory.isEmpty) return _empty('🆘', t('No SOS events yet', 'Tewali SOS eyakolebwa'));
    return RefreshIndicator(
      color: const Color(0xFFD32F2F),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sosHistory.length,
        itemBuilder: (_, i) => _SOSTile(item: _sosHistory[i], formatDate: _formatDate, t: t),
      ),
    );
  }

  // ── Repair Tab ────────────────────────────────────────────────────────────

  Widget _buildRepairTab() {
    if (_repairHistory.isEmpty) {
      return _empty('🔧', t('No repair requests yet', 'Tewali okusaba okuddaabiriza'));
    }
    return RefreshIndicator(
      color: const Color(0xFFD32F2F),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _repairHistory.length,
        itemBuilder: (_, i) => _RepairTile(req: _repairHistory[i], lang: _lang),
      ),
    );
  }

  Widget _empty(String emoji, String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      Text(msg, style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(t('Events will appear here once they happen.', 'Ebyakolebwa bijja kujjira wano.'),
          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
    ]));
  }
}

// ── SOS Tile ──────────────────────────────────────────────────────────────────

class _SOSTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String?) formatDate;
  final String Function(String, String) t;
  const _SOSTile({required this.item, required this.formatDate, required this.t});

  @override
  Widget build(BuildContext context) {
    final synced = item['synced'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: synced ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: synced ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(synced ? '✅' : '⏳', style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('🆘 SOS Alert', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: synced ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    synced ? t('Sent ✓', 'Yatumibwa ✓') : t('Pending', 'Olindirira'),
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: synced ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '📍 ${item['latitude']?.toStringAsFixed(4) ?? '—'}, ${item['longitude']?.toStringAsFixed(4) ?? '—'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace'),
              ),
              const SizedBox(height: 3),
              Text(formatDate(item['timestamp']?.toString()),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          )),
        ],
      ),
    );
  }
}

// ── Repair Tile ───────────────────────────────────────────────────────────────

class _RepairTile extends StatelessWidget {
  final RepairRequest req;
  final String lang;
  const _RepairTile({required this.req, required this.lang});

  Color get _statusColor {
    switch (req.status) {
      case RepairStatus.done:       return const Color(0xFF2E7D32);
      case RepairStatus.cancelled:  return Colors.grey;
      case RepairStatus.pending:    return const Color(0xFFE65100);
      default:                      return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = lang == 'lg' ? req.issue.labelLg : req.issue.label;
    final statusLabel = lang == 'lg' ? req.status.labelLg : req.status.label;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFBE9E7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(req.issue.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('📍 ${req.stage}, ${req.district}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 3),
              Text(req.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              if (req.respondersCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${req.respondersCount} riders alerted',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                ),
            ],
          )),
        ],
      ),
    );
  }
}
