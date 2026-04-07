import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'violation_management.dart';
import 'student_records.dart';
import 'incident_reports.dart';
import 'notifications.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3);

  @override
  void initState() {
    super.initState();
    // 1. START BOTH LISTENERS
    _startIncidentListener();
    _startAccountListener();
  }

  // LISTENER A: For New Incident Reports
  void _startIncidentListener() {
    FirebaseFirestore.instance
        .collection('violations')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _showNotificationSnackBar(
                "🚨 New Incident Report from ${change.doc['studentName']}",
                Colors.brown.shade800,
              );
            }
          }
        });
  }

  // LISTENER B: For New Pending Accounts (The one you asked for!)
  void _startAccountListener() {
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _showNotificationSnackBar(
                "👤 New Student Registration: ${change.doc['fullName']}",
                Colors.blueGrey.shade800,
              );
            }
          }
        });
  }

  void _showNotificationSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Students record';
      case 2:
        return 'Violations';
      case 3:
        return 'Incident Reports';
      case 4:
        return 'Handbook CMS';
      default:
        return 'Admin Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDashboardTab(),
      StudentRecords(),
      ViolationManagement(),
      AdminIncidentReports(),
      const Center(child: Text("Handbook CMS Module (Coming Soon)")),
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
              _getAppBarTitle(),
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
        actions: [
          // NOTIFICATION BELL (Combines both Pending Reports and Pending Accounts)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('violations')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, violationSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'student')
                    .where('isApproved', isEqualTo: false)
                    .snapshots(),
                builder: (context, userSnap) {
                  int totalPending =
                      (violationSnap.hasData
                          ? violationSnap.data!.docs.length
                          : 0) +
                      (userSnap.hasData ? userSnap.data!.docs.length : 0);

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      icon: Badge(
                        label: Text(totalPending.toString()),
                        isLabelVisible: totalPending > 0,
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 26,
                        ),
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
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: pages[_selectedIndex],
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
        var allUsers = userSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('violations')
              .snapshots(),
          builder: (context, violationSnapshot) {
            if (!violationSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            Map<String, int> dataMap = {
              'Bullying': 0,
              'Vandalism': 0,
              'Cheating': 0,
              'Smoking': 0,
              'Alcohol': 0,
              'Other': 0,
            };
            int verifiedViolationsCount = 0;

            // STATS CALCULATION
            int pendingReports = violationSnapshot.data!.docs
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['status'] == 'pending',
                )
                .length;
            int pendingAccounts = allUsers
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['isApproved'] == false,
                )
                .length;

            for (var doc in violationSnapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              String status = (data['status'] ?? 'pending')
                  .toString()
                  .toLowerCase();
              if (status == 'approved' ||
                  status == 'resolved' ||
                  status == 'cleared') {
                String type = data['type'] ?? 'Other';
                if (dataMap.containsKey(type)) {
                  dataMap[type] = dataMap[type]! + 1;
                } else {
                  dataMap['Other'] = dataMap['Other']! + 1;
                }
                verifiedViolationsCount++;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard(
                        'Total\nStudents',
                        allUsers.length.toString(),
                        Icons.people,
                        Colors.transparent,
                      ),

                      // CARD 2: PENDING ACCOUNTS (Will turn Yellow if > 0)
                      _buildStatCard(
                        'Pending\nAccounts',
                        pendingAccounts.toString(),
                        Icons.person_add_alt_1,
                        pendingAccounts > 0
                            ? Colors.yellow.shade700
                            : Colors.transparent,
                      ),

                      _buildStatCard(
                        'Account\nViolations',
                        verifiedViolationsCount.toString(),
                        Icons.pan_tool,
                        Colors.red.shade700,
                      ),

                      // CARD 4: PENDING REPORTS (Will turn Orange if > 0)
                      _buildStatCard(
                        'New\nReports',
                        pendingReports.toString(),
                        Icons.notification_important,
                        pendingReports > 0 ? Colors.orange : Colors.transparent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Incident reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Verified Violations (Approved/Resolved)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),

                  // PIE CHART
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
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
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 45,
                                  sections: _chartSections(
                                    dataMap,
                                    verifiedViolationsCount,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "$verifiedViolationsCount",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "TOTAL",
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
                        Wrap(
                          spacing: 20,
                          runSpacing: 10,
                          children: dataMap.entries
                              .where((e) => e.value > 0)
                              .map((e) => _buildLegendItem(e.key, e.value))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER WIDGETS (UNCHANGED) ---
  List<PieChartSectionData> _chartSections(Map<String, int> counts, int total) {
    final List<Color> colors = [
      const Color(0xFFBC6C74),
      const Color(0xFF7B8CB4),
      const Color(0xFFE5B075),
      const Color(0xFF8CAF8D),
      const Color(0xFFC4AD6F),
      const Color(0xFF533E85),
    ];
    int i = 0;
    return counts.entries.map((entry) {
      final double val = entry.value.toDouble();
      final double percentage = total > 0 ? (val / total) * 100 : 0;
      return PieChartSectionData(
        color: colors[i++],
        value: val > 0 ? val : 0.001,
        title: val > 0 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(String name, int count) {
    final Map<String, Color> colorMap = {
      'Bullying': const Color(0xFFBC6C74),
      'Vandalism': const Color(0xFF7B8CB4),
      'Cheating': const Color(0xFFE5B075),
      'Smoking': const Color(0xFF8CAF8D),
      'Alcohol': const Color(0xFFC4AD6F),
      'Other': const Color(0xFF533E85),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colorMap[name],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          "$name ($count)",
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
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
        color: const Color(0xFFE8DCC4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
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
                ),
              ),
              Icon(icon, size: 18, color: Colors.black45),
            ],
          ),
          Text(
            count,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _bgColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20),
            color: _darkBrown,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber, size: 40),
                SizedBox(height: 10),
                Text(
                  'DISCIPLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Admin Portal',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.dashboard_outlined, 'Dashboard', 0),
          _drawerItem(Icons.people_outline, 'Students', 1),
          _drawerItem(Icons.warning_amber_rounded, 'Violations', 2),
          _drawerItem(Icons.assignment_outlined, 'Incident reports', 3),
          _drawerItem(Icons.menu_book_outlined, 'Handbook CMS', 4),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBrown,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? _darkBrown : Colors.black54),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? _darkBrown : Colors.black87,
        ),
      ),
      selected: isSelected,
      onTap: () => _onItemTapped(index),
    );
  }
}
