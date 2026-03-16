class Rider {
  final String id;
  final String name;
  final String phone;
  final String stage;
  final String area;
  double? latitude;
  double? longitude;
  DateTime? lastSeen;
  bool isOnline;
  double? distanceKm;

  Rider({
    required this.id,
    required this.name,
    required this.phone,
    required this.stage,
    required this.area,
    this.latitude,
    this.longitude,
    this.lastSeen,
    this.isOnline = false,
    this.distanceKm,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      distanceKm: json['distance_km'] != null
          ? double.tryParse(json['distance_km'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'stage': stage,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'last_seen': lastSeen?.toIso8601String(),
      'is_online': isOnline ? 1 : 0,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'stage': stage,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'last_seen': lastSeen?.toIso8601String(),
      'is_online': isOnline ? 1 : 0,
    };
  }

  String get formattedDistance {
    if (distanceKm == null) return 'Unknown';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toStringAsFixed(0)}m away';
    }
    return '${distanceKm!.toStringAsFixed(1)}km away';
  }
}

class SOSAlert {
  final String riderId;
  final String riderName;
  final String riderPhone;
  final double latitude;
  final double longitude;
  final String stage;
  final String district;
  final DateTime timestamp;
  final String? message;

  SOSAlert({
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.latitude,
    required this.longitude,
    required this.stage,
    required this.district,
    required this.timestamp,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'rider_id':   riderId,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'latitude':   latitude,
      'longitude':  longitude,
      'stage':      stage,
      'district':   district,
      'timestamp':  timestamp.toIso8601String(),
      'message':    message ?? 'EMERGENCY! Boda rider needs help!',
    };
  }
}

// Uganda stages/areas configuration
class UgandaStages {
  static const Map<String, List<String>> stagesByDistrict = {
    'Kampala': [
      'Kampala Central',
      'Nakawa',
      'Makindye',
      'Rubaga',
      'Kawempe',
      'Wandegeya',
      'Kisenyi',
      'Katwe',
      'Ntinda',
      'Bukoto',
      'Kololo',
      'Mulago',
      'Makerere',
    ],
    'Wakiso': [
      'Entebbe',
      'Kajjansi',
      'Nansana',
      'Mukono Rd',
      'Gayaza',
      'Namulanda',
      'Wakiso Town',
    ],
    'Mukono': [
      'Mukono Town',
      'Seeta',
      'Najeera',
      'Kyaliwajjala',
    ],
    'Masaka': [
      'Masaka Town',
      'Nyendo',
    ],
    'Mbarara': [
      'Mbarara Town',
      'Kakoba',
    ],
    'Gulu': [
      'Gulu Town',
      'Layibi',
    ],
    'Jinja': [
      'Jinja Town',
      'Walukuba',
    ],
  };

  static List<String> get allDistricts => stagesByDistrict.keys.toList();

  static List<String> stagesForDistrict(String district) {
    return stagesByDistrict[district] ?? [];
  }
}

// Police contacts per region
class PoliceContacts {
  static const Map<String, Map<String, String>> byDistrict = {
    'Kampala': {
      'name': 'Kampala Metropolitan Police',
      'phone': '+256414258333',
      'emergency': '999',
    },
    'Wakiso': {
      'name': 'Wakiso District Police',
      'phone': '+256312200700',
      'emergency': '999',
    },
    'Mukono': {
      'name': 'Mukono District Police',
      'phone': '+256312200800',
      'emergency': '999',
    },
    'Masaka': {
      'name': 'Masaka District Police',
      'phone': '+256312201000',
      'emergency': '999',
    },
    'Mbarara': {
      'name': 'Mbarara District Police',
      'phone': '+256312201200',
      'emergency': '999',
    },
    'Gulu': {
      'name': 'Gulu District Police',
      'phone': '+256312201500',
      'emergency': '999',
    },
    'Jinja': {
      'name': 'Jinja District Police',
      'phone': '+256312201800',
      'emergency': '999',
    },
  };

  static Map<String, String> getForDistrict(String district) {
    return byDistrict[district] ??
        {
          'name': 'Uganda Police Force',
          'phone': '+256414258333',
          'emergency': '999',
        };
  }
}
