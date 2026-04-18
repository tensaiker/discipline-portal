import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

// ✅ Web-safe import for downloads
import 'dart:html' as html if (dart.library.io) 'package:discipline/services/stub_html.dart';

// --- GLOBAL COURSE DATA ---
const Map<String, String> _pdmCourseMap = {
  'BSENTREP': 'BS Entrepreneurship',
  'BSIT': 'BS Information Technology',
  'BSCS': 'BS Computer Science',
  'BSHM': 'BS Hospitality Management',
  'BSTM': 'BS Tourism Management',
  'BSOA': 'BS Office Administration',
  'BECED': 'BS Early Childhood Education',
  'BTLED': 'BT Livelihood Education',
};

class StudentRecords extends StatefulWidget {
  const StudentRecords({super.key});

  @override
  State<StudentRecords> createState() => _StudentRecordsState();
}

class _StudentRecordsState extends State<StudentRecords> {
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);
  final Color _bgColor = const Color(0xFFF9F7F2);

  bool _isSyncing = false;
  String _searchQuery = "";
  String _selectedCourse = "All";

  final String _apiBaseUrl = kIsWeb 
      ? "http://localhost/pdm_admin" 
      : "http://192.168.100.72/pdm_admin";

  // --- HELPERS ---
  String _getCourseFullName(String? input) {
    if (input == null || input.isEmpty) return "N/A";
    String key = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return _pdmCourseMap[key] ?? input; 
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // --- LOGIC: ACTIONS ---
  Future<void> _syncWithMySQL(String studentID, String status) async {
    try {
      await http.post(Uri.parse("$_apiBaseUrl/activate_student.php"), 
      body: {"student_id": studentID, "status": status});
    } catch (e) { print("MySQL Sync Error: $e"); }
  }

  Future<void> _approveStudent(String docId, String name, String studentID) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isApproved': true, 'isActive': true, 'status': 'cleared'
      });
      await _syncWithMySQL(studentID, 'Active');
      _showSnackBar("$name approved!", Colors.green);
    } catch (e) { _showSnackBar("Error: $e", Colors.red); }
  }

  Future<void> _toggleAccount(String docId, String studentID, bool currentlyActive) async {
    try {
      bool newStatus = !currentlyActive;
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isActive': newStatus, 
        'status': newStatus ? 'cleared' : 'deactivated'
      });
      await _syncWithMySQL(studentID, newStatus ? 'Active' : 'Disabled');
      _showSnackBar(currentlyActive ? "Deactivated" : "Activated", 
      currentlyActive ? Colors.orange : Colors.green);
    } catch (e) { _showSnackBar("Error: $e", Colors.red); }
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: _bgColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text("Student Records", style: TextStyle(color: _darkBrown, fontSize: 18, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(icon: Icon(Icons.download_outlined, color: _darkBrown), 
              onPressed: () {
                int tabIndex = DefaultTabController.of(context).index;
                // Add export logic here if needed
              }),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: TabBar(
                labelColor: _darkBrown,
                indicatorColor: _yellow,
                tabs: const [Tab(text: "Active"), Tab(text: "Pending"), Tab(text: "Inactive")],
              ),
            ),
          ),
          body: Column(
            children: [
              _buildSearchAndFilter(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFilteredList('active'),
                    _buildFilteredList('pending'),
                    _buildFilteredList('inactive'),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search Name or ID...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCourse,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
                  items: ["All", ..._pdmCourseMap.keys].map((c) => DropdownMenuItem(
                    value: c, 
                    child: Text(c == "All" ? "All Courses" : _getCourseFullName(c), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCourse = val!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredList(String filterType) {
    Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student');
    
    if (filterType == 'active') query = query.where('isActive', isEqualTo: true);
    else if (filterType == 'pending') query = query.where('status', isEqualTo: 'Pending');
    else query = query.where('isActive', isEqualTo: false).where('status', whereIn: ['Disabled', 'deactivated', 'disabled']);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['fullName'] ?? "").toString().toLowerCase();
          String id = (data['studentID'] ?? "").toString().toLowerCase();
          String dbCourse = (data['course'] ?? "").toString().toUpperCase();

          bool matchesSearch = name.contains(_searchQuery) || id.contains(_searchQuery);
          bool matchesCourse = _selectedCourse == "All" || 
                               dbCourse == _selectedCourse.toUpperCase() ||
                               _getCourseFullName(dbCourse).toUpperCase().contains(_selectedCourse.toUpperCase());

          return matchesSearch && matchesCourse;
        }).toList();

        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No records found.")));

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var docId = docs[index].id;
            var data = docs[index].data() as Map<String, dynamic>;
            return _buildStudentCard(docId, data, filterType);
          },
        );
      },
    );
  }

  Widget _buildStudentCard(String docId, Map<String, dynamic> data, String type) {
    bool isActive = data['isActive'] ?? false;
    String studentID = data['studentID'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _darkBrown.withOpacity(0.1), child: Icon(Icons.person, color: _darkBrown)),
        title: Text(data['fullName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: $studentID", style: const TextStyle(fontSize: 11)),
            Text(_getCourseFullName(data['course']), style: TextStyle(fontSize: 10, color: _darkBrown.withOpacity(0.8))),
          ],
        ),
        trailing: type == 'pending' 
          ? ElevatedButton(
              onPressed: () => _approveStudent(docId, data['fullName'], studentID),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, elevation: 0),
              child: const Text("Approve", style: TextStyle(fontSize: 11, color: Colors.white)),
            )
          : TextButton(
              onPressed: () => _toggleAccount(docId, studentID, isActive),
              child: Text(isActive ? "Deactivate" : "Activate", 
                style: TextStyle(color: isActive ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
      ),
    );
  }
}