import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String _riderName = '';
  String _riderStage = '';
  bool _linkCopied = false;
  String _lang = 'en';

  // Replace with your real app download URL once deployed
  static const String _downloadUrl = 'https://bodasos.app/download';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _riderName = prefs.getString('rider_name') ?? '';
      _riderStage = prefs.getString('rider_stage') ?? '';
      _lang = prefs.getString('lang') ?? 'en';
    });
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  String get _smsMessage {
    if (_lang == 'lg') {
      return 'Mukwano wange,\n\n'
          'Nzeyingira BodaSOS — app eyokusaba obuyambi ku boda boda '
          'mu Uganda. Oyinza okusindika SOS emu mu kiseera ky\'obubaka. '
          'Apolisi n\'abasomi abeggerereddwa bategeezebwa amangu!\n\n'
          '📲 Yingira webale: $_downloadUrl\n\n'
          'Wakola nange $_riderName ku $_riderStage — tukuume awamu! 🏍';
    }
    return 'Hey,\n\n'
        'I just joined BodaSOS — a one-tap emergency app for boda boda '
        'riders in Uganda. Press SOS once and police + nearby riders are '
        'instantly alerted with your GPS location!\n\n'
        '📲 Download free here: $_downloadUrl\n\n'
        'Join me $_riderName at $_riderStage — let\'s ride safe! 🏍';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _downloadUrl));
    setState(() => _linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: _smsMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Message copied! Paste into WhatsApp or SMS.',
            'Obubaka bukopebwa! Tandika mu WhatsApp oba SMS.')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Text(
          t('Invite Riders', 'Yita Abasomi'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD32F2F), Color(0xFF9A0007)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('📡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      'Build Your Safety Network',
                      'Teeka Omutimbagano Ogw\'Obukuumi',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t(
                      'BodaSOS is only as strong as your network. '
                      'Every rider you invite means faster help when someone needs it.',
                      'BodaSOS ekola bulungi ngana omutimbagano gwange. '
                      'Omusirikale buli oyo oyita asuubiza obuyambi obuyangu.',
                    ),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.55),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // How to share label
            Text(
              t('How to invite', 'Engeri y\'okuyita').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 12),

            // Option 1 — Copy link
            _shareOption(
              icon: Icons.link,
              iconColor: const Color(0xFF1565C0),
              iconBg: const Color(0xFFE3F2FD),
              title: t('Copy App Link', 'Kopya Ekisinze ky\'App'),
              subtitle: t(
                'Share directly in WhatsApp, Telegram, or SMS',
                'Gaba mu WhatsApp, Telegram, oba SMS',
              ),
              action: GestureDetector(
                onTap: _copyLink,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _linkCopied
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _linkCopied
                        ? t('Copied! ✓', 'Yakopebwa! ✓')
                        : t('Copy', 'Kopya'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Option 2 — Copy message
            _shareOption(
              icon: Icons.message_rounded,
              iconColor: const Color(0xFF2E7D32),
              iconBg: const Color(0xFFE8F5E9),
              title: t('Copy WhatsApp/SMS Message', 'Kopya Obubaka bwa WhatsApp/SMS'),
              subtitle: t(
                'Ready-to-send message with your name and stage',
                'Obubaka obulemerera ne linnya lyo n\'esiteeji yo',
              ),
              action: GestureDetector(
                onTap: _copyMessage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t('Copy', 'Kopya'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Message preview
            Text(
              t('Message Preview', 'Laba Obubaka').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                            child: Text('💬', style: TextStyle(fontSize: 16))),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t('Your invite message:', 'Obubaka bwo bw\'okuyita:'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _smsMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Tips
            Text(
              t('Tips for growing your network', 'Amakubo okukulisa omutimbagano').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 12),

            _tipCard('🏁',
                t('Start at your stage', 'Tandika ku siteeji yo'),
                t(
                  'Share with riders you see every day at your stage — '
                  'they\'re the ones most likely to help you in an emergency.',
                  'Gaba n\'abasomi abo olaba buli lunaku ku siteeji yo — '
                  'bano be baakusaasira ennyo mu kiseera ky\'obubaka.',
                )),
            const SizedBox(height: 10),
            _tipCard('🤝',
                t('Share in SACCO meetings', 'Gabana mu nkuŋaana ya SACCO'),
                t(
                  'Bring it up at your boda SACCO or association meeting — '
                  'group adoption makes everyone safer.',
                  'Kibuulira mu nkuŋaana ya boda SACCO oba ekibiina kyo — '
                  'okukyusa ekibiina kyonna kukola buli omu abeere mu bwe oba.',
                )),
            const SizedBox(height: 10),
            _tipCard('📣',
                t('Post in WhatsApp groups', 'Sindika mu bibiina bya WhatsApp'),
                t(
                  'Drop the link in your rider WhatsApp group — '
                  'one message can reach 50+ riders instantly.',
                  'Sika ekisinze mu kibiina kyo kya WhatsApp kya boda — '
                  'obubaka bumu buyinza okutuuka ku basomi 50+ amangu.',
                )),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _shareOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }

  Widget _tipCard(String emoji, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 5),
                Text(body,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[600], height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
