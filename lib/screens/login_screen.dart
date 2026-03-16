import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/rider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String  _selectedDistrict = 'Kampala';
  String? _selectedStage;
  bool    _isLoading    = false;
  bool    _consentGiven = false;
  String  _lang         = 'en';

  late AnimationController _animCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return t('Name is required', 'Erinnya liteekwawo');
    }
    if (v.trim().length < 2) {
      return t('Name is too short', 'Erinnya ntono');
    }
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) {
      return t('Phone number is required', 'Enamba ya simu yetaagisa');
    }
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 13) {
      return t('Enter a valid Uganda number', 'Yingiza enamba ey\'Uganda');
    }
    return null;
  }

  // ── Register ────────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_consentGiven) {
      _snack(
        t('Please accept the privacy consent', 'Kkiriza omuteesa ogw\'obukuumi'),
        Colors.orange,
      );
      return;
    }
    if (_selectedStage == null) {
      _snack(
        t('Please select your stage/area', 'Londa siteeji yo'),
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final riderId = const Uuid().v4();
    final name    = _nameCtrl.text.trim();
    final phone   = _normalizePhone(_phoneCtrl.text.trim());

    final result = await ApiService.instance.registerRider(
      id:       riderId,
      name:     name,
      phone:    phone,
      stage:    _selectedStage!,
      area:     _selectedStage!,
      district: _selectedDistrict,
    );

    await DatabaseService.instance.saveProfile({
      'id':         riderId,
      'name':       name,
      'phone':      phone,
      'stage':      _selectedStage,
      'area':       _selectedStage,
      'district':   _selectedDistrict,
      'created_at': DateTime.now().toIso8601String(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rider_id',       riderId);
    await prefs.setString('rider_name',     name);
    await prefs.setString('rider_phone',    phone);
    await prefs.setString('rider_stage',    _selectedStage!);
    await prefs.setString('rider_district', _selectedDistrict);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['offline'] == true) {
      _snack(
        t('Saved offline. Will sync when connected.',
          'Yakumiibwa offline. Ejja okusingaho nga network edzaayo.'),
        Colors.orange,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  String _normalizePhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('0')) return '+256${phone.substring(1)}';
    if (!phone.startsWith('+')) return '+256$phone';
    return phone;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildHero(),
                  const SizedBox(height: 28),
                  _buildFormCard(),
                  const SizedBox(height: 20),
                  _buildFooterNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _LangToggle(
          lang: _lang,
          onTap: () => setState(() => _lang = _lang == 'en' ? 'lg' : 'en'),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Center(
      child: Column(
        children: [
          // Logo
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFF9A0007)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD32F2F).withOpacity(0.38),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.two_wheeler, size: 48, color: Colors.white),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'BodaSOS',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD32F2F),
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('Emergency System · Uganda Boda Riders',
              'Akabonero k\'obuyambi · Abavuzi b\'Uganda'),
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Chip('🆘 One-tap SOS'),
              _Chip('📡 Offline GPS'),
              _Chip('🚔 Police Alert'),
              _Chip('🔧 Repair Help'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormSection(label: t('Your Name', 'Erinnya Lyo')),
            const SizedBox(height: 8),
            _buildNameField(),

            const SizedBox(height: 18),
            _FormSection(label: t('Phone Number', 'Enamba ya Simu')),
            const SizedBox(height: 8),
            _buildPhoneField(),

            const SizedBox(height: 18),
            _FormSection(label: t('District', 'Akaali')),
            const SizedBox(height: 8),
            _buildDistrictPicker(),

            const SizedBox(height: 18),
            _FormSection(label: t('Stage / Area', 'Siteeji / Ekifo')),
            const SizedBox(height: 8),
            _buildStagePicker(),

            const SizedBox(height: 22),
            _buildConsentRow(),
            const SizedBox(height: 24),
            _buildRegisterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      validator: _validateName,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [LengthLimitingTextInputFormatter(60)],
      decoration: _inputDecoration(
        hint: t('e.g. Hassan Mukasa', 'e.g. Hassan Mukasa'),
        icon: Icons.person_outline,
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      validator: _validatePhone,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
        LengthLimitingTextInputFormatter(16),
      ],
      decoration: _inputDecoration(
        hint: '+256 7XX XXX XXX',
        icon: Icons.phone_android_outlined,
      ),
    );
  }

  Widget _buildDistrictPicker() {
    return _DropdownField<String>(
      value: _selectedDistrict,
      hint: t('Select district', 'Londa akaali'),
      icon: Icons.location_city_outlined,
      items: UgandaStages.allDistricts,
      onChanged: (v) => setState(() {
        _selectedDistrict = v!;
        _selectedStage = null;
      }),
    );
  }

  Widget _buildStagePicker() {
    final stages = UgandaStages.stagesForDistrict(_selectedDistrict);
    return _DropdownField<String>(
      value: _selectedStage,
      hint: t('Select stage', 'Londa siteeji'),
      icon: Icons.place_outlined,
      items: stages,
      onChanged: stages.isEmpty ? null : (v) => setState(() => _selectedStage = v),
    );
  }

  Widget _buildConsentRow() {
    return GestureDetector(
      onTap: () => setState(() => _consentGiven = !_consentGiven),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _consentGiven
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _consentGiven
                ? const Color(0xFF4CAF50)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _consentGiven,
                onChanged: (v) => setState(() => _consentGiven = v!),
                activeColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t(
                  'I agree to share my GPS location during emergencies only. '
                  'No background tracking. No data sold.',
                  'Nzuula okugabana GPS yange mu kiseera ky\'obuyambi bukyali. '
                  'Tewali kukubirako. Tewali tudaamu data.',
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: _consentGiven
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  key: const ValueKey('label'),
                  t('JOIN BODASOS', 'YINGIRA BODASOS'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                t('Free · Secure · Works offline',
                  'Yabula bbeeyi · Erinzibwa · Ekola nga tewali network'),
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t('MTN & Airtel Uganda supported',
              'MTN & Airtel Uganda ziviiramu'),
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _LangToggle extends StatelessWidget {
  final String lang;
  final VoidCallback onTap;
  const _LangToggle({required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang == 'en' ? '🇺🇬' : '🇬🇧',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 5),
            Text(
              lang == 'en' ? 'Luganda' : 'English',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  const _FormSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF424242),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB71C1C),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final List<T> items;
  final ValueChanged<T?>? onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          hint: Text(hint,
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: const Color(0xFFD32F2F)),
                        const SizedBox(width: 10),
                        Text(item.toString(), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
