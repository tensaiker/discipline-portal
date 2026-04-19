import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'violation_management.dart';
import 'student_records.dart';
import 'incident_reports.dart';
import 'notifications.dart';
import 'handbook_cms.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int _totalMasterStudents = 0;
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3);
  final Color _cardColor = const Color(0xFFE8DCC4);

  final String _apiBaseUrl =
      "https://railway-hurray-uncurled.ngrok-free.dev/pdm_admin";

  @override
  void initState() {
    super.initState();
    _fetchMySQLStats();
  }

  Future<void> _fetchMySQLStats() async {
    try {
      final response = await http
          .get(Uri.parse("$_apiBaseUrl/get_stats.php"))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(
            () => _totalMasterStudents = int.parse(data['total'].toString()),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching MySQL stats: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboardTab(),
      const StudentRecords(),
      const ViolationManagement(),
      const AdminIncidentReports(),
      const HandbookCMS(),
    ];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _darkBrown,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedIndex == 0
                  ? 'Dashboard'
                  : _selectedIndex == 1
                  ? 'Students record'
                  : _selectedIndex == 2
                  ? 'Violations'
                  : _selectedIndex == 3
                  ? 'Incident reports'
                  : 'Handbook CMS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Admin Portal',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [_buildNotificationBell()],
      ),
      drawer: _buildDrawer(),
      body: pages[_selectedIndex],
    );
  }

  // ✅ FIXED NOTIFICATION BELL: Accurate counts for both reports and signups
  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('violations')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, violationSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('isActive', isEqualTo: false)
              .snapshots(),
          builder: (context, userSnap) {
            int total =
                (violationSnap.hasData ? violationSnap.data!.docs.length : 0) +
                (userSnap.hasData ? userSnap.data!.docs.length : 0);
            return Padding(
              padding: const EdgeInsets.only(right: 15, top: 5),
              child: IconButton(
                icon: Badge(
                  label: Text(total.toString()),
                  isLabelVisible: total > 0,
                  child: const Icon(Icons.notifications_none_rounded, size: 28),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminNotifications(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('violations')
              .snapshots(),
          builder: (context, violationSnapshot) {
            if (!violationSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            int pendingReports = violationSnapshot.data!.docs
                .where((d) => d['status'] == 'pending')
                .length;
            int pendingAccounts = userSnapshot.data!.docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              return (data['isActive'] == false) &&
                  (data['status'] != 'deactivated');
            }).length;

            int verifiedTotal = violationSnapshot.data!.docs
                .where(
                  (d) => [
                    'approved',
                    'resolved',
                    'cleared',
                  ].contains(d['status'].toString().toLowerCase()),
                )
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard(
                        'Master List\nStudents',
                        _totalMasterStudents.toString(),
                        Icons.storage,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Pending\nAccounts',
                        pendingAccounts.toString(),
                        Icons.person_add_alt_1,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Account\nViolations',
                        verifiedTotal.toString(),
                        Icons.front_hand_rounded,
                        Colors.red,
                      ),
                      _buildStatCard(
                        'New\nReports',
                        pendingReports.toString(),
                        Icons.notifications_active,
                        Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Incident reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Verified Violations (Approved/Resolved)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  _buildPieChart(violationSnapshot.data!.docs, verifiedTotal),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              Icon(icon, size: 18, color: Colors.black45),
            ],
          ),
          Text(
            count,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<QueryDocumentSnapshot> docs, int total) {
    Map<String, double> dataMap = {
      'Vandalism': 0,
      'Cheating': 0,
      'Smoking': 0,
      'Alcohol': 0,
      'Other': 0,
    };

    for (var doc in docs) {
      String status = (doc['status'] ?? '').toString().toLowerCase();
      if (['approved', 'resolved', 'cleared'].contains(status)) {
        String type = doc['type'] ?? 'Other';
        if (dataMap.containsKey(type)) {
          dataMap[type] = dataMap[type]! + 1;
        } else {
          dataMap['Other'] = dataMap['Other']! + 1;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 45,
                    sectionsSpace: 2,
                    sections: _buildSections(dataMap, total),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(dataMap),
        ],
      ),
    );
  }

  // ✅ PERCENTAGE LOGIC: Calculates and shows % inside the slice
  List<PieChartSectionData> _buildSections(
    Map<String, double> dataMap,
    int total,
  ) {
    final List<Color> colors = [
      const Color(0xFF7B8CB4),
      const Color(0xFFE5B075),
      const Color(0xFF8CAF8D),
      const Color(0xFFC4AD6F),
      const Color(0xFF533E85),
    ];
    int i = 0;

    return dataMap.entries.map((entry) {
      final isSelected = entry.value > 0;
      final double percentage = total > 0 ? (entry.value / total) * 100 : 0;

      return PieChartSectionData(
        color: colors[i++ % colors.length],
        value: entry.value > 0
            ? entry.value
            : 0.001, // Small value to prevent crash if 0
        title: isSelected
            ? '${percentage.toStringAsFixed(0)}%'
            : '', // Shows percentage
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> dataMap) {
    final List<Color> colors = [
      const Color(0xFF7B8CB4),
      const Color(0xFFE5B075),
      const Color(0xFF8CAF8D),
      const Color(0xFFC4AD6F),
      const Color(0xFF533E85),
    ];
    int i = 0;
    return Wrap(
      spacing: 15,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: dataMap.entries.where((e) => e.value > 0).map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors[i++ % colors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${e.key} (${e.value.toInt()})',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _bgColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _darkBrown),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.shield, color: Color(0xFF513C2C), size: 35),
            ),
            accountName: const Text(
              "PDM Admin",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: const Text(
              "Pambayang Dalubhasaan ng Marilao",
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          _drawerItem(Icons.grid_view_rounded, 'Dashboard', 0),
          _drawerItem(Icons.people_alt_outlined, 'Students', 1),
          _drawerItem(Icons.warning_amber_rounded, 'Violations', 2),
          _drawerItem(Icons.assignment_outlined, 'Incident reports', 3),
          _drawerItem(Icons.menu_book_rounded, 'Handbook CMS', 4),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => FirebaseAuth.instance.signOut().then(
                  (_) => Navigator.pushReplacementNamed(context, '/login'),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index ? _darkBrown : Colors.black54,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: _selectedIndex == index ? _darkBrown : Colors.black87,
          fontWeight: _selectedIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      onTap: () => _onItemTapped(index),
    );
  }
}
