import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewReports extends StatefulWidget {
  const ViewReports({super.key});

  @override
  State<ViewReports> createState() => _ViewReportsState();
}

class _ViewReportsState extends State<ViewReports> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Cache userId -> name so we don't fetch same user repeatedly
  final Map<String, String> _userNameCache = {};

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final name = doc.data()?['name'] ?? doc.data()?['email'] ?? 'Unknown';
        _userNameCache[userId] = name;
        return name;
      }
    } catch (_) {}
    _userNameCache[userId] = 'Unknown';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Attendance Reports',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No attendance records yet',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              // Summary bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total', docs.length.toString(),
                        const Color(0xFF4FC3F7)),
                    _statItem(
                        'QR',
                        docs
                            .where((d) =>
                        (d.data() as Map)['method'] == 'qr' ||
                            (d.data() as Map)['method'] == 'qr_demo')
                            .length
                            .toString(),
                        const Color(0xFF81C784)),
                    _statItem(
                        'Manual',
                        docs
                            .where((d) =>
                        (d.data() as Map)['method'] == 'manual' ||
                            (d.data() as Map)['method'] == 'override')
                            .length
                            .toString(),
                        const Color(0xFFFFB74D)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                    docs[index].data() as Map<String, dynamic>;
                    final timestamp =
                    (data['timestamp'] as Timestamp).toDate();
                    final method = data['method'] ?? 'qr';
                    final userId = data['userId'] ?? '';

                    Color color;
                    IconData icon;
                    if (method == 'qr' || method == 'qr_demo') {
                      color = const Color(0xFF81C784);
                      icon = Icons.qr_code;
                    } else if (method == 'manual') {
                      color = const Color(0xFF4FC3F7);
                      icon = Icons.touch_app;
                    } else {
                      color = const Color(0xFFFFB74D);
                      icon = Icons.edit_note;
                    }

                    return FutureBuilder<String>(
                      future: _getUserName(userId),
                      builder: (context, nameSnapshot) {
                        final name = nameSnapshot.data ?? '...';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(12),
                            border:
                            Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${timestamp.day}/${timestamp.month}/${timestamp.year}  ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  method.toUpperCase(),
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}