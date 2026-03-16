class Mechanic {
  final String id;
  final String name;
  final String phone;
  final String stage;
  final String district;
  final List<String> specialties;
  double? latitude;
  double? longitude;
  bool isAvailable;
  bool isVerified;
  double? distanceKm;
  double rating;
  int jobsCompleted;
  DateTime? lastSeen;

  Mechanic({
    required this.id,
    required this.name,
    required this.phone,
    required this.stage,
    required this.district,
    required this.specialties,
    this.latitude,
    this.longitude,
    this.isAvailable = true,
    this.isVerified = false,
    this.distanceKm,
    this.rating = 0,
    this.jobsCompleted = 0,
    this.lastSeen,
  });

  factory Mechanic.fromJson(Map<String, dynamic> j) => Mechanic(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        stage: j['stage']?.toString() ?? '',
        district: j['district']?.toString() ?? 'Kampala',
        specialties: (j['specialties'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        latitude: double.tryParse(j['latitude']?.toString() ?? ''),
        longitude: double.tryParse(j['longitude']?.toString() ?? ''),
        isAvailable: j['is_available'] == true || j['is_available'] == 1,
        isVerified: j['is_verified'] == true || j['is_verified'] == 1,
        distanceKm: double.tryParse(j['distance_km']?.toString() ?? ''),
        rating: double.tryParse(j['rating']?.toString() ?? '0') ?? 0,
        jobsCompleted: int.tryParse(j['jobs_completed']?.toString() ?? '0') ?? 0,
        lastSeen: j['last_seen'] != null
            ? DateTime.tryParse(j['last_seen'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'stage': stage,
        'district': district,
        'specialties': specialties.join(','),
        'is_available': isAvailable ? 1 : 0,
      };

  String get formattedDistance {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).toStringAsFixed(0)}m';
    return '${distanceKm!.toStringAsFixed(1)}km away';
  }

  String get ratingStars {
    if (rating == 0) return 'New';
    final full = rating.floor();
    return '${'★' * full}${'☆' * (5 - full)} ${rating.toStringAsFixed(1)}';
  }
}

// Available mechanic specialties
class MechanicSpecialties {
  static const List<String> all = [
    'puncture',
    'engine',
    'brakes',
    'electrical',
    'chain',
    'gearbox',
    'bodywork',
    'general',
  ];

  static const Map<String, String> labels = {
    'puncture': 'Tyre & Punctures 🔴',
    'engine': 'Engine Repairs ⚙️',
    'brakes': 'Brakes 🛑',
    'electrical': 'Electrical / Battery ⚡',
    'chain': 'Chain & Sprockets ⛓️',
    'gearbox': 'Gearbox & Clutch 🔧',
    'bodywork': 'Bodywork & Frame 🏍',
    'general': 'General Servicing 🛠️',
  };
}
