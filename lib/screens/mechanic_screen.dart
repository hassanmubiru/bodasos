import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/mechanic.dart';
import '../models/rider.dart';
import '../services/api_service.dart';

class MechanicRegisterScreen extends StatefulWidget {
  const MechanicRegisterScreen({super.key});
  @override
  State<MechanicRegisterScreen> createState() => _MechanicRegisterScreenState();
}

class _MechanicRegisterScreenState extends State<MechanicRegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _shopCtrl  = TextEditingController();

  String _district  = 'Kampala';
  String? _stage;
  Set<String> _specialties = {};
  bool _saving = false;
  bool _registered = false;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _shopCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _registered = prefs.getBool('is_mechanic') ?? false;
      _nameCtrl.text = prefs.getString('rider_name') ?? '';
      _phoneCtrl.text = prefs.getString('rider_phone') ?? '';
      _district = prefs.getString('rider_district') ?? 'Kampala';
      _stage    = prefs.getString('rider_stage');
      _lang     = prefs.getString('lang') ?? 'en';
    });
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stage == null) {
      _snack(t('Please select your area', 'Londa ekifo kyo'), Colors.orange);
      return;
    }
    if (_specialties.isEmpty) {
      _snack(t('Select at least one specialty', 'Londa omu mu nzubu zo'), Colors.orange);
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('rider_id') ?? const Uuid().v4();
    final phone = _normalizePhone(_phoneCtrl.text.trim());

    final result = await ApiService.instance.registerMechanic(
      id: riderId,
      name: _nameCtrl.text.trim(),
      phone: phone,
      stage: _stage!,
      district: _district,
      shopName: _shopCtrl.text.trim(),
      specialties: _specialties.toList(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true || result['offline'] == true) {
      await prefs.setBool('is_mechanic', true);
      await prefs.setString('mechanic_id', riderId);
      setState(() => _registered = true);
      _snack(t('You\'re now registered as a mechanic! 🔧',
          'Wereese noomu nga fumbi! 🔧'), Colors.green);
    } else {
      _snack(result['error']?.toString() ??
          t('Registration failed', 'Okwandika kwagoba'), Colors.red);
    }
  }

  String _normalizePhone(String p) {
    p = p.replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('0')) return '+256${p.substring(1)}';
    if (!p.startsWith('+')) return '+256$p';
    return p;
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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('🔧', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(t('Mechanic Registration', 'Okwandika kwa Fumbi'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: _registered ? _buildRegisteredView() : _buildForm(),
    );
  }

  Widget _buildRegisteredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: Text('🔧', style: TextStyle(fontSize: 52))),
          ),
          const SizedBox(height: 24),
          Text(t('You\'re a Registered Mechanic!', 'Oli Fumbi Owandise!'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
          const SizedBox(height: 12),
          Text(
            t('When nearby riders have a breakdown, you\'ll receive an SMS alert and can respond.',
              'Abasomi ab\'okumpi nga bagumiidde, ojja kufuna SMS n\'oyinza okuyamba.'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBCCFF)),
            ),
            child: Column(children: [
              _infoRow('📲', t('You\'ll get SMS for nearby repair requests within 5km',
                  'Ojja kufuna SMS ez\'okusaba okuddaabiriza okumpi mu 5km')),
              _infoRow('⭐', t('Build your rating by completing jobs',
                  'Jenga omusulo gwo ng\'okola ebikolwa')),
              _infoRow('💰', t('Riders pay you directly — BodaSOS is free',
                  'Abasomi bakubaza balinganye — BodaSOS tewali bbeeyi')),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _registered = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE65100),
                side: const BorderSide(color: Color(0xFFE65100)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(t('Update My Details', 'Kyusa Ebisingawo Byange')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(String emoji, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45))),
    ]),
  );

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFBF360C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              const Text('🔧', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(t('Join as a Mechanic', 'Yingira Nga Fumbi'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                t('Get notified when nearby riders need repair help. Build your customer base.',
                  'Tegeezebwa nga abasomi ab\'okumpi bayetaaga obuyambi bw\'okuddaabiriza.'),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ]),
          ),

          const SizedBox(height: 24),
          _label(t('Your Name', 'Erinnya Lyo')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().length < 2) ? t('Required', 'Yetaagisa') : null,
            decoration: _deco(Icons.person_outline, t('Full name', 'Erinnya lyona')),
          ),

          const SizedBox(height: 16),
          _label(t('Phone Number', 'Enamba ya Simu')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
              LengthLimitingTextInputFormatter(16),
            ],
            validator: (v) {
              final d = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
              return (d.length < 9) ? t('Enter valid number', 'Yingiza enamba ey\'Uganda') : null;
            },
            decoration: _deco(Icons.phone_android_outlined, '+256 7XX XXX XXX'),
          ),

          const SizedBox(height: 16),
          _label(t('Workshop / Shop Name (optional)', 'Erinnya lya Dduuka (si yetaagisa)')),
          const SizedBox(height: 8),
          TextFormField(
            controller: _shopCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _deco(Icons.store_outlined, t('e.g. Hassan Motors', 'e.g. Hassan Motors')),
          ),

          const SizedBox(height: 16),
          _label(t('District', 'Akaali')),
          const SizedBox(height: 8),
          _dropdown(
            value: _district,
            items: UgandaStages.allDistricts,
            icon: Icons.location_city_outlined,
            hint: t('Select district', 'Londa akaali'),
            onChanged: (v) => setState(() { _district = v!; _stage = null; }),
          ),

          const SizedBox(height: 16),
          _label(t('Your Stage / Work Area', 'Siteeji Yo / Ekifo ky\'Okukola')),
          const SizedBox(height: 8),
          _dropdown(
            value: _stage,
            items: UgandaStages.stagesForDistrict(_district),
            icon: Icons.place_outlined,
            hint: t('Select stage', 'Londa siteeji'),
            onChanged: (v) => setState(() => _stage = v),
          ),

          const SizedBox(height: 20),
          _label(t('Your Specialties (select all that apply)',
              'Ebyokulwana (londa byonna bikolagana')),
          const SizedBox(height: 12),
          _buildSpecialtyGrid(),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _register,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.handyman_rounded),
              label: Text(
                _saving ? t('Registering…', 'Kwandika…') : t('Register as Mechanic', 'Kwandika Nga Fumbi'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildSpecialtyGrid() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: MechanicSpecialties.all.map((s) {
        final selected = _specialties.contains(s);
        final label = MechanicSpecialties.labels[s] ?? s;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (selected) _specialties.remove(s);
              else _specialties.add(s);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE65100) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFFE65100) : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? [BoxShadow(
                color: const Color(0xFFE65100).withOpacity(0.3),
                blurRadius: 8,
              )] : null,
            ),
            child: Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF424242),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF424242)));

  InputDecoration _deco(IconData icon, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFFE65100), size: 20),
    filled: true, fillColor: const Color(0xFFF7F7F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5)),
  );

  Widget _dropdown<T>({required T? value, required List<T> items, required IconData icon,
      required String hint, required ValueChanged<T?>? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          hint: Text(hint, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Row(children: [
              Icon(icon, size: 16, color: const Color(0xFFE65100)),
              const SizedBox(width: 10),
              Text(item.toString(), style: const TextStyle(fontSize: 14)),
            ]),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
