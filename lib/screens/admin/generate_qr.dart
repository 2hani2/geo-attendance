import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class GenerateQR extends StatefulWidget {
  const GenerateQR({super.key});

  @override
  State<GenerateQR> createState() => _GenerateQRState();
}

class _GenerateQRState extends State<GenerateQR> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _qrData;
  String? _sessionId;
  DateTime? _expiresAt;
  bool _isLoading = false;
  int _validMinutes = 10;

  Future<void> _generateQR() async {
    setState(() => _isLoading = true);

    final sessionId = const Uuid().v4();
    final now = DateTime.now();
    final expires = now.add(Duration(minutes: _validMinutes));

    final qrPayload = {
      'session_id': sessionId,
      'location_id': 'default',
      'generated_at': now.toIso8601String(),
      'expires_at': expires.toIso8601String(),
    };

    // Save session to Firestore
    await _firestore.collection('sessions').doc(sessionId).set({
      'sessionId': sessionId,
      'locationId': 'default',
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expires),
      'active': true,
    });

    setState(() {
      _qrData = jsonEncode(qrPayload);
      _sessionId = sessionId;
      _expiresAt = expires;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Generate QR Code', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Valid duration selector
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR Valid Duration',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [5, 10, 15, 30].map((mins) {
                      return GestureDetector(
                        onTap: () => setState(() => _validMinutes = mins),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _validMinutes == mins
                                ? const Color(0xFF4FC3F7)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${mins}m',
                              style: TextStyle(
                                  color: _validMinutes == mins ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR Display
            if (_qrData != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Expires at: ${_expiresAt!.hour}:${_expiresAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Session: ${_sessionId!.substring(0, 8)}...',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ] else
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No QR generated yet', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateQR,
                icon: const Icon(Icons.qr_code, color: Colors.white),
                label: Text(
                  _isLoading ? 'Generating...' : 'Generate New QR',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}