import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/rider.dart';


class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bodasos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS repair_requests (
        id                   TEXT PRIMARY KEY,
        rider_id             TEXT NOT NULL,
        rider_name           TEXT NOT NULL,
        rider_phone          TEXT NOT NULL,
        issue                TEXT NOT NULL,
        custom_note          TEXT,
        latitude             REAL NOT NULL,
        longitude            REAL NOT NULL,
        stage                TEXT NOT NULL,
        district             TEXT NOT NULL DEFAULT 'Kampala',
        status               TEXT NOT NULL DEFAULT 'pending',
        mechanic_name        TEXT,
        mechanic_phone       TEXT,
        mechanic_distance_km REAL,
        estimated_minutes    INTEGER,
        responders_count     INTEGER DEFAULT 0,
        created_at           TEXT NOT NULL,
        updated_at           TEXT,
        synced               INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS riders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        stage TEXT NOT NULL,
        area TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        last_seen TEXT,
        is_online INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS my_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        stage TEXT NOT NULL,
        area TEXT NOT NULL,
        district TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sos_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        response TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        timestamp TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mechanics (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        stage TEXT NOT NULL,
        district TEXT NOT NULL,
        shop_name TEXT,
        specialties TEXT,
        is_available INTEGER DEFAULT 1,
        is_verified INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        jobs_completed INTEGER DEFAULT 0,
        latitude REAL,
        longitude REAL,
        last_seen TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        text TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        rider_id TEXT NOT NULL,
        rider_name TEXT NOT NULL,
        rider_phone TEXT NOT NULL,
        start_lat REAL NOT NULL,
        start_lng REAL NOT NULL,
        current_lat REAL,
        current_lng REAL,
        start_label TEXT,
        destination_label TEXT,
        status TEXT DEFAULT 'active',
        share_token TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT
      )
    ''');
  }

  // ── My Profile ──────────────────────────────────────────────────────────────

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'my_profile',
      profile,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    final maps = await db.query('my_profile', limit: 1);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> deleteProfile() async {
    final db = await database;
    await db.delete('my_profile');
  }

  // ── Nearby Riders ────────────────────────────────────────────────────────────

  Future<void> cacheNearbyRiders(List<Rider> riders) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('riders');
    for (final rider in riders) {
      batch.insert('riders', rider.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Rider>> getCachedRiders() async {
    final db = await database;
    final maps = await db.query('riders');
    return maps.map((m) => Rider.fromJson(m)).toList();
  }

  // ── Location Cache ───────────────────────────────────────────────────────────

  Future<void> cacheLocation(
      double lat, double lng, double accuracy) async {
    final db = await database;
    await db.insert('location_cache', {
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
    // Keep only last 100 locations
    await db.rawDelete('''
      DELETE FROM location_cache 
      WHERE id NOT IN (
        SELECT id FROM location_cache ORDER BY id DESC LIMIT 100
      )
    ''');
  }

  Future<Map<String, dynamic>?> getLastKnownLocation() async {
    final db = await database;
    final maps = await db.query(
      'location_cache',
      orderBy: 'id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    final db = await database;
    return await db.query(
      'location_cache',
      where: 'synced = ?',
      whereArgs: [0],
      limit: 20,
    );
  }

  Future<void> markLocationSynced(int id) async {
    final db = await database;
    await db.update(
      'location_cache',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── SOS History ──────────────────────────────────────────────────────────────

  Future<int> saveSOS(double lat, double lng) async {
    final db = await database;
    return await db.insert('sos_history', {
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getSOSHistory() async {
    final db = await database;
    return await db.query('sos_history', orderBy: 'id DESC', limit: 50);
  }

  Future<void> markSOSSynced(int id, String response) async {
    final db = await database;
    await db.update(
      'sos_history',
      {'synced': 1, 'response': response},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
