import 'package:flutter/material.dart';
import 'student_home.dart';
import 'alerts.dart';
import 'report_incident.dart';

class StudentMainWrapper extends StatefulWidget {
  const StudentMainWrapper({super.key});

  @override
  State<StudentMainWrapper> createState() => _StudentMainWrapperState();
}

class _StudentMainWrapperState extends State<StudentMainWrapper> {
  int _currentIndex = 0;
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFF9F7F2);

  @override
  Widget build(BuildContext context) {
    // REMOVED 'const' from StudentAlerts and ReportIncident to support dynamic data
    final List<Widget> screens = [
      const StudentHome(),
      _buildHandbookTab(),
      const StudentAlerts(), // Real-time Firestore stream
      const ReportIncident(), // Dynamic form submission
    ];

    return Scaffold(
      backgroundColor: _bgColor,
      // IndexedStack keeps the screens "alive" in the background so they don't reload every time
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _darkBrown,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Handbook',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            activeIcon: Icon(Icons.warning),
            label: 'Report',
          ),
        ],
      ),
    );
  }

  Widget _buildHandbookTab() {
    return const Center(
      child: Text(
        "Handbook Screen\n(Coming Soon)",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }
}
