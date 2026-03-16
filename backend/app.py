"""
BodaSOS Flask Backend
=====================
Uganda Boda Boda Emergency System API

Requirements:
    pip install flask flask-cors twilio python-dotenv requests flask-limiter

Setup:
    1. Copy .env.example to .env and fill in your credentials
    2. python app.py
    3. Deploy to Railway/Render: gunicorn app:app
"""

import os
import math
import sqlite3
import logging
import hashlib
import hmac
from datetime import datetime, timedelta
from functools import wraps

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from twilio.rest import Client as TwilioClient
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# ── Config ────────────────────────────────────────────────────────────────────

DATABASE        = os.getenv("DATABASE_PATH", "bodasos.db")
TWILIO_SID      = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_TOKEN    = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM     = os.getenv("TWILIO_PHONE_NUMBER", "")
API_SECRET_KEY  = os.getenv("API_SECRET_KEY", "")
ADMIN_KEY       = os.getenv("ADMIN_SECRET_KEY", "")
SOS_RADIUS_KM   = float(os.getenv("SOS_RADIUS_KM", "5.0"))
REPAIR_RADIUS_KM = float(os.getenv("REPAIR_RADIUS_KM", "5.0"))
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")

# Warn loudly if running without real credentials
if not API_SECRET_KEY:
    print("WARNING: API_SECRET_KEY not set — all requests will be accepted. Set this in production!")

# ── CORS (restrict to known origins in production) ────────────────────────────
CORS(app, origins=ALLOWED_ORIGINS, supports_credentials=False)

# ── Rate limiting ─────────────────────────────────────────────────────────────
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["300 per hour"],
    storage_uri="memory://",
)

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)

# ── Twilio client (cached) ────────────────────────────────────────────────────
_twilio_client = None

def get_twilio():
    global _twilio_client
    if _twilio_client is None and all([TWILIO_SID, TWILIO_TOKEN]):
        _twilio_client = TwilioClient(TWILIO_SID, TWILIO_TOKEN)
    return _twilio_client

# Uganda police contacts per district
POLICE_CONTACTS = {
    "Kampala": {"name": "Kampala Metropolitan Police", "phone": "+256414258333"},
    "Wakiso":  {"name": "Wakiso District Police",      "phone": "+256312200700"},
    "Mukono":  {"name": "Mukono District Police",      "phone": "+256312200800"},
    "Masaka":  {"name": "Masaka District Police",      "phone": "+256312201000"},
    "Mbarara": {"name": "Mbarara District Police",     "phone": "+256312201200"},
    "Gulu":    {"name": "Gulu District Police",        "phone": "+256312201500"},
    "Jinja":   {"name": "Jinja District Police",       "phone": "+256312201800"},
}

VALID_DISTRICTS = set(POLICE_CONTACTS.keys())
VALID_ISSUES = {
    "puncture", "engineFail", "brakesFail", "chainSnapped",
    "batteryDead", "fuelEmpty", "electricalFault", "gearboxFault",
    "overheating", "accident", "other",
}

ISSUE_LABELS = {
    "puncture":       "Tyre Puncture 🔴",
    "engineFail":     "Engine Won't Start ⚙️",
    "brakesFail":     "Brakes Failed 🛑",
    "chainSnapped":   "Chain Snapped ⛓️",
    "batteryDead":    "Battery Dead 🔋",
    "fuelEmpty":      "Out of Fuel ⛽",
    "electricalFault":"Electrical Fault ⚡",
    "gearboxFault":   "Gearbox Problem 🔧",
    "overheating":    "Overheating 🌡️",
    "accident":       "Accident Damage 🚨",
    "other":          "Bike Problem ❓",
}

# ── Database ──────────────────────────────────────────────────────────────────

def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DATABASE, detect_types=sqlite3.PARSE_DECLTYPES)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA journal_mode=WAL")   # better concurrency
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db


@app.teardown_appcontext
def close_db(error):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Create all tables. Safe to call multiple times (IF NOT EXISTS)."""
    with app.app_context():
        db = get_db()
        db.executescript("""
            CREATE TABLE IF NOT EXISTS riders (
                id          TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                phone       TEXT NOT NULL,
                stage       TEXT NOT NULL,
                area        TEXT NOT NULL,
                district    TEXT NOT NULL DEFAULT 'Kampala',
                latitude    REAL,
                longitude   REAL,
                accuracy    REAL,
                last_seen   TEXT,
                is_online   INTEGER DEFAULT 0,
                created_at  TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS location_updates (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                rider_id    TEXT NOT NULL,
                latitude    REAL NOT NULL,
                longitude   REAL NOT NULL,
                accuracy    REAL,
                timestamp   TEXT NOT NULL,
                FOREIGN KEY(rider_id) REFERENCES riders(id)
            );

            CREATE TABLE IF NOT EXISTS sos_events (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                rider_id        TEXT NOT NULL,
                rider_name      TEXT NOT NULL,
                rider_phone     TEXT NOT NULL,
                latitude        REAL NOT NULL,
                longitude       REAL NOT NULL,
                stage           TEXT NOT NULL,
                district        TEXT NOT NULL DEFAULT 'Kampala',
                message         TEXT,
                riders_alerted  INTEGER DEFAULT 0,
                police_alerted  INTEGER DEFAULT 0,
                timestamp       TEXT NOT NULL,
                resolved        INTEGER DEFAULT 0,
                FOREIGN KEY(rider_id) REFERENCES riders(id)
            );

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
                FOREIGN KEY(rider_id) REFERENCES riders(id)
            );

            CREATE TABLE IF NOT EXISTS mechanics (
                id              TEXT PRIMARY KEY,
                name            TEXT NOT NULL,
                phone           TEXT NOT NULL,
                stage           TEXT NOT NULL,
                district        TEXT NOT NULL DEFAULT 'Kampala',
                shop_name       TEXT,
                specialties     TEXT,
                is_available    INTEGER DEFAULT 1,
                is_verified     INTEGER DEFAULT 0,
                rating          REAL    DEFAULT 0,
                jobs_completed  INTEGER DEFAULT 0,
                latitude        REAL,
                longitude       REAL,
                last_seen       TEXT,
                created_at      TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS messages (
                id          TEXT PRIMARY KEY,
                sender_id   TEXT NOT NULL,
                sender_name TEXT NOT NULL,
                receiver_id TEXT NOT NULL,
                text        TEXT NOT NULL,
                sent_at     TEXT NOT NULL,
                is_read     INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS trips (
                id                TEXT PRIMARY KEY,
                rider_id          TEXT NOT NULL,
                rider_name        TEXT NOT NULL,
                rider_phone       TEXT NOT NULL,
                start_lat         REAL NOT NULL,
                start_lng         REAL NOT NULL,
                current_lat       REAL,
                current_lng       REAL,
                start_label       TEXT,
                destination_label TEXT,
                status            TEXT DEFAULT 'active',
                share_token       TEXT UNIQUE,
                started_at        TEXT NOT NULL,
                ended_at          TEXT,
                FOREIGN KEY(rider_id) REFERENCES riders(id)
            );

            CREATE TABLE IF NOT EXISTS fcm_tokens (
                rider_id    TEXT PRIMARY KEY,
                fcm_token   TEXT NOT NULL,
                updated_at  TEXT NOT NULL,
                FOREIGN KEY(rider_id) REFERENCES riders(id)
            );
        """)
        db.commit()
    log.info("Database initialised")


# ── Helpers ───────────────────────────────────────────────────────────────────

def haversine_km(lat1, lon1, lat2, lon2):
    """Great-circle distance in km."""
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(d_lon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def send_sms(to: str, body: str) -> bool:
    """Send SMS via Twilio. Returns True on success."""
    client = get_twilio()
    if not client or not TWILIO_FROM:
        log.warning("Twilio not configured – SMS skipped (to=%s)", to)
        return False
    # Truncate body to Twilio's 1600-char limit
    body = body[:1580]
    try:
        msg = client.messages.create(body=body, from_=TWILIO_FROM, to=to)
        log.info("SMS sent sid=%s to=%s", msg.sid, to)
        return True
    except Exception as exc:
        log.error("SMS failed to=%s err=%s", to, exc)
        return False


def sanitize(value: str, max_len: int = 200) -> str:
    """Strip and truncate a string input."""
    return str(value).strip()[:max_len]


def validate_coords(lat, lng):
    """Return (float, float) or raise ValueError."""
    lat, lng = float(lat), float(lng)
    if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
        raise ValueError("Coordinates out of range")
    # Uganda bounding box (loose)
    if not (-2 <= lat <= 5 and 29 <= lng <= 36):
        log.warning("Coordinates outside Uganda: %s, %s", lat, lng)
    return lat, lng


# ── Decorators ────────────────────────────────────────────────────────────────

def require_json(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not request.is_json:
            return jsonify({"error": "Content-Type must be application/json"}), 415
        return f(*args, **kwargs)
    return wrapper


def require_api_key(f):
    """Validate X-API-Key header against API_SECRET_KEY (if set)."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not API_SECRET_KEY:
            return f(*args, **kwargs)   # dev mode — no key required
        key = request.headers.get("X-API-Key", "")
        # Constant-time comparison to prevent timing attacks
        if not hmac.compare_digest(key, API_SECRET_KEY):
            log.warning("Rejected request — bad API key from %s", request.remote_addr)
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper


def require_admin_key(f):
    """Validate X-Admin-Key header against ADMIN_SECRET_KEY."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not ADMIN_KEY:
            return jsonify({"error": "Admin access disabled — set ADMIN_SECRET_KEY"}), 403
        key = request.headers.get("X-Admin-Key", "")
        if not hmac.compare_digest(key, ADMIN_KEY):
            return jsonify({"error": "Forbidden"}), 403
        return f(*args, **kwargs)
    return wrapper


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    db = get_db()
    rider_count = db.execute("SELECT COUNT(*) FROM riders").fetchone()[0]
    return jsonify({
        "status": "ok",
        "service": "BodaSOS API",
        "riders": rider_count,
        "timestamp": datetime.utcnow().isoformat(),
    })


@app.post("/register")
@require_json
@require_api_key
@limiter.limit("10 per minute")
def register():
    """Register or update a boda rider."""
    data = request.get_json()
    required = ["id", "name", "phone", "stage", "area"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    district = sanitize(data.get("district", "Kampala"), 50)
    if district not in VALID_DISTRICTS:
        district = "Kampala"

    db = get_db()
    try:
        db.execute(
            """INSERT INTO riders (id, name, phone, stage, area, district, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                   name=excluded.name,
                   phone=excluded.phone,
                   stage=excluded.stage,
                   area=excluded.area,
                   district=excluded.district""",
            (
                sanitize(data["id"], 36),
                sanitize(data["name"], 100),
                sanitize(data["phone"], 20),
                sanitize(data["stage"], 100),
                sanitize(data["area"], 100),
                district,
                datetime.utcnow().isoformat(),
            ),
        )
        db.commit()
    except sqlite3.Error as e:
        log.error("Register DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    log.info("Registered rider %s (%s)", data["name"], data["phone"])
    return jsonify({
        "success": True,
        "message": f"Welcome to BodaSOS, {sanitize(data['name'], 50)}!",
        "rider_id": data["id"],
    }), 201


@app.post("/update_location")
@require_json
@require_api_key
@limiter.limit("120 per minute")   # 30s interval × riders
def update_location():
    """Heartbeat GPS update from rider."""
    data = request.get_json()
    rider_id = data.get("rider_id")
    if not rider_id:
        return jsonify({"error": "rider_id required"}), 400

    try:
        lat, lng = validate_coords(data.get("latitude"), data.get("longitude"))
    except (TypeError, ValueError):
        return jsonify({"error": "Valid latitude and longitude required"}), 400

    accuracy = float(data.get("accuracy", 0))
    now = datetime.utcnow().isoformat()
    db = get_db()
    try:
        rows = db.execute("UPDATE riders SET latitude=?, longitude=?, accuracy=?, last_seen=?, is_online=1 WHERE id=?",
                          (lat, lng, accuracy, now, sanitize(rider_id, 36))).rowcount
        if rows == 0:
            return jsonify({"error": "Rider not found"}), 404

        db.execute(
            "INSERT INTO location_updates (rider_id, latitude, longitude, accuracy, timestamp) VALUES (?,?,?,?,?)",
            (rider_id, lat, lng, accuracy, now),
        )
        # Mark stale riders offline (>5 min)
        cutoff = (datetime.utcnow() - timedelta(minutes=5)).isoformat()
        db.execute("UPDATE riders SET is_online=0 WHERE last_seen < ? AND id != ?",
                   (cutoff, rider_id))
        db.commit()
    except sqlite3.Error as e:
        log.error("update_location DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    return jsonify({"success": True})


@app.post("/sos")
@require_json
@require_api_key
@limiter.limit("5 per minute")   # hard cap — can't spam SOS
def trigger_sos():
    """
    Emergency SOS trigger.
    Alerts riders within SOS_RADIUS_KM and the district police station.
    """
    data = request.get_json()
    required = ["rider_id", "rider_name", "rider_phone", "latitude", "longitude", "stage"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    try:
        lat, lng = validate_coords(data["latitude"], data["longitude"])
    except (TypeError, ValueError) as e:
        return jsonify({"error": str(e)}), 400

    rider_name  = sanitize(data["rider_name"], 100)
    rider_phone = sanitize(data["rider_phone"], 20)
    stage       = sanitize(data["stage"], 100)
    district    = sanitize(data.get("district", "Kampala"), 50)
    if district not in VALID_DISTRICTS:
        district = "Kampala"

    db = get_db()

    # 1. Find nearby online riders ─────────────────────────────────────────────
    all_riders = db.execute(
        "SELECT id, name, phone, latitude, longitude FROM riders WHERE is_online=1 AND id != ?",
        (sanitize(data["rider_id"], 36),),
    ).fetchall()

    nearby = []
    for r in all_riders:
        if r["latitude"] is None or r["longitude"] is None:
            continue
        dist = haversine_km(lat, lng, r["latitude"], r["longitude"])
        if dist <= SOS_RADIUS_KM:
            nearby.append({**dict(r), "distance_km": dist})

    nearby.sort(key=lambda x: x["distance_km"])

    # 2. SMS nearby riders ─────────────────────────────────────────────────────
    maps_link = f"https://maps.google.com/?q={lat},{lng}"
    rider_sms = (
        f"🆘 BODASOS EMERGENCY!\n"
        f"{rider_name} needs help at {stage}!\n"
        f"📞 Call: {rider_phone}\n"
        f"📍 {maps_link}"
    )

    sms_count = 0
    for r in nearby[:10]:
        if send_sms(r["phone"], rider_sms):
            sms_count += 1

    # 3. SMS police ────────────────────────────────────────────────────────────
    police = POLICE_CONTACTS.get(district, POLICE_CONTACTS["Kampala"])
    police_sms = (
        f"🚨 BODA EMERGENCY REPORT\n"
        f"Rider: {rider_name} · {rider_phone}\n"
        f"Stage: {stage}, {district}\n"
        f"GPS: {lat:.6f},{lng:.6f}\n"
        f"Maps: {maps_link}\n"
        f"Time: {datetime.utcnow().strftime('%Y-%m-%d %H:%M')} UTC"
    )
    police_alerted = send_sms(police["phone"], police_sms)

    # 4. Save event ────────────────────────────────────────────────────────────
    try:
        db.execute(
            """INSERT INTO sos_events
               (rider_id, rider_name, rider_phone, latitude, longitude,
                stage, district, message, riders_alerted, police_alerted, timestamp)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (
                data["rider_id"], rider_name, rider_phone,
                lat, lng, stage, district,
                f"EMERGENCY! {rider_name} at {stage}",
                sms_count, 1 if police_alerted else 0,
                datetime.utcnow().isoformat(),
            ),
        )
        db.commit()
    except sqlite3.Error as e:
        log.error("SOS DB error: %s", e)

    log.warning("SOS from %s at %s — %d riders alerted, police=%s",
                rider_name, stage, sms_count, police_alerted)

    return jsonify({
        "success": True,
        "message": "Help is on the way!",
        "riders_alerted": sms_count,
        "police_alerted": police_alerted,
        "police_name": police["name"],
        "maps_link": maps_link,
    })


@app.get("/nearby_riders")
@require_api_key
@limiter.limit("60 per minute")
def nearby_riders():
    """Return active riders within radius."""
    try:
        lat, lng = validate_coords(
            request.args.get("latitude"), request.args.get("longitude")
        )
        radius = min(float(request.args.get("radius_km", SOS_RADIUS_KM)), 20.0)
    except (TypeError, ValueError):
        return jsonify({"error": "Valid latitude and longitude required"}), 400

    db = get_db()
    riders = db.execute(
        """SELECT id, name, stage, latitude, longitude, last_seen, is_online
           FROM riders WHERE latitude IS NOT NULL AND is_online=1"""
    ).fetchall()

    result = []
    for r in riders:
        dist = haversine_km(lat, lng, r["latitude"], r["longitude"])
        if dist <= radius:
            result.append({
                "id":          r["id"],
                "name":        r["name"],
                "stage":       r["stage"],
                "latitude":    r["latitude"],
                "longitude":   r["longitude"],
                "last_seen":   r["last_seen"],
                "is_online":   bool(r["is_online"]),
                "distance_km": round(dist, 3),
                # phone NOT exposed — only shared during SOS
            })

    result.sort(key=lambda x: x["distance_km"])
    return jsonify({
        "riders":    result,
        "total":     len(result),
        "radius_km": radius,
        "timestamp": datetime.utcnow().isoformat(),
    })


@app.get("/sos_history")
@require_admin_key
def sos_history():
    """Admin — recent SOS events."""
    limit = min(int(request.args.get("limit", 50)), 200)
    db = get_db()
    events = db.execute(
        "SELECT * FROM sos_events ORDER BY id DESC LIMIT ?", (limit,)
    ).fetchall()
    return jsonify({"events": [dict(e) for e in events]})


# ── Repair Routes ─────────────────────────────────────────────────────────────

@app.post("/repair/request")
@require_json
@require_api_key
@limiter.limit("10 per minute")
def repair_request():
    """Submit a bike repair request. Alerts nearby riders via SMS."""
    data = request.get_json()
    required = ["id", "rider_id", "rider_name", "rider_phone", "issue", "latitude", "longitude", "stage"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    issue = sanitize(data["issue"], 30)
    if issue not in VALID_ISSUES:
        return jsonify({"error": f"Invalid issue type: {issue}"}), 400

    try:
        lat, lng = validate_coords(data["latitude"], data["longitude"])
    except (TypeError, ValueError) as e:
        return jsonify({"error": str(e)}), 400

    rider_name  = sanitize(data["rider_name"], 100)
    rider_phone = sanitize(data["rider_phone"], 20)
    stage       = sanitize(data["stage"], 100)
    district    = sanitize(data.get("district", "Kampala"), 50)
    note        = sanitize(data.get("custom_note", ""), 300)
    if district not in VALID_DISTRICTS:
        district = "Kampala"

    now = datetime.utcnow().isoformat()
    db = get_db()

    try:
        db.execute(
            """INSERT INTO repair_requests
               (id, rider_id, rider_name, rider_phone, issue, custom_note,
                latitude, longitude, stage, district, status, created_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (sanitize(data["id"], 36), sanitize(data["rider_id"], 36),
             rider_name, rider_phone, issue, note or None,
             lat, lng, stage, district, "pending", now),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"error": "Duplicate request ID"}), 409
    except sqlite3.Error as e:
        log.error("repair_request DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    # Alert nearby riders
    riders = db.execute(
        "SELECT name, phone, latitude, longitude FROM riders WHERE is_online=1 AND id != ? AND latitude IS NOT NULL",
        (data["rider_id"],),
    ).fetchall()

    maps_link   = f"https://maps.google.com/?q={lat},{lng}"
    issue_text  = ISSUE_LABELS.get(issue, issue)
    note_line   = f"Note: {note}\n" if note else ""
    sms_body = (
        f"🔧 BODA REPAIR ALERT!\n"
        f"{rider_name} needs help at {stage}!\n"
        f"Problem: {issue_text}\n"
        f"{note_line}"
        f"📞 Call: {rider_phone}\n"
        f"📍 {maps_link}"
    )

    nearby = [
        {**dict(r), "dist": haversine_km(lat, lng, r["latitude"], r["longitude"])}
        for r in riders
        if r["latitude"] is not None
    ]
    nearby = sorted([n for n in nearby if n["dist"] <= REPAIR_RADIUS_KM], key=lambda x: x["dist"])

    sms_count = sum(1 for r in nearby[:10] if send_sms(r["phone"], sms_body))

    db.execute("UPDATE repair_requests SET responders_count=? WHERE id=?",
               (sms_count, data["id"]))
    db.commit()

    log.info("Repair %s from %s at %s — %d riders alerted", data["id"], rider_name, stage, sms_count)

    return jsonify({
        "success": True,
        "message": "Help is being sent your way!",
        "responders_alerted": sms_count,
        "maps_link": maps_link,
    }), 201


@app.post("/repair/cancel")
@require_json
@require_api_key
@limiter.limit("20 per minute")
def repair_cancel():
    """Cancel a repair request — only the requesting rider can cancel."""
    data = request.get_json()
    request_id = data.get("request_id")
    rider_id   = data.get("rider_id")
    if not request_id or not rider_id:
        return jsonify({"error": "request_id and rider_id required"}), 400

    db = get_db()
    row = db.execute(
        "SELECT rider_id, status FROM repair_requests WHERE id=?",
        (sanitize(request_id, 36),)
    ).fetchone()

    if not row:
        return jsonify({"error": "Request not found"}), 404
    if row["rider_id"] != sanitize(rider_id, 36):
        return jsonify({"error": "You can only cancel your own requests"}), 403
    if row["status"] in ("done", "cancelled"):
        return jsonify({"error": f"Cannot cancel a {row['status']} request"}), 409

    db.execute(
        "UPDATE repair_requests SET status='cancelled', updated_at=? WHERE id=?",
        (datetime.utcnow().isoformat(), request_id),
    )
    db.commit()
    return jsonify({"success": True})


@app.get("/repair/status/<request_id>")
@require_api_key
@limiter.limit("60 per minute")
def repair_status(request_id):
    """Get live status of a repair request."""
    db = get_db()
    row = db.execute(
        "SELECT * FROM repair_requests WHERE id=?", (sanitize(request_id, 36),)
    ).fetchone()
    if not row:
        return jsonify({"error": "Request not found"}), 404
    return jsonify({"success": True, "request": dict(row)})


@app.get("/repair/nearby")
@require_api_key
@limiter.limit("60 per minute")
def repair_nearby():
    """Return open repair requests near given coordinates."""
    try:
        lat, lng = validate_coords(
            request.args.get("latitude"), request.args.get("longitude")
        )
        radius = min(float(request.args.get("radius_km", REPAIR_RADIUS_KM)), 20.0)
    except (TypeError, ValueError):
        return jsonify({"error": "Valid latitude and longitude required"}), 400

    db = get_db()
    rows = db.execute(
        """SELECT id, rider_name, issue, custom_note, latitude, longitude,
                  stage, district, status, created_at, responders_count
           FROM repair_requests
           WHERE status IN ('pending','accepted','onTheWay') AND latitude IS NOT NULL
           ORDER BY created_at DESC LIMIT 50"""
    ).fetchall()   # rider_phone intentionally excluded from public query

    result = []
    for r in rows:
        dist = haversine_km(lat, lng, r["latitude"], r["longitude"])
        if dist <= radius:
            item = dict(r)
            item["distance_km"] = round(dist, 3)
            result.append(item)

    result.sort(key=lambda x: x["distance_km"])
    return jsonify({"requests": result, "total": len(result), "radius_km": radius})


@app.get("/repair/history/<rider_id>")
@require_api_key
@limiter.limit("30 per minute")
def repair_history(rider_id):
    """Repair history for a specific rider (their own data only)."""
    db = get_db()
    rows = db.execute(
        "SELECT * FROM repair_requests WHERE rider_id=? ORDER BY created_at DESC LIMIT 20",
        (sanitize(rider_id, 36),),
    ).fetchall()
    return jsonify({"requests": [dict(r) for r in rows]})


# ── Mechanic Routes ───────────────────────────────────────────────────────────

@app.post("/mechanic/register")
@require_json
@require_api_key
@limiter.limit("10 per minute")
def mechanic_register():
    data = request.get_json()
    required = ["id", "name", "phone", "stage"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing: {', '.join(missing)}"}), 400

    district = sanitize(data.get("district", "Kampala"), 50)
    if district not in VALID_DISTRICTS:
        district = "Kampala"

    db = get_db()
    try:
        db.execute(
            """INSERT INTO mechanics
               (id, name, phone, stage, district, shop_name, specialties, created_at)
               VALUES (?,?,?,?,?,?,?,?)
               ON CONFLICT(id) DO UPDATE SET
                   name=excluded.name, phone=excluded.phone,
                   stage=excluded.stage, district=excluded.district,
                   shop_name=excluded.shop_name, specialties=excluded.specialties""",
            (
                sanitize(data["id"], 36),
                sanitize(data["name"], 100),
                sanitize(data["phone"], 20),
                sanitize(data["stage"], 100),
                district,
                sanitize(data.get("shop_name", ""), 100),
                sanitize(data.get("specialties", ""), 200),
                datetime.utcnow().isoformat(),
            ),
        )
        db.commit()
    except sqlite3.Error as e:
        log.error("mechanic_register DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    log.info("Mechanic registered: %s (%s)", data["name"], data["phone"])
    return jsonify({"success": True, "message": f"Welcome, {sanitize(data['name'],50)}!"}), 201


@app.get("/mechanic/nearby")
@require_api_key
@limiter.limit("60 per minute")
def mechanic_nearby():
    try:
        lat, lng = validate_coords(
            request.args.get("latitude"), request.args.get("longitude")
        )
        radius = min(float(request.args.get("radius_km", 5.0)), 20.0)
    except (TypeError, ValueError):
        return jsonify({"error": "Valid latitude and longitude required"}), 400

    db = get_db()
    rows = db.execute(
        """SELECT id, name, stage, district, shop_name, specialties,
                  is_available, is_verified, rating, jobs_completed,
                  latitude, longitude, last_seen
           FROM mechanics
           WHERE is_available=1 AND latitude IS NOT NULL"""
    ).fetchall()   # phone intentionally excluded

    result = []
    for r in rows:
        dist = haversine_km(lat, lng, r["latitude"], r["longitude"])
        if dist <= radius:
            item = dict(r)
            item["distance_km"] = round(dist, 3)
            result.append(item)

    result.sort(key=lambda x: x["distance_km"])
    return jsonify({"mechanics": result, "total": len(result)})


# ── FCM Token Route ───────────────────────────────────────────────────────────

@app.post("/fcm_token")
@require_json
@require_api_key
@limiter.limit("30 per minute")
def fcm_token():
    data = request.get_json()
    rider_id  = sanitize(data.get("rider_id", ""), 36)
    fcm_token = sanitize(data.get("fcm_token", ""), 300)
    if not rider_id or not fcm_token:
        return jsonify({"error": "rider_id and fcm_token required"}), 400

    db = get_db()
    db.execute(
        """INSERT INTO fcm_tokens (rider_id, fcm_token, updated_at)
           VALUES (?,?,?)
           ON CONFLICT(rider_id) DO UPDATE SET
               fcm_token=excluded.fcm_token, updated_at=excluded.updated_at""",
        (rider_id, fcm_token, datetime.utcnow().isoformat()),
    )
    db.commit()
    return jsonify({"success": True})


# ── Message Routes ────────────────────────────────────────────────────────────

@app.post("/messages/send")
@require_json
@require_api_key
@limiter.limit("60 per minute")
def messages_send():
    data = request.get_json()
    required = ["id", "sender_id", "sender_name", "receiver_id", "text"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing: {', '.join(missing)}"}), 400

    text = sanitize(data["text"], 1000)
    if not text:
        return jsonify({"error": "Message text cannot be empty"}), 400

    db = get_db()
    try:
        db.execute(
            """INSERT OR IGNORE INTO messages
               (id, sender_id, sender_name, receiver_id, text, sent_at)
               VALUES (?,?,?,?,?,?)""",
            (
                sanitize(data["id"], 36),
                sanitize(data["sender_id"], 36),
                sanitize(data["sender_name"], 100),
                sanitize(data["receiver_id"], 36),
                text,
                data.get("sent_at", datetime.utcnow().isoformat()),
            ),
        )
        db.commit()
    except sqlite3.Error as e:
        log.error("messages_send DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    return jsonify({"success": True}), 201


@app.get("/messages/thread/<my_id>/<peer_id>")
@require_api_key
@limiter.limit("120 per minute")
def messages_thread(my_id, peer_id):
    my_id   = sanitize(my_id, 36)
    peer_id = sanitize(peer_id, 36)
    db = get_db()
    rows = db.execute(
        """SELECT id, sender_id, sender_name, receiver_id, text, sent_at, is_read
           FROM messages
           WHERE (sender_id=? AND receiver_id=?)
              OR (sender_id=? AND receiver_id=?)
           ORDER BY sent_at ASC LIMIT 200""",
        (my_id, peer_id, peer_id, my_id),
    ).fetchall()

    # Mark as read
    db.execute(
        "UPDATE messages SET is_read=1 WHERE sender_id=? AND receiver_id=? AND is_read=0",
        (peer_id, my_id),
    )
    db.commit()

    return jsonify({"messages": [dict(r) for r in rows]})


@app.get("/messages/conversations/<rider_id>")
@require_api_key
@limiter.limit("60 per minute")
def messages_conversations(rider_id):
    rid = sanitize(rider_id, 36)
    db  = get_db()
    # Return latest message per peer, with unread count
    rows = db.execute(
        """SELECT
               CASE WHEN sender_id=? THEN receiver_id ELSE sender_id END AS peer_id,
               CASE WHEN sender_id=? THEN
                   (SELECT name FROM riders WHERE id=receiver_id LIMIT 1)
               ELSE sender_name END AS peer_name,
               text AS last_message,
               sent_at AS last_at,
               SUM(CASE WHEN sender_id!=? AND is_read=0 THEN 1 ELSE 0 END) AS unread_count
           FROM messages
           WHERE sender_id=? OR receiver_id=?
           GROUP BY peer_id
           ORDER BY last_at DESC""",
        (rid, rid, rid, rid, rid),
    ).fetchall()
    return jsonify({"conversations": [dict(r) for r in rows]})


# ── Trip / Ride Tracking Routes ───────────────────────────────────────────────

@app.post("/trips/start")
@require_json
@require_api_key
@limiter.limit("20 per minute")
def trips_start():
    data = request.get_json()
    required = ["id", "rider_id", "rider_name", "rider_phone",
                "start_lat", "start_lng", "started_at"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing: {', '.join(missing)}"}), 400

    try:
        lat, lng = validate_coords(data["start_lat"], data["start_lng"])
    except (TypeError, ValueError) as e:
        return jsonify({"error": str(e)}), 400

    token = sanitize(data.get("share_token", ""), 20) or data["id"][:8].upper()
    db = get_db()
    try:
        db.execute(
            """INSERT INTO trips
               (id, rider_id, rider_name, rider_phone, start_lat, start_lng,
                current_lat, current_lng, start_label, destination_label,
                status, share_token, started_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                sanitize(data["id"], 36),
                sanitize(data["rider_id"], 36),
                sanitize(data["rider_name"], 100),
                sanitize(data["rider_phone"], 20),
                lat, lng, lat, lng,
                sanitize(data.get("start_label", ""), 200),
                sanitize(data.get("destination_label", ""), 200) or None,
                "active", token,
                data["started_at"],
            ),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"error": "Duplicate trip ID"}), 409
    except sqlite3.Error as e:
        log.error("trips_start DB error: %s", e)
        return jsonify({"error": "Database error"}), 500

    share_url = f"https://bodasos.app/track/{token}"
    return jsonify({"success": True, "share_token": token, "share_url": share_url}), 201


@app.post("/trips/update")
@require_json
@require_api_key
@limiter.limit("120 per minute")
def trips_update():
    data = request.get_json()
    trip_id = sanitize(data.get("trip_id", ""), 36)
    if not trip_id:
        return jsonify({"error": "trip_id required"}), 400
    try:
        lat, lng = validate_coords(data.get("latitude"), data.get("longitude"))
    except (TypeError, ValueError) as e:
        return jsonify({"error": str(e)}), 400

    db = get_db()
    db.execute(
        "UPDATE trips SET current_lat=?, current_lng=? WHERE id=? AND status='active'",
        (lat, lng, trip_id),
    )
    db.commit()
    return jsonify({"success": True})


@app.post("/trips/end")
@require_json
@require_api_key
@limiter.limit("20 per minute")
def trips_end():
    data = request.get_json()
    trip_id = sanitize(data.get("trip_id", ""), 36)
    if not trip_id:
        return jsonify({"error": "trip_id required"}), 400

    db = get_db()
    db.execute(
        "UPDATE trips SET status='completed', ended_at=? WHERE id=?",
        (datetime.utcnow().isoformat(), trip_id),
    )
    db.commit()
    return jsonify({"success": True})


@app.get("/trips/track/<token>")
def trips_track(token):
    """Public endpoint — no auth needed, used by passengers to view rider location."""
    db = get_db()
    row = db.execute(
        """SELECT rider_name, rider_phone, current_lat, current_lng,
                  start_label, destination_label, status, started_at
           FROM trips WHERE share_token=?""",
        (sanitize(token, 20),),
    ).fetchone()
    if not row:
        return jsonify({"error": "Trip not found or expired"}), 404
    return jsonify({"trip": dict(row)})


# ── Admin Dashboard ───────────────────────────────────────────────────────────

@app.get("/admin/stats")
@require_admin_key
def admin_stats():
    db = get_db()
    stats = {
        "riders":          db.execute("SELECT COUNT(*) FROM riders").fetchone()[0],
        "riders_online":   db.execute("SELECT COUNT(*) FROM riders WHERE is_online=1").fetchone()[0],
        "mechanics":       db.execute("SELECT COUNT(*) FROM mechanics").fetchone()[0],
        "sos_total":       db.execute("SELECT COUNT(*) FROM sos_events").fetchone()[0],
        "sos_today":       db.execute("SELECT COUNT(*) FROM sos_events WHERE timestamp >= date('now')").fetchone()[0],
        "repairs_open":    db.execute("SELECT COUNT(*) FROM repair_requests WHERE status='pending'").fetchone()[0],
        "repairs_total":   db.execute("SELECT COUNT(*) FROM repair_requests").fetchone()[0],
        "trips_active":    db.execute("SELECT COUNT(*) FROM trips WHERE status='active'").fetchone()[0],
        "messages_today":  db.execute("SELECT COUNT(*) FROM messages WHERE sent_at >= date('now')").fetchone()[0],
        "timestamp":       datetime.utcnow().isoformat(),
    }
    return jsonify(stats)


@app.get("/admin/sos")
@require_admin_key
def admin_sos():
    limit = min(int(request.args.get("limit", 100)), 500)
    db = get_db()
    rows = db.execute(
        "SELECT * FROM sos_events ORDER BY id DESC LIMIT ?", (limit,)
    ).fetchall()
    return jsonify({"events": [dict(r) for r in rows], "total": len(rows)})


@app.get("/admin/riders")
@require_admin_key
def admin_riders():
    db = get_db()
    rows = db.execute(
        """SELECT id, name, stage, district, is_online, last_seen, created_at
           FROM riders ORDER BY created_at DESC"""
    ).fetchall()   # phone excluded from admin listing too
    return jsonify({"riders": [dict(r) for r in rows], "total": len(rows)})


@app.get("/admin/repairs")
@require_admin_key
def admin_repairs():
    limit = min(int(request.args.get("limit", 100)), 500)
    db = get_db()
    rows = db.execute(
        "SELECT * FROM repair_requests ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    return jsonify({"repairs": [dict(r) for r in rows], "total": len(rows)})


# ── Error handlers ────────────────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(_):
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(405)
def method_not_allowed(_):
    return jsonify({"error": "Method not allowed"}), 405

@app.errorhandler(429)
def rate_limited(_):
    return jsonify({"error": "Too many requests. Please slow down."}), 429

@app.errorhandler(500)
def server_error(_):
    return jsonify({"error": "Internal server error"}), 500


# ── Init DB at module load (works with Gunicorn) ──────────────────────────────
init_db()

# ── Run ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port  = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    log.info("BodaSOS API starting on port %d (debug=%s)", port, debug)
    app.run(host="0.0.0.0", port=port, debug=debug)
