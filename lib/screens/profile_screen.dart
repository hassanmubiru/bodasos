import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _district = 'Kampala';
  String? _stage;
  bool _saving = false;
  bool _changed = false;
  String _lang = 'en';
  String _riderId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameCtrl.addListener(() => setState(() => _changed = true));
    _phoneCtrl.addListener(() => setState(() => _changed = true));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderId = prefs.getString('rider_id') ?? '';
      _nameCtrl.text  = prefs.getString('rider_name') ?? '';
      _phoneCtrl.text = prefs.getString('rider_phone') ?? '';
      _district = prefs.getString('rider_district') ?? 'Kampala';
      _stage    = prefs.getString('rider_stage');
      _lang     = prefs.getString('lang') ?? 'en';
      _changed  = false;
    });
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  String _normalizePhone(String p) {
    p = p.replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('0')) return '+256${p.substring(1)}';
    if (!p.startsWith('+')) return '+256$p';
    return p;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stage == null) {
      _snack(t('Please select your stage', 'Londa siteeji yo'), Colors.orange);
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final name  = _nameCtrl.text.trim();
    final phone = _normalizePhone(_phoneCtrl.text.trim());

    // Update on server
    final result = await ApiService.instance.registerRider(
      id:       _riderId,
      name:     name,
      phone:    phone,
      stage:    _stage!,
      area:     _stage!,
      district: _district,
    );

    // Always update SharedPreferences regardless of network
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_name', name);
    await prefs.setString('rider_phone', phone);
    await prefs.setString('rider_stage', _stage!);
    await prefs.setString('rider_district', _district);

    if (!mounted) return;
    setState(() { _saving = false; _changed = false; });

    if (result['offline'] == true) {
      _snack(
        t('Saved locally. Will sync when online.', 'Yakumiibwa. Ejja okusingaho nga network edzaayo.'),
        Colors.orange,
      );
    } else if (result['success'] == true) {
      _snack(t('Profile updated ✓', 'Eprofile yavuunulwa ✓'), Colors.green);
    } else {
      _snack(result['error']?.toString() ?? t('Update failed', 'Okuvuunula kwagoba'), Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Text(t('My Profile', 'Eprofile Yange'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_changed)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                t('Save', 'Kumiira'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar card
              Center(
                child: Column(children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFF9A0007)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFD32F2F).withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 8),
                      )],
                    ),
                    child: Center(
                      child: Text(
                        _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(t('Boda Rider', 'Omuvuzi wa Boda'),
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ]),
              ),
              const SizedBox(height: 28),

              _sectionLabel(t('Full Name', 'Erinnya Lyona')),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                validator: (v) => (v == null || v.trim().length < 2)
                    ? t('Name required', 'Erinnya lyetaagisa') : null,
                decoration: _deco(Icons.person_outline, t('Your name', 'Erinnya lyo')),
              ),
              const SizedBox(height: 18),

              _sectionLabel(t('Phone Number', 'Enamba ya Simu')),
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
                  return (d.length < 9 || d.length > 13)
                      ? t('Enter valid Uganda number', 'Yingiza enamba ey\'Uganda') : null;
                },
                decoration: _deco(Icons.phone_android_outlined, '+256 7XX XXX XXX'),
              ),
              const SizedBox(height: 18),

              _sectionLabel(t('District', 'Akaali')),
              const SizedBox(height: 8),
              _dropdown<String>(
                value: _district,
                items: UgandaStages.allDistricts,
                icon: Icons.location_city_outlined,
                hint: t('Select district', 'Londa akaali'),
                onChanged: (v) => setState(() { _district = v!; _stage = null; _changed = true; }),
              ),
              const SizedBox(height: 18),

              _sectionLabel(t('Stage / Area', 'Siteeji / Ekifo')),
              const SizedBox(height: 8),
              _dropdown<String>(
                value: _stage,
                items: UgandaStages.stagesForDistrict(_district),
                icon: Icons.place_outlined,
                hint: t('Select stage', 'Londa siteeji'),
                onChanged: (v) => setState(() { _stage = v; _changed = true; }),
              ),

              const SizedBox(height: 32),

              // Language toggle
              _card(child: Row(
                children: [
                  const Text('🇺🇬', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('App Language', 'Olulimi lw\'App'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(_lang == 'en' ? 'English' : 'Luganda',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  )),
                  Switch(
                    value: _lang == 'lg',
                    activeColor: const Color(0xFFD32F2F),
                    onChanged: (v) async {
                      final prefs = await SharedPreferences.getInstance();
                      final newLang = v ? 'lg' : 'en';
                      await prefs.setString('lang', newLang);
                      setState(() => _lang = newLang);
                    },
                  ),
                ],
              )),

              const SizedBox(height: 16),

              // Save button (bottom)
              if (_changed)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(t('Save Changes', 'Kumiira Enkyukakyuka'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF424242)));

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    ),
    child: child,
  );

  InputDecoration _deco(IconData icon, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
    filled: true,
    fillColor: const Color(0xFFF7F7F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5)),
  );

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required IconData icon,
    required String hint,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          hint: Text(hint, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Row(children: [
              Icon(icon, size: 16, color: const Color(0xFFD32F2F)),
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
