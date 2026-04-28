# Geo Attendance — Secure Geolocation-Based Attendance System

A Flutter mobile application that eliminates proxy attendance by combining GPS geo-fencing with time-bound QR code scanning. Built with Firebase and OpenStreetMap at zero infrastructure cost.

> March 2026 – April 2026

---

## Features

### User
- **Dual Verification** — Must be physically within a GPS geo-fenced zone and scan a valid QR code to mark attendance
- **Fake GPS Detection** — Detects and blocks mock location and GPS spoofing attempts
- **Proximity Notifications** — Push notifications when entering or leaving a geo-fenced zone
- **Override Requests** — Submit attendance correction requests with reason; notified on approval or rejection
- **Real-Time Sync** — Attendance status updates instantly via Cloud Firestore

### Admin
- **Admin Dashboard** — View all users, locations, and attendance records in real time
- **QR Code Generation** — Generate time-bound QR codes per session and location
- **Interactive Map Location Picker** — Set geo-fence zones visually using OpenStreetMap (no paid API)
- **Override Request Management** — Review and approve or reject user attendance correction requests
- **Multi-Location Support** — Manage multiple geo-fenced locations and user groups
- **Real-Time Reports** — Live attendance reports with Firestore sync

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter / Dart |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Location | Geolocator |
| Maps | flutter_map + OpenStreetMap (Nominatim API) |
| QR Code | QR Flutter (generation) + Mobile Scanner (scanning) |
| Notifications | Flutter Local Notifications |
| IDE | Android Studio |

---

## Screens (11 Total)

1. Splash / Onboarding
2. Login (Role-based: Admin / User)
3. User Dashboard
4. Mark Attendance (QR Scanner + GPS check)
5. Attendance History
6. Override Request Form
7. Notifications
8. Admin Dashboard
9. QR Code Generator
10. Map Location Picker
11. Override Request Management

---

## How Attendance Works

```
User opens app
      |
GPS location verified → Within geo-fence?
      |
Fake GPS check → Real device?
      |
QR code scanned → Valid and not expired?
      |
Attendance marked and synced to Firestore
```

If any step fails, attendance is rejected — no proxy possible.

---

## Getting Started

### Prerequisites

- Flutter SDK 3.x or above
- Dart SDK
- Android Studio
- Firebase project (free tier)

### Setup

1. Clone the repository

   ```bash
   git clone https://github.com/2hani2/geo-attendance.git
   cd geo-attendance
   ```

2. Install dependencies

   ```bash
   flutter pub get
   ```

3. Configure Firebase
   - Create a project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Password) and Cloud Firestore
   - Download `google-services.json` and place it in `android/app/`

4. Run the app

   ```bash
   flutter run
   ```

---

## Infrastructure Cost

| Service | Cost |
|---------|------|
| Firebase Authentication | Free (Spark plan) |
| Cloud Firestore | Free (Spark plan) |
| OpenStreetMap / Nominatim | Free (open source) |
| **Total** | **$0** |

---

## Results

- Fully functional Android app with end-to-end attendance flow
- Supports multiple locations and multiple users
- Real-time Firestore sync across all devices
- Zero infrastructure cost
- Tested on Android Emulator

---

## License

This project is open source and available under the [MIT License](LICENSE).
