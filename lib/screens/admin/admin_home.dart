import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'generate_qr.dart';
import 'override_approvals.dart';
import 'manage_locations.dart';
import 'view_reports.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _manualAllowed = false;
  bool _isTogglingManual = false;

  @override
  void initState() {
    super.initState();
    _fetchManualSetting();
  }

  Future<void> _fetchManualSetting() async {
    final doc = await _firestore.collection('settings').doc('attendance').get();
    if (doc.exists) {
      setState(() {
        _manualAllowed = doc.data()?['manualAllowed'] ?? false;
      });
    }
  }

  Future<void> _toggleManualAttendance(bool value) async {
    setState(() => _isTogglingManual = true);
    await _firestore.collection('settings').doc('attendance').set(
      {'manualAllowed': value},
      SetOptions(merge: true),
    );
    setState(() {
      _manualAllowed = value;
      _isTogglingManual = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Manual attendance enabled for users ✅'
            : 'Manual attendance disabled ❌'),
        backgroundColor: value ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
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
            const Text(
              'Welcome, Admin 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text('What would you like to do?', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),

            // Manual attendance toggle card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_manualAllowed
                      ? const Color(0xFF66BB6A)
                      : Colors.white24)
                      .withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_manualAllowed
                          ? const Color(0xFF66BB6A)
                          : Colors.white24)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.touch_app,
                      color: _manualAllowed
                          ? const Color(0xFF66BB6A)
                          : Colors.white38,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manual Attendance',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _manualAllowed
                              ? 'Users can mark attendance manually'
                              : 'Currently disabled for users',
                          style: TextStyle(
                              color: _manualAllowed
                                  ? const Color(0xFF66BB6A)
                                  : Colors.white54,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _isTogglingManual
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF66BB6A)))
                      : Switch(
                    value: _manualAllowed,
                    onChanged: _toggleManualAttendance,
                    activeColor: const Color(0xFF66BB6A),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white12,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _adminCard(
              context,
              icon: Icons.qr_code,
              title: 'Generate QR Code',
              subtitle: 'Create a time-bound QR for attendance session',
              color: const Color(0xFF4FC3F7),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GenerateQR()),
              ),
            ),
            const SizedBox(height: 16),
            _adminCard(
              context,
              icon: Icons.location_on,
              title: 'Manage Locations',
              subtitle: 'Set and update geo-fence locations',
              color: const Color(0xFF81C784),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageLocations()),
              ),
            ),
            const SizedBox(height: 16),
            _adminCard(
              context,
              icon: Icons.approval,
              title: 'Override Requests',
              subtitle: 'Approve or reject manual attendance requests',
              color: const Color(0xFFFFB74D),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OverrideApprovals()),
              ),
            ),
            const SizedBox(height: 16),
            _adminCard(
              context,
              icon: Icons.bar_chart,
              title: 'View Reports',
              subtitle: 'See attendance analytics and records',
              color: const Color(0xFFCE93D8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewReports()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(BuildContext context,
      {required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}