import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'scan_screen.dart';
import 'override_request.dart';
import 'my_records.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userName = '';
  bool _manualAllowed = false;
  bool _isMarkingManual = false;
  StreamSubscription? _manualAllowedSub;

  // DEMO MODE: spoof GPS to Manipal so emulator passes geo-fence
  // Set to false in production
  static const bool _demoMode = true;
  static const double _demoLat = 13.34740;
  static const double _demoLng = 74.79290;

  @override
  void initState() {
    super.initState();
    _listenManualAllowed();
    _fetchUserName();
  }

  // Listens to THIS USER'S own doc for manualAllowed.
  // Admin sets manualAllowed: true on a specific user when approving
  // their override request — so only that user sees the manual button.
  void _listenManualAllowed() {
    final uid = _auth.currentUser!.uid;
    _manualAllowedSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _manualAllowed = doc.data()?['manualAllowed'] ?? false;
        });
      }
    });
  }

  @override
  void dispose() {
    _manualAllowedSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _userName = doc.data()?['name'] ?? '';
      });
    }
  }

  Future<void> _markManualAttendance() async {
    setState(() => _isMarkingManual = true);

    try {
      double userLat;
      double userLng;

      if (_demoMode) {
        userLat = _demoLat;
        userLng = _demoLng;
      } else {
        // Real GPS
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          _showResult(false,
              'Location permission permanently denied. Please enable it in settings.');
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (position.isMocked) {
          _showResult(false, 'Fake GPS detected! Attendance rejected.');
          return;
        }

        userLat = position.latitude;
        userLng = position.longitude;
      }

      // Fetch all geo-fence locations
      final locationsSnapshot =
      await _firestore.collection('locations').get();

      if (locationsSnapshot.docs.isEmpty) {
        _showResult(
            false, 'No geo-fence locations set. Please contact admin.');
        return;
      }

      // Check if user is within ANY saved location
      bool withinFence = false;
      String closestLocationName = '';
      double closestDistance = double.infinity;
      double closestRadius = 200;

      for (final doc in locationsSnapshot.docs) {
        final data = doc.data();
        final double fenceLat = (data['latitude'] as num).toDouble();
        final double fenceLng = (data['longitude'] as num).toDouble();
        final double fenceRadius = (data['radiusMeters'] as num).toDouble();
        final String locationName = data['name'] ?? 'campus';

        double distance = Geolocator.distanceBetween(
          userLat, userLng, fenceLat, fenceLng,
        );

        if (distance < closestDistance) {
          closestDistance = distance;
          closestLocationName = locationName;
          closestRadius = fenceRadius;
        }

        if (distance <= fenceRadius) {
          withinFence = true;
          break;
        }
      }

      if (!withinFence) {
        _showResult(false,
            'You are ${closestDistance.toStringAsFixed(0)}m away from '
                '$closestLocationName. Must be within ${closestRadius.toStringAsFixed(0)}m.');
        return;
      }

      // Get latest active session
      final sessions = await _firestore
          .collection('sessions')
          .where('active', isEqualTo: true)
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      if (sessions.docs.isEmpty) {
        _showResult(false, 'No active session found. Please contact admin.');
        return;
      }

      final session = sessions.docs.first;
      final sessionId = session['sessionId'];
      final expiresAt = (session['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        _showResult(false, 'Session has expired. Please contact admin.');
        return;
      }

      // Check if already marked
      final existing = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(false, 'Attendance already marked for this session!');
        return;
      }

      // Write attendance record
      await _firestore.collection('attendance').add({
        'userId': _auth.currentUser!.uid,
        'sessionId': sessionId,
        'timestamp': Timestamp.now(),
        'locationId': 'default',
        'method': 'manual',
        'latitude': userLat,
        'longitude': userLng,
        'distance': closestDistance,
        'status': 'present',
      });

      // Consume the one-time unlock — reset manualAllowed on this user's doc
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'manualAllowed': false});

      _showResult(true, 'Attendance marked successfully! ✅');
    } catch (e) {
      _showResult(false, 'Error: ${e.toString()}');
    } finally {
      setState(() => _isMarkingManual = false);
    }
  }

  void _showResult(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.cancel,
              color: success ? Colors.green : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('My Attendance',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userName.isEmpty ? 'Hello! 👋' : 'Hello, $_userName! 👋',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text('Mark your attendance below',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),

            // ── Scan QR button ──────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FC3F7).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 64, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Scan QR Code',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to mark your attendance',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Manual attendance (only visible when override approved) ──
            if (_manualAllowed) ...[
              GestureDetector(
                onTap: _isMarkingManual ? null : _markManualAttendance,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF66BB6A).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: _isMarkingManual
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white))
                      : const Column(
                    children: [
                      Icon(Icons.touch_app,
                          size: 48, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Mark Attendance Manually',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Override approved — tap to mark',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Info card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4FC3F7)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure you are within the campus geo-fence before scanning.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Override request ────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OverrideRequest()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFFB74D).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note,
                        color: Color(0xFFFFB74D), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Request Manual Override',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('For emergencies or GPS issues',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: Color(0xFFFFB74D), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── My records ──────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyRecords()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFCE93D8).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history,
                        color: Color(0xFFCE93D8), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Attendance Records',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('View your attendance history',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: Color(0xFFCE93D8), size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}