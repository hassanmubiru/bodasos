// ── Chat Message ─────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String text;
  final DateTime sentAt;
  bool isRead;
  bool isMine;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    required this.sentAt,
    this.isRead = false,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j, String myId) {
    return ChatMessage(
      id: j['id']?.toString() ?? '',
      senderId: j['sender_id']?.toString() ?? '',
      senderName: j['sender_name']?.toString() ?? '',
      receiverId: j['receiver_id']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
      sentAt: DateTime.tryParse(j['sent_at']?.toString() ?? '') ?? DateTime.now(),
      isRead: j['is_read'] == true || j['is_read'] == 1,
      isMine: j['sender_id']?.toString() == myId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'text': text,
        'sent_at': sentAt.toIso8601String(),
      };
}

// ── Conversation summary (for inbox list) ──────────────────────────────────

class Conversation {
  final String peerId;
  final String peerName;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;

  const Conversation({
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    required this.lastAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        peerId: j['peer_id']?.toString() ?? '',
        peerName: j['peer_name']?.toString() ?? '',
        lastMessage: j['last_message']?.toString() ?? '',
        lastAt: DateTime.tryParse(j['last_at']?.toString() ?? '') ?? DateTime.now(),
        unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
      );
}

// ── Ride / Trip ───────────────────────────────────────────────────────────────

enum TripStatus { idle, active, completed, cancelled }

class Trip {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  double startLat;
  double startLng;
  double currentLat;
  double currentLng;
  final String startLabel;
  String? destinationLabel;
  TripStatus status;
  final DateTime startedAt;
  DateTime? endedAt;
  String? shareToken;  // short token for passenger link

  Trip({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.startLat,
    required this.startLng,
    required this.currentLat,
    required this.currentLng,
    required this.startLabel,
    this.destinationLabel,
    this.status = TripStatus.active,
    required this.startedAt,
    this.endedAt,
    this.shareToken,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id']?.toString() ?? '',
        riderId: j['rider_id']?.toString() ?? '',
        riderName: j['rider_name']?.toString() ?? '',
        riderPhone: j['rider_phone']?.toString() ?? '',
        startLat: double.tryParse(j['start_lat']?.toString() ?? '0') ?? 0,
        startLng: double.tryParse(j['start_lng']?.toString() ?? '0') ?? 0,
        currentLat: double.tryParse(j['current_lat']?.toString() ?? '0') ?? 0,
        currentLng: double.tryParse(j['current_lng']?.toString() ?? '0') ?? 0,
        startLabel: j['start_label']?.toString() ?? '',
        destinationLabel: j['destination_label']?.toString(),
        status: TripStatus.values.firstWhere(
          (s) => s.name == j['status']?.toString(),
          orElse: () => TripStatus.active,
        ),
        startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ?? DateTime.now(),
        endedAt: j['ended_at'] != null
            ? DateTime.tryParse(j['ended_at'].toString())
            : null,
        shareToken: j['share_token']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rider_id': riderId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'start_lat': startLat,
        'start_lng': startLng,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'start_label': startLabel,
        'destination_label': destinationLabel,
        'status': status.name,
        'started_at': startedAt.toIso8601String(),
      };

  String get shareUrl => 'https://bodasos.app/track/$shareToken';

  String get durationText {
    final end = endedAt ?? DateTime.now();
    final diff = end.difference(startedAt);
    if (diff.inMinutes < 1) return 'Just started';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}
