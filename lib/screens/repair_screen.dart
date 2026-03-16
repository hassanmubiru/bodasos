import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/repair.dart';
import '../services/repair_service.dart';
import '../services/location_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR SCREEN — entry point (issue picker)
// ═══════════════════════════════════════════════════════════════════════════
class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key});

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen>
    with SingleTickerProviderStateMixin {
  BikeIssue? _selectedIssue;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  String _lang = 'en';

  // Profile
  String _riderId = '';
  String _riderName = '';
  String _riderPhone = '';
  String _riderStage = '';
  String _riderDistrict = 'Kampala';

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadProfile();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderId = prefs.getString('rider_id') ?? '';
      _riderName = prefs.getString('rider_name') ?? '';
      _riderPhone = prefs.getString('rider_phone') ?? '';
      _riderStage = prefs.getString('rider_stage') ?? '';
      _riderDistrict = prefs.getString('rider_district') ?? 'Kampala';
      _lang = prefs.getString('lang') ?? 'en';
    });
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  Future<void> _submit() async {
    if (_selectedIssue == null) {
      _showSnack(t('Please select what\'s wrong with your bike.',
          'Funa ekizibu kya boda yo.'), Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) {
      setState(() => _isSubmitting = false);
      _showSnack(
        t('Cannot get your location. Is GPS on?',
            'Tunafiirwa obubeera bwo. GPS ekyuse?'),
        Colors.red,
      );
      return;
    }

    final req = RepairRequest(
      id: const Uuid().v4(),
      riderId: _riderId,
      riderName: _riderName,
      riderPhone: _riderPhone,
      issue: _selectedIssue!,
      customNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      latitude: position.latitude,
      longitude: position.longitude,
      stage: _riderStage,
      district: _riderDistrict,
      createdAt: DateTime.now(),
    );

    final result = await RepairService.instance.submitRequest(req);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RepairStatusScreen(
            request: req,
            isOffline: result['offline'] == true,
            respondersCount: result['responders_alerted'] as int? ?? 0,
          ),
        ),
      );
    } else {
      _showSnack(
        result['error']?.toString() ??
            t('Failed to send. Try again.', 'Kutuma kwagoba. Gezaako nate.'),
        Colors.red,
      );
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('🔧', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(t('Bike Repair Help', 'Obuyambi bwa Boda'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildSectionLabel(
                t('What\'s wrong with your bike?', 'Ekizibu ki ku boda yo?')),
            const SizedBox(height: 12),
            _buildIssueGrid(),
            if (_selectedIssue != null) ...[
              const SizedBox(height: 20),
              _buildNoteField(),
            ],
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 16),
            _buildInfoNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFBF360C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🏍', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Stuck on the road?', 'Ogumiidde mu kkubo?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'Alert nearby riders and mechanics instantly.',
                    'Tegeeza abasomi n\'abafumbi abeggerereddwa amangu.',
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF212121),
      ),
    );
  }

  Widget _buildIssueGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: BikeIssue.values.length,
      itemBuilder: (_, i) {
        final issue = BikeIssue.values[i];
        final selected = _selectedIssue == issue;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedIssue = issue);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE65100) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFE65100)
                    : issue.isUrgent
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFFEEEEEE),
                width: selected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0xFFE65100).withOpacity(0.3)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: selected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(issue.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Text(
                  _lang == 'lg' ? issue.labelLg : issue.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF424242),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (issue.isUrgent && !selected) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('URGENT',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD32F2F),
                            letterSpacing: 0.3)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(t('Add more details (optional)',
            'Gattako ebigambo ebisingawo (si byetaagisa)')),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: t(
              'e.g. "Chain snapped near Shell petrol station, Kireka road"',
              'e.g. "Cheeni eyatema okumpi na petulo ya Shell, kkubo ya Kireka"',
            ),
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE65100), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _selectedIssue != null && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? _submit : null,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.build_circle_rounded, size: 22),
        label: Text(
          _isSubmitting
              ? t('Sending alert…', 'Okutuma…')
              : t('Request Repair Help', 'Saba Obuyambi bwa Okuddaabiriza'),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canSubmit ? 4 : 0,
          shadowColor: const Color(0xFFE65100).withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                'Your GPS location will be shared with nearby riders and '
                'mechanics so they can find you quickly. '
                'Works offline — request is saved and sent when reconnected.',
                'Obubeera bwo ogw\'eddiro bugabanyizibwa n\'abasomi n\'abafumbi '
                'abeggerereddwa okuba bayinza okunoonyereza amangu. '
                'Ekola nga tewali network — okusaba kugumizibwa n\'okutumibwa ng\'odzza.',
              ),
              style: TextStyle(
                  fontSize: 12.5, color: Colors.brown[700], height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR STATUS SCREEN — live tracking after submission
// ═══════════════════════════════════════════════════════════════════════════
class RepairStatusScreen extends StatefulWidget {
  final RepairRequest request;
  final bool isOffline;
  final int respondersCount;

  const RepairStatusScreen({
    super.key,
    required this.request,
    this.isOffline = false,
    this.respondersCount = 0,
  });

  @override
  State<RepairStatusScreen> createState() => _RepairStatusScreenState();
}

class _RepairStatusScreenState extends State<RepairStatusScreen>
    with SingleTickerProviderStateMixin {
  late RepairRequest _req;
  Timer? _pollTimer;
  bool _isCancelling = false;
  String _lang = 'en';

  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;

  @override
  void initState() {
    super.initState();
    _req = widget.request;
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _spinAnim =
        Tween<double>(begin: 0, end: 1).animate(_spinCtrl);

    _loadLang();

    // Poll for status updates every 15 seconds
    if (!widget.isOffline) {
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    }
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _lang = prefs.getString('lang') ?? 'en');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final updated = await RepairService.instance.getStatus(_req.id);
    if (mounted && updated != null) {
      setState(() => _req = updated);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_lang == 'lg' ? 'Kansila Okusaba?' : 'Cancel Request?'),
        content: Text(_lang == 'lg'
            ? 'Oyagala kukansila okusaba kw\'obuyambi?'
            : 'Are you sure you want to cancel the repair request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_lang == 'lg' ? 'Nedda' : 'No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_lang == 'lg' ? 'Yee, Kansila' : 'Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isCancelling = true);
    await RepairService.instance.cancelRequest(
      requestId: _req.id,
      riderId: widget.request.riderId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  Color get _statusColor {
    switch (_req.status) {
      case RepairStatus.pending:    return const Color(0xFFFF8F00);
      case RepairStatus.accepted:   return const Color(0xFF1565C0);
      case RepairStatus.onTheWay:   return const Color(0xFF2E7D32);
      case RepairStatus.arrived:    return const Color(0xFF00897B);
      case RepairStatus.done:       return const Color(0xFF2E7D32);
      case RepairStatus.cancelled:  return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          title: Text(t('Repair Request', 'Okusaba Okuddaabiriza'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (_req.status == RepairStatus.pending ||
                _req.status == RepairStatus.accepted)
              TextButton(
                onPressed: _isCancelling ? null : _cancel,
                child: Text(
                  t('Cancel', 'Kansila'),
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildRequestDetails(),
              const SizedBox(height: 16),
              if (_req.mechanicName != null) _buildMechanicCard(),
              if (_req.mechanicName != null) const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 16),
              _buildTips(),
              if (_req.status == RepairStatus.done) ...[
                const SizedBox(height: 20),
                _buildDoneCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isPending = _req.status == RepairStatus.pending;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isPending)
            RotationTransition(
              turns: _spinAnim,
              child: const Icon(Icons.sync, color: Colors.white, size: 44),
            )
          else
            Icon(_statusIcon(), color: Colors.white, size: 44),
          const SizedBox(height: 14),
          Text(
            _lang == 'lg' ? _req.status.labelLg : _req.status.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.isOffline && isPending) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t('⚠️ Saved offline — will alert when connected',
                    '⚠️ Yakumizibwa offline — enotifya nga network edzaayo'),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (widget.respondersCount > 0 && isPending) ...[
            const SizedBox(height: 8),
            Text(
              t(
                '${widget.respondersCount} riders notified near you',
                'Abasomi ${widget.respondersCount} bategeezeddwa okumpi nawe',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _req.timeAgo,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon() {
    switch (_req.status) {
      case RepairStatus.accepted:   return Icons.check_circle_outline;
      case RepairStatus.onTheWay:   return Icons.directions_bike;
      case RepairStatus.arrived:    return Icons.handshake;
      case RepairStatus.done:       return Icons.verified;
      case RepairStatus.cancelled:  return Icons.cancel;
      default:                       return Icons.sync;
    }
  }

  Widget _buildRequestDetails() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.build, t('Your Request', 'Okusaba Kwo')),
          const SizedBox(height: 14),
          _detailRow(
            _req.issue.emoji,
            _lang == 'lg' ? _req.issue.labelLg : _req.issue.label,
            _req.issue.isUrgent
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('URGENT',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD32F2F))),
                  )
                : null,
          ),
          if (_req.customNote != null) ...[
            const Divider(height: 16),
            _detailRow('📝', _req.customNote!),
          ],
          const Divider(height: 16),
          _detailRow('📍', '${_req.stage}, ${_req.district}'),
          const Divider(height: 16),
          _detailRow(
            '🗺️',
            '${_req.latitude.toStringAsFixed(5)}, ${_req.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicCard() {
    return _card(
      color: const Color(0xFFE8F5E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.handyman, t('Your Mechanic', 'Fumbi Wo'),
              color: const Color(0xFF2E7D32)),
          const SizedBox(height: 14),
          _detailRow('👤', _req.mechanicName ?? ''),
          const Divider(height: 16),
          _detailRow('📞', _req.mechanicPhone ?? ''),
          if (_req.mechanicDistanceKm != null) ...[
            const Divider(height: 16),
            _detailRow(
              '📍',
              '${_req.mechanicDistanceKm!.toStringAsFixed(1)}km away'
              '${_req.estimatedMinutes != null ? " · ~${_req.estimatedMinutes}min" : ""}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final steps = [
      (
        RepairStatus.pending,
        t('Request sent', 'Okusaba kutumibwa'),
        '🔧'
      ),
      (
        RepairStatus.accepted,
        t('Mechanic found', 'Fumbi azuulidwa'),
        '👷'
      ),
      (
        RepairStatus.onTheWay,
        t('Mechanic on the way', 'Fumbi ajja'),
        '🏍'
      ),
      (
        RepairStatus.arrived,
        t('Mechanic arrived', 'Fumbi atuuse'),
        '🤝'
      ),
      (
        RepairStatus.done,
        t('Repair complete', 'Okuddaabiriza kwavaawo'),
        '✅'
      ),
    ];

    final currentIdx = steps.indexWhere((s) => s.$1 == _req.status);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.timeline, t('Progress', 'Enkyukakyuka')),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final idx = e.key;
            final step = e.value;
            final isDone = idx <= currentIdx;
            final isActive = idx == currentIdx;
            return _timelineStep(
              emoji: step.$3,
              label: step.$2,
              isDone: isDone,
              isActive: isActive,
              isLast: idx == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required String emoji,
    required String label,
    required bool isDone,
    required bool isActive,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEEEEEE),
                border: isActive
                    ? Border.all(color: const Color(0xFFE65100), width: 2.5)
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE65100).withOpacity(0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            if (!isLast)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 2,
                height: 28,
                color: isDone
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isActive ? FontWeight.w800 : FontWeight.w400,
              color: isDone
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF9E9E9E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTips() {
    if (_req.status == RepairStatus.done ||
        _req.status == RepairStatus.cancelled) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('While you wait…', 'Nga olindirira…'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _tipRow('🚦',
              t('Move your bike off the road if safe to do so',
                  'Singa obinagala, yimusa boda yo okuva mu kkubo')),
          _tipRow('💡',
              t('Turn on your hazard lights if your bike has them',
                  'Kyusa amatangaaza go singa boda yo girina')),
          _tipRow('📍',
              t('Stay near your location — help is coming to you',
                  'Yimirira okumpi n\'obubeera bwo — obuyambi bujja')),
          _tipRow('📞',
              t('If urgent, call police directly: 999',
                  'Singa bwetaagisa, yita apolisi mangu: 999')),
        ],
      ),
    );
  }

  Widget _tipRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            t('Repair Complete!', 'Okuddaabiriza Kwavaawo!'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('Stay safe on the road, $_riderName! 🏍',
                'Weegenderera mu kkubo, $_riderName! 🏍'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                t('Back to Dashboard', 'Ddayo ku Dashboard'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  String get _riderName => widget.request.riderName;

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String label,
      {Color color = const Color(0xFFE65100)}) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  Widget _detailRow(String emoji, String text, [Widget? trailing]) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF424242))),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
