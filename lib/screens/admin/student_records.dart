import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// ✅ Universal import for Web/Mobile safety
import 'package:universal_html/html.dart' as html;

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

  final List<String> _courseFilters = ["All", ..._pdmCourseMap.keys];

  // ✅ Your Live Ngrok URL
  final String _apiBaseUrl =
      "https://railway-hurray-uncurled.ngrok-free.dev/pdm_admin";

  // --- HELPERS ---

  String _getCourseFullName(String? input) {
    if (input == null || input.isEmpty) return "N/A";
    String key = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return _pdmCourseMap[key] ?? input;
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- DATABASE ACTIONS ---

  Future<void> _syncWithMySQL(String studentID, String status) async {
    try {
      await http.post(
        Uri.parse("$_apiBaseUrl/activate_student.php"),
        headers: {
          "ngrok-skip-browser-warning": "true",
          "Accept": "application/json",
        },
        body: {"student_id": studentID, "status": status},
      );
    } catch (e) {
      debugPrint("❌ MySQL Error: $e");
    }
  }

  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        setState(() => _isSyncing = true);
        var request = http.MultipartRequest(
          'POST',
          Uri.parse("$_apiBaseUrl/import_csv.php"),
        );
        request.headers.addAll({"ngrok-skip-browser-warning": "true"});

        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              result.files.first.bytes!,
              filename: result.files.first.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', result.files.first.path!),
          );
        }
        request.fields['import'] = 'true';
        await request.send();
        _showSnackBar("Master List updated!", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Import Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _toggleAccount(
    String docId,
    String studentID,
    bool currentlyActive,
  ) async {
    try {
      bool newStatus = !currentlyActive;
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isActive': newStatus,
        'status': newStatus ? 'cleared' : 'deactivated',
      });

      await _syncWithMySQL(studentID, newStatus ? 'Active' : 'Disabled');

      _showSnackBar(
        currentlyActive ? "Deactivated" : "Activated",
        currentlyActive ? Colors.orange : Colors.green,
      );
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            "Student Records",
            style: TextStyle(
              color: _darkBrown,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            _isSyncing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.file_upload_outlined, color: _darkBrown),
                    onPressed: _importCSV,
                  ),
          ],
          bottom: TabBar(
            labelColor: _darkBrown,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _yellow,
            tabs: const [
              Tab(text: "Active"),
              Tab(text: "Pending"),
              Tab(text: "Inactive"),
            ],
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
      ),
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
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search Name or ID...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCourse,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  items: _courseFilters
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c == "All" ? "All Courses" : _getCourseFullName(c),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
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
    return StreamBuilder<QuerySnapshot>(
      // 1. Get ALL users to ensure we don't miss those 7 "ghost" students
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;

          // 2. Hide Admin and non-students
          String role = (data['role'] ?? "").toString().toLowerCase();
          if (role == 'admin') return false;

          bool active = data['isActive'] ?? false;
          String status = (data['status'] ?? "").toString().toLowerCase();

          // 3. Tab Filtering
          if (filterType == 'active') {
            if (!active) return false;
          } else if (filterType == 'pending') {
            // "Pending" are those who are NOT active AND haven't been manually disabled
            if (active || status == 'deactivated' || status == 'disabled')
              return false;
          } else {
            // "Inactive" are those who are specifically deactivated
            if (active || (status != 'deactivated' && status != 'disabled'))
              return false;
          }

          // 4. Search and Course Filter
          String name = (data['fullName'] ?? "").toString().toLowerCase();
          String id = (data['studentID'] ?? "").toString().toLowerCase();
          String dbCourse = (data['course'] ?? "")
              .toString()
              .toUpperCase()
              .trim();

          bool matchesSearch =
              name.contains(_searchQuery) || id.contains(_searchQuery);
          bool matchesCourse =
              _selectedCourse == "All" ||
              dbCourse == _selectedCourse.toUpperCase();

          return matchesSearch && matchesCourse;
        }).toList();

        if (docs.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("No records found."),
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildStudentCard(
            docs[index].id,
            docs[index].data() as Map<String, dynamic>,
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(String docId, Map<String, dynamic> data) {
    bool isActive = data['isActive'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _darkBrown.withOpacity(0.1),
          child: Icon(Icons.person, color: _darkBrown),
        ),
        title: Text(
          data['fullName'] ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ID: ${data['studentID'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              _getCourseFullName(data['course']),
              style: TextStyle(
                fontSize: 10,
                color: _darkBrown.withOpacity(0.8),
              ),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _toggleAccount(docId, data['studentID'], isActive),
          child: Text(
            isActive ? "Deactivate" : "Activate",
            style: TextStyle(
              color: isActive ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
