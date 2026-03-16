import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../services/api_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String _myId = '', _myName = '';
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _myId   = prefs.getString('rider_id') ?? '';
    _myName = prefs.getString('rider_name') ?? '';
    _lang   = prefs.getString('lang') ?? 'en';

    try {
      final online = await ApiService.instance.isOnline;
      if (online) {
        final res = await http.get(
          Uri.parse('${ApiService.baseUrl}/messages/conversations/$_myId'),
          headers: ApiService.instance.authHeaders,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = (data['conversations'] as List)
              .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() { _conversations = list; _loading = false; });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String t(String en, String lg) => _lang == 'lg' ? lg : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Text(t('Messages', 'Obubaka'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : _conversations.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFD32F2F),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (_, i) => _ConvTile(
                      conv: _conversations[i],
                      myId: _myId,
                      myName: _myName,
                      lang: _lang,
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('💬', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      Text(t('No messages yet', 'Tewali bubaka'), style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(t('You can message any online rider from the map.', 'Oyinza okutumira obubaka omuvuzi yenna awali ku maapu.'),
          style: TextStyle(fontSize: 13, color: Colors.grey[400]), textAlign: TextAlign.center),
    ]));
  }
}

// ── Conversation tile ──────────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final Conversation conv;
  final String myId, myName, lang;
  const _ConvTile({required this.conv, required this.myId, required this.myName, required this.lang});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFD32F2F),
        child: Text(
          conv.peerName.isNotEmpty ? conv.peerName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      title: Text(conv.peerName, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(conv.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_timeAgo(conv.lastAt), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        if (conv.unreadCount > 0) ...[
          const SizedBox(height: 4),
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle),
            child: Center(child: Text('${conv.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
          ),
        ],
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: conv.peerId, peerName: conv.peerName,
          myId: myId, myName: myName, lang: lang,
        ),
      )),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAT SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  final String peerId, peerName, myId, myName, lang;
  const ChatScreen({super.key, required this.peerId, required this.peerName,
      required this.myId, required this.myName, required this.lang});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  bool _sending = false;
  Timer? _pollTimer;

  String t(String en, String lg) => widget.lang == 'lg' ? lg : en;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    final online = await ApiService.instance.isOnline;
    if (!online) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/messages/thread/${widget.myId}/${widget.peerId}'),
        headers: ApiService.instance.authHeaders,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final msgs = (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>, widget.myId))
            .toList();
        if (mounted) {
          setState(() => _messages = msgs);
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();

    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: widget.myId,
      senderName: widget.myName,
      receiverId: widget.peerId,
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    );

    setState(() => _messages.add(msg));
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/messages/send'),
        headers: ApiService.instance.authHeaders,
        body: jsonEncode(msg.toJson()),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: Row(children: [
          CircleAvatar(
            radius: 16, backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(widget.peerName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(t('Boda Rider', 'Omuvuzi wa Boda'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(child: Text(t('Say hello! 👋', 'Osobola! 👋'),
                  style: TextStyle(color: Colors.grey[400], fontSize: 16)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _MessageBubble(msg: _messages[i]),
                ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: t('Type a message…', 'Wandika obubaka…'),
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : _send,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.35), blurRadius: 8)],
            ),
            child: _sending
                ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMine ? const Color(0xFFD32F2F) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMine ? 16 : 4),
            bottomRight: Radius.circular(msg.isMine ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(msg.text, style: TextStyle(
            color: msg.isMine ? Colors.white : const Color(0xFF212121),
            fontSize: 14, height: 1.45,
          )),
          const SizedBox(height: 4),
          Text(
            '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 10,
              color: msg.isMine ? Colors.white60 : Colors.grey[400],
            ),
          ),
        ]),
      ),
    );
  }
}
