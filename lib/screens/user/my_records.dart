import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyRecords extends StatefulWidget {
  const MyRecords({super.key});

  @override
  State<MyRecords> createState() => _MyRecordsState();
}

class _MyRecordsState extends State<MyRecords>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('My Records', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4FC3F7),
          labelColor: const Color(0xFF4FC3F7),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
            Tab(icon: Icon(Icons.list), text: 'List'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
          }

          final docs = snapshot.data?.docs ?? [];

          // Build a map of date -> status
          final Map<String, String> attendanceMap = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final dateKey =
                '${timestamp.year}-${timestamp.month}-${timestamp.day}';
            final status = data['status'] ?? 'present';
            // Keep worst status if duplicate (late > present)
            if (!attendanceMap.containsKey(dateKey) ||
                status == 'late') {
              attendanceMap[dateKey] = status;
            }
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCalendar(attendanceMap),
              _buildList(docs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar(Map<String, String> attendanceMap) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday
    final today = DateTime.now();

    // Count stats for this month
    int presentCount = 0;
    int lateCount = 0;
    for (int d = 1; d <= lastDay.day; d++) {
      final key =
          '${_focusedMonth.year}-${_focusedMonth.month}-$d';
      if (attendanceMap[key] == 'present') presentCount++;
      if (attendanceMap[key] == 'late') lateCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1);
                  }),
                ),
                Text(
                  '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => setState(() {
                    _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month + 1);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _calStat('Present', presentCount, Colors.green),
              const SizedBox(width: 8),
              _calStat('Late', lateCount, Colors.orange),
              const SizedBox(width: 8),
              _calStat(
                  'Absent',
                  lastDay.day - presentCount - lateCount,
                  Colors.red),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Day headers
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 8),

                // Day cells
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: startWeekday + lastDay.day,
                  itemBuilder: (context, index) {
                    if (index < startWeekday) {
                      return const SizedBox();
                    }
                    final day = index - startWeekday + 1;
                    final dateKey =
                        '${_focusedMonth.year}-${_focusedMonth.month}-$day';
                    final status = attendanceMap[dateKey];
                    final isToday = today.year == _focusedMonth.year &&
                        today.month == _focusedMonth.month &&
                        today.day == day;
                    final isFuture = DateTime(_focusedMonth.year,
                        _focusedMonth.month, day)
                        .isAfter(today);

                    Color bgColor;
                    Color textColor;

                    if (isFuture) {
                      bgColor = Colors.transparent;
                      textColor = Colors.white24;
                    } else if (status == 'present') {
                      bgColor = Colors.green.withOpacity(0.3);
                      textColor = Colors.green;
                    } else if (status == 'late') {
                      bgColor = Colors.orange.withOpacity(0.3);
                      textColor = Colors.orange;
                    } else {
                      bgColor = Colors.red.withOpacity(0.15);
                      textColor = Colors.red.shade300;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(
                            color: const Color(0xFF4FC3F7), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(Colors.green, 'Present'),
              const SizedBox(width: 16),
              _legendItem(Colors.orange, 'Late'),
              const SizedBox(width: 16),
              _legendItem(Colors.red.shade300, 'Absent'),
              const SizedBox(width: 16),
              _legendItem(const Color(0xFF4FC3F7), 'Today'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No attendance records yet',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final method = data['method'] ?? 'qr';
        final status = data['status'] ?? 'present';

        Color color;
        IconData icon;
        String statusLabel;

        if (status == 'late') {
          color = Colors.orange;
          icon = Icons.access_time;
          statusLabel = 'Late';
        } else if (method == 'qr' || method == 'qr_demo') {
          color = const Color(0xFF81C784);
          icon = Icons.qr_code;
          statusLabel = 'QR Scan';
        } else if (method == 'manual') {
          color = const Color(0xFF4FC3F7);
          icon = Icons.touch_app;
          statusLabel = 'Manual';
        } else {
          color = const Color(0xFFFFB74D);
          icon = Icons.edit_note;
          statusLabel = 'Override';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _calStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}