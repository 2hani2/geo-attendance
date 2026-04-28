import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  String _statusMessage = 'Point camera at QR code';

  final double _fenceLat = 13.3474;
  final double _fenceLng = 74.7929;
  final double _fenceRadius = 200;
  static const int _lateThresholdMinutes = 10;

  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying QR...';
    });

    cameraController.stop();

    try {
      final qrData = jsonDecode(barcode.rawValue!);
      final sessionId = qrData['session_id'];
      final expiresAt = DateTime.parse(qrData['expires_at']);
      final generatedAt = DateTime.parse(qrData['generated_at']);

      if (DateTime.now().isAfter(expiresAt)) {
        _showResult(false, 'QR code has expired!', isLate: false);
        return;
      }

      // Determine if late
      final minutesSinceGenerated =
          DateTime.now().difference(generatedAt).inMinutes;
      final bool isLate = minutesSinceGenerated >= _lateThresholdMinutes;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      setState(() => _statusMessage = 'Checking your location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (position.isMocked) {
        _showResult(false, 'Fake GPS detected! Attendance rejected.',
            isLate: false);
        return;
      }

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _fenceLat,
        _fenceLng,
      );

      if (distance > _fenceRadius) {
        _showResult(false,
            'You are ${distance.toStringAsFixed(0)}m away from campus. Must be within ${_fenceRadius.toStringAsFixed(0)}m.',
            isLate: false);
        return;
      }

      final existing = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(false, 'Attendance already marked for this session!',
            isLate: false);
        return;
      }

      final status = isLate ? 'late' : 'present';

      await _firestore.collection('attendance').add({
        'userId': _auth.currentUser!.uid,
        'sessionId': sessionId,
        'timestamp': Timestamp.now(),
        'locationId': qrData['location_id'],
        'method': 'qr',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distance': distance,
        'status': status,
      });

      _showResult(
        true,
        isLate
            ? 'Marked as Late ⚠️ (scanned ${minutesSinceGenerated}mins after session started)'
            : 'Attendance marked successfully! ✅',
        isLate: isLate,
      );
    } catch (e) {
      _showResult(false, 'Error: ${e.toString()}', isLate: false);
    }
  }

  Future<void> _simulateScan() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying QR...';
    });
    cameraController.stop();

    try {
      final sessions = await _firestore
          .collection('sessions')
          .where('active', isEqualTo: true)
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      if (sessions.docs.isEmpty) {
        _showResult(false, 'No active session found! Ask admin to generate a QR.',
            isLate: false);
        return;
      }

      final session = sessions.docs.first;
      final sessionId = session['sessionId'];
      final expiresAt = (session['expiresAt'] as Timestamp).toDate();
      final generatedAt = (session['generatedAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        _showResult(false, 'QR code has expired!', isLate: false);
        return;
      }

      final minutesSinceGenerated =
          DateTime.now().difference(generatedAt).inMinutes;
      final bool isLate = minutesSinceGenerated >= _lateThresholdMinutes;

      final existing = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        _showResult(false, 'Attendance already marked for this session!',
            isLate: false);
        return;
      }

      final status = isLate ? 'late' : 'present';

      await _firestore.collection('attendance').add({
        'userId': _auth.currentUser!.uid,
        'sessionId': sessionId,
        'timestamp': Timestamp.now(),
        'locationId': 'default',
        'method': 'qr_demo',
        'latitude': _fenceLat,
        'longitude': _fenceLng,
        'distance': 0.0,
        'status': status,
      });

      _showResult(
        true,
        isLate
            ? 'Marked as Late ⚠️ (scanned ${minutesSinceGenerated}mins after session started)'
            : 'Attendance marked successfully! ✅',
        isLate: isLate,
      );
    } catch (e) {
      _showResult(false, 'Error: ${e.toString()}', isLate: false);
    }
  }

  void _showResult(bool success, String message, {required bool isLate}) {
    final color = !success
        ? Colors.red
        : isLate
        ? Colors.orange
        : Colors.green;
    final icon = !success
        ? Icons.cancel
        : isLate
        ? Icons.access_time
        : Icons.check_circle;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 64),
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Point camera at QR code';
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onQRDetected,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4FC3F7), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 130,
            left: 32,
            right: 32,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _simulateScan,
              icon: const Icon(Icons.play_circle, color: Colors.white),
              label: const Text(
                'Demo: Auto-Mark Attendance',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
              ),
            ),
        ],
      ),
    );
  }
}