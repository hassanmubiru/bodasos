# 🏍️ BodaSOS — Emergency System for Boda Boda Riders, Uganda

> **"One tap can save a life."**  
> Built for boda boda riders across Kampala, Wakiso, and Uganda.

---

## 📱 App Overview

BodaSOS is an offline-first emergency system that lets boda riders:
- Register their name, phone, and stage in seconds
- Share live GPS location every 30 seconds
- Trigger a one-tap SOS that alerts police + nearby riders via SMS
- Work even without internet (offline mode with sync)

---

## 🗂 Project Structure

```
bodasos/
├── lib/
│   ├── main.dart                  ← App entry, auth routing
│   ├── models/
│   │   └── rider.dart             ← Rider model, Uganda stages, police contacts
│   ├── screens/
│   │   ├── login_screen.dart      ← Registration (English/Luganda)
│   │   ├── dashboard_screen.dart  ← Map, rider list, GPS status
│   │   └── sos_screen.dart        ← Giant SOS button, shake detection
│   └── services/
│       ├── api_service.dart       ← Flask backend HTTP calls
│       ├── database_service.dart  ← SQLite local storage
│       ├── location_service.dart  ← GPS tracking (30s heartbeat)
│       └── sos_service.dart       ← Alarm, vibration, shake detection
├── backend/
│   ├── app.py                     ← Flask API (register/location/SOS/nearby)
│   ├── requirements.txt
│   └── .env.example
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml   ← All required permissions
└── pubspec.yaml
```

---

## ⚡ Quick Start (2 Days to Production)

### Day 1 — Backend Setup (2–3 hours)

```bash
cd backend
cp .env.example .env
# Fill in your Twilio credentials in .env

pip install -r requirements.txt
python app.py
# API running at http://localhost:5000
```

**Test the API:**
```bash
# Health check
curl http://localhost:5000/health

# Register a rider
curl -X POST http://localhost:5000/register \
  -H "Content-Type: application/json" \
  -d '{"id":"test-1","name":"Hassan Mukasa","phone":"+256701234567","stage":"Kampala Central","area":"Kampala Central","district":"Kampala"}'

# Trigger SOS test
curl -X POST http://localhost:5000/sos \
  -H "Content-Type: application/json" \
  -d '{"rider_id":"test-1","rider_name":"Hassan","rider_phone":"+256701234567","latitude":0.3476,"longitude":32.5825,"stage":"Kampala Central","district":"Kampala"}'
```

**Deploy to Render (free):**
1. Push `backend/` to GitHub
2. Create new Web Service on render.com
3. Build command: `pip install -r requirements.txt`
4. Start command: `gunicorn app:app`
5. Add environment variables from `.env.example`
6. Copy your Render URL (e.g. `https://bodasos-api.onrender.com`)

### Day 1 — Flutter Setup (2–3 hours)

```bash
# Prerequisites
flutter doctor  # Make sure Flutter is installed

# Update backend URL in lib/services/api_service.dart:
# static const String baseUrl = 'https://your-render-url.onrender.com';

cd bodasos
flutter pub get
flutter run  # Test on connected Android device
```

### Day 2 — Build APK

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for production - requires signing)
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

**Sign the APK for Google Play:**
```bash
keytool -genkey -v -keystore bodasos-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias bodasos

# Add to android/key.properties:
# storePassword=<password>
# keyPassword=<password>
# keyAlias=bodasos
# storeFile=../bodasos-key.jks
```

---

## 📲 Twilio SMS Setup (Uganda MTN/Airtel)

1. Sign up at [twilio.com](https://twilio.com) — free trial includes $15 credit
2. Get a Twilio phone number (US number works for Uganda SMS)
3. Uganda MTN numbers: `+2567XXXXXXXX`
4. Uganda Airtel numbers: `+2567XXXXXXXX`
5. Add to `.env`:
   ```
   TWILIO_ACCOUNT_SID=ACxxxxx
   TWILIO_AUTH_TOKEN=xxxxx
   TWILIO_PHONE_NUMBER=+12025551234
   ```

> **Cost estimate:** ~$0.05 per SMS to Uganda. 10 riders alerted per SOS = ~$0.50/emergency.

---

## 🔒 Privacy & Consent

- Location is **only shared during active SOS** or the 30-second heartbeat
- Riders must **explicitly consent** during registration
- **No data sold** to third parties
- Location data older than 30 days is automatically purged
- Riders can delete their account at any time

---

## 📍 Uganda Stages Covered

| District  | Stages                                           |
|-----------|--------------------------------------------------|
| Kampala   | Central, Nakawa, Makindye, Rubaga, Kawempe, Ntinda, Bukoto, Kololo, Mulago, Makerere |
| Wakiso    | Entebbe, Kajjansi, Nansana, Gayaza, Wakiso Town  |
| Mukono    | Mukono Town, Seeta, Najeera, Kyaliwajjala        |
| Masaka    | Masaka Town, Nyendo                              |
| Mbarara   | Mbarara Town, Kakoba                             |
| Gulu      | Gulu Town, Layibi                                |
| Jinja     | Jinja Town, Walukuba                             |

---

## 🎬 3-Minute Demo Video Script

### [0:00–0:15] Opening
> *"Every day, boda boda riders in Uganda face danger on the roads with no quick way to call for help. BodaSOS changes that."*

**Shot:** Montage of Kampala streets, boda riders at stage

### [0:15–0:45] Registration
> *"Registration takes 30 seconds. Enter your name, MTN or Airtel number, pick your district and stage."*

**Shot:** Show the login screen, fill in "Hassan Mukasa", "+256 701 234 567", select "Kampala" → "Kampala Central", check consent, tap REGISTER

### [0:45–1:15] Dashboard
> *"The dashboard shows your live GPS location, the nearest riders in your area, and the local police contact — even offline."*

**Shot:** Dashboard showing location coords, 3 nearby riders, police card

### [1:15–1:45] SOS Button
> *"One tap opens the SOS screen. The huge red button gives a 5-second countdown — enough time to cancel if it's an accident."*

**Shot:** Tap the SOS button, show countdown 5–4–3–2–1

### [1:45–2:15] SOS In Action
> *"When SOS fires, it immediately alerts nearby riders by SMS and sends a report with GPS coordinates to the district police."*

**Shot:** Show "SENT ✓" screen. Show a phone receiving: "🆘 BODASOS ALERT! Hassan needs help at Kampala Central!"

### [2:15–2:30] Shake Feature
> *"In a real emergency you can't always reach your screen. Shake your phone three times and SOS activates automatically."*

**Shot:** Hand shaking phone, SOS auto-triggers

### [2:30–2:45] Offline Mode
> *"No internet? BodaSOS saves your SOS locally and sends it the moment you reconnect. Critical for rural areas."*

**Shot:** Enable airplane mode, trigger SOS, show "⚠️ Saved offline", reconnect, show sync

### [2:45–3:00] Closing
> *"BodaSOS. Built in Uganda, for Uganda's boda riders. Available now on Android."*

**Shot:** App icon, "Download BodaSOS" CTA

---

## 🛠 Troubleshooting

| Problem | Solution |
|---------|----------|
| GPS not working | Check Location permissions in Android Settings > Apps > BodaSOS |
| SMS not sending | Verify Twilio credentials and account balance |
| Can't connect to backend | Confirm `baseUrl` in `api_service.dart` is correct |
| App crashes on start | Run `flutter clean && flutter pub get` |
| Build fails | Run `flutter doctor` and fix any issues |

---

## 📞 Emergency Numbers (Uganda)

- **Police:** 999 / 0800 199 999
- **Ambulance:** 0800 106 000  
- **Fire Brigade:** 0800 199 999

---

*Built with ❤️ for the safety of Uganda's boda boda community.*
