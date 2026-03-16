// ── Repair Request Model ─────────────────────────────────────────────────────

enum RepairStatus { pending, accepted, onTheWay, arrived, done, cancelled }

enum BikeIssue {
  puncture,
  engineFail,
  brakesFail,
  chainSnapped,
  batteryDead,
  fuelEmpty,
  electricalFault,
  gearboxFault,
  overheating,
  accident,
  other,
}

extension BikeIssueInfo on BikeIssue {
  String get label {
    switch (this) {
      case BikeIssue.puncture:      return 'Tyre Puncture';
      case BikeIssue.engineFail:    return 'Engine Won\'t Start';
      case BikeIssue.brakesFail:    return 'Brakes Failed';
      case BikeIssue.chainSnapped:  return 'Chain Snapped';
      case BikeIssue.batteryDead:   return 'Battery Dead';
      case BikeIssue.fuelEmpty:     return 'Out of Fuel';
      case BikeIssue.electricalFault: return 'Electrical Fault';
      case BikeIssue.gearboxFault:  return 'Gearbox Problem';
      case BikeIssue.overheating:   return 'Engine Overheating';
      case BikeIssue.accident:      return 'Accident Damage';
      case BikeIssue.other:         return 'Other Problem';
    }
  }

  String get labelLg {
    switch (this) {
      case BikeIssue.puncture:      return 'Tayara Ejeese';
      case BikeIssue.engineFail:    return 'Injini Etandika';
      case BikeIssue.brakesFail:    return 'Buleeki Zigoba';
      case BikeIssue.chainSnapped:  return 'Cheeni Eyatema';
      case BikeIssue.batteryDead:   return 'Batule Egweddwa';
      case BikeIssue.fuelEmpty:     return 'Petulo Eyaggwaawo';
      case BikeIssue.electricalFault: return 'Obugumu bw\'Amasannyalaze';
      case BikeIssue.gearboxFault:  return 'Ekizibu ky\'Giiya';
      case BikeIssue.overheating:   return 'Injini Okunywa Obutiti';
      case BikeIssue.accident:      return 'Okonooneka kwa Akadde';
      case BikeIssue.other:         return 'Ekizibu Ekirala';
    }
  }

  String get emoji {
    switch (this) {
      case BikeIssue.puncture:      return '🔴';
      case BikeIssue.engineFail:    return '⚙️';
      case BikeIssue.brakesFail:    return '🛑';
      case BikeIssue.chainSnapped:  return '⛓️';
      case BikeIssue.batteryDead:   return '🔋';
      case BikeIssue.fuelEmpty:     return '⛽';
      case BikeIssue.electricalFault: return '⚡';
      case BikeIssue.gearboxFault:  return '🔧';
      case BikeIssue.overheating:   return '🌡️';
      case BikeIssue.accident:      return '🚨';
      case BikeIssue.other:         return '❓';
    }
  }

  bool get isUrgent =>
      this == BikeIssue.brakesFail ||
      this == BikeIssue.accident ||
      this == BikeIssue.engineFail;

  static BikeIssue fromString(String s) {
    return BikeIssue.values.firstWhere(
      (e) => e.name == s,
      orElse: () => BikeIssue.other,
    );
  }
}

extension RepairStatusInfo on RepairStatus {
  String get label {
    switch (this) {
      case RepairStatus.pending:    return 'Looking for mechanic…';
      case RepairStatus.accepted:   return 'Mechanic found!';
      case RepairStatus.onTheWay:   return 'Mechanic on the way';
      case RepairStatus.arrived:    return 'Mechanic arrived';
      case RepairStatus.done:       return 'Repair complete ✓';
      case RepairStatus.cancelled:  return 'Cancelled';
    }
  }

  String get labelLg {
    switch (this) {
      case RepairStatus.pending:    return 'Tunoonyeza fumbi…';
      case RepairStatus.accepted:   return 'Fumbi azuulidwa!';
      case RepairStatus.onTheWay:   return 'Fumbi ajja';
      case RepairStatus.arrived:    return 'Fumbi atuuse';
      case RepairStatus.done:       return 'Okuddaabiriza kwavaawo ✓';
      case RepairStatus.cancelled:  return 'Yakansibwa';
    }
  }

  static RepairStatus fromString(String s) {
    return RepairStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RepairStatus.pending,
    );
  }
}

// ── RepairRequest ────────────────────────────────────────────────────────────

class RepairRequest {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final BikeIssue issue;
  final String? customNote;
  final double latitude;
  final double longitude;
  final String stage;
  final String district;
  RepairStatus status;
  final DateTime createdAt;
  DateTime? updatedAt;

  // Mechanic info (filled when accepted)
  String? mechanicName;
  String? mechanicPhone;
  double? mechanicDistanceKm;
  int? estimatedMinutes;

  // Response counts
  int respondersCount;

  RepairRequest({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.issue,
    this.customNote,
    required this.latitude,
    required this.longitude,
    required this.stage,
    required this.district,
    this.status = RepairStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.mechanicName,
    this.mechanicPhone,
    this.mechanicDistanceKm,
    this.estimatedMinutes,
    this.respondersCount = 0,
  });

  factory RepairRequest.fromJson(Map<String, dynamic> json) {
    return RepairRequest(
      id: json['id']?.toString() ?? '',
      riderId: json['rider_id']?.toString() ?? '',
      riderName: json['rider_name']?.toString() ?? '',
      riderPhone: json['rider_phone']?.toString() ?? '',
      issue: BikeIssueInfo.fromString(json['issue']?.toString() ?? 'other'),
      customNote: json['custom_note']?.toString(),
      latitude: double.tryParse(json['latitude'].toString()) ?? 0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0,
      stage: json['stage']?.toString() ?? '',
      district: json['district']?.toString() ?? 'Kampala',
      status: RepairStatusInfo.fromString(json['status']?.toString() ?? 'pending'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      mechanicName: json['mechanic_name']?.toString(),
      mechanicPhone: json['mechanic_phone']?.toString(),
      mechanicDistanceKm: json['mechanic_distance_km'] != null
          ? double.tryParse(json['mechanic_distance_km'].toString())
          : null,
      estimatedMinutes: json['estimated_minutes'] != null
          ? int.tryParse(json['estimated_minutes'].toString())
          : null,
      respondersCount: int.tryParse(json['responders_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rider_id': riderId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'issue': issue.name,
        'custom_note': customNote,
        'latitude': latitude,
        'longitude': longitude,
        'stage': stage,
        'district': district,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'rider_id': riderId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'issue': issue.name,
        'custom_note': customNote,
        'latitude': latitude,
        'longitude': longitude,
        'stage': stage,
        'district': district,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'synced': 0,
      };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
