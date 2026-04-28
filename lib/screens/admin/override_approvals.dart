import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverrideApprovals extends StatelessWidget {
  const OverrideApprovals({super.key});

  Future<void> _approve(String docId, String userId) async {
    // 1. Unlock manual attendance for this specific user only
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'manualAllowed': true});

    // 2. Mark the override request as approved
    await FirebaseFirestore.instance
        .collection('overrideRequests')
        .doc(docId)
        .update({'status': 'approved'});
  }

  Future<void> _reject(String docId) async {
    await FirebaseFirestore.instance
        .collection('overrideRequests')
        .doc(docId)
        .update({'status': 'rejected'});
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return const Color(0xFFFFB74D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Override Requests',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('overrideRequests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4FC3F7)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('No override requests yet',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final userId = data['userId'] ?? '';
              final status = data['status'] ?? 'pending';
              final timestamp = (data['timestamp'] as Timestamp).toDate();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _statusColor(status).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['email'] ?? 'Unknown user',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Reason: ${data['reason']}',
                        style: const TextStyle(
                            color: Color(0xFF4FC3F7), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(data['details'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${timestamp.day}/${timestamp.month}/${timestamp.year} '
                          '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),

                    // Show approve/reject only for pending requests
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: userId.isEmpty
                                  ? null
                                  : () => _approve(docId, userId),
                              icon: const Icon(Icons.check,
                                  color: Colors.white, size: 18),
                              label: const Text('Approve',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _reject(docId),
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                              label: const Text('Reject',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Show note when approved so admin knows manual was unlocked
                    if (status == 'approved') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_open,
                                color: Colors.green, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Manual attendance unlocked for this user',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}