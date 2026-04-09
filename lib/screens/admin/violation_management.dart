import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViolationManagement extends StatefulWidget {
  const ViolationManagement({super.key});

  @override
  State<ViolationManagement> createState() => _ViolationManagementState();
}

class _ViolationManagementState extends State<ViolationManagement> {
  int _view = 0; // 0 = List View, 1 = Add Form
  String _activeTab = "All Students";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Form Controllers
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _courseController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedViolation;

  // Background Data for Database
  String? _targetStudentUid;
  String? _gender;

  // Design Colors
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3);
  final Color _cardColor = const Color(0xFFF9F7F2);

  // LOGIC: Auto-fill Student Info when ID is typed
  Future<void> _searchAndFill(String id) async {
    // Search when the ID reaches the standard length (e.g., PDM-2023-000000)
    if (id.length < 15) return;

    var res = await FirebaseFirestore.instance
        .collection('users')
        .where('studentID', isEqualTo: id)
        .limit(1)
        .get();

    if (res.docs.isNotEmpty) {
      var d = res.docs.first.data();
      setState(() {
        // Auto-fill visible fields
        _nameController.text = d['fullName'] ?? '';
        _courseController.text = d['course'] ?? ''; // AUTO-FILL COURSE

        // Save background data for saving
        _targetStudentUid = d['uid'];
        _gender = d['sex'];
      });
    } else {
      // Clear if not found
      setState(() {
        _nameController.clear();
        _courseController.clear();
        _targetStudentUid = null;
        _gender = null;
      });
    }
  }

  // LOGIC: Save Violation (Updates both Admin and Student Dashboards)
  Future<void> _saveViolation() async {
    if (_idController.text.isEmpty ||
        _selectedViolation == null ||
        _targetStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Student ID")),
      );
      return;
    }

    try {
      // 1. Save to 'violations' collection
      await FirebaseFirestore.instance.collection('violations').add({
        'studentUid': _targetStudentUid,
        'studentID': _idController.text.trim(),
        'studentName': _nameController.text,
        'course': _courseController.text, // SAVING THE COURSE
        'gender': _gender ?? "N/A",
        'type': _selectedViolation,
        'description': _descController.text.trim(),
        'status': 'approved',
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateFormat('MMMM d, yyyy').format(DateTime.now()),
        'reporterUid': 'ADMIN_LOG',
      });

      // 2. Update student status in 'users' collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetStudentUid)
          .update({
            'status': 'violations',
            'activeViolation': _selectedViolation,
          });

      _showSuccessSnackBar("Violation logged and student notified!");
      _resetForm();
    } catch (e) {
      print("Error saving violation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _resetForm() {
    _idController.clear();
    _nameController.clear();
    _courseController.clear();
    _descController.clear();
    setState(() {
      _selectedViolation = null;
      _targetStudentUid = null;
      _gender = null;
      _view = 0;
    });
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _view == 0 ? _buildListView() : _buildFormView(),
    );
  }

  // ==========================================
  // VIEW 1: THE VIOLATION LIST
  // ==========================================
  Widget _buildListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: "Search",
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () => setState(() => _view = 1),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _darkBrown,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      Text(
                        " Add",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: ["All Students", "With Violations", "Clear Students"].map(
              (tab) {
                bool isActive = _activeTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _activeTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? _darkBrown : const Color(0xFFD2C1AF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ),

        const SizedBox(height: 15),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                _buildTableHeader(),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'student')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      var docs = snapshot.data!.docs.where((doc) {
                        var name = (doc['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        var status = doc['status'] ?? 'cleared';
                        bool matchesSearch = name.contains(_searchQuery);
                        bool matchesTab = true;
                        if (_activeTab == "With Violations")
                          matchesTab = status == "violations";
                        if (_activeTab == "Clear Students")
                          matchesTab = status == "cleared";
                        return matchesSearch && matchesTab;
                      }).toList();

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) => _buildStudentRow(docs[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "Student Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Violation",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Action",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    bool hasViolation = data['status'] == 'violations';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['fullName'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  data['studentID'] ?? 'N/A',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  data['course'] ?? 'N/A',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              hasViolation ? (data['activeViolation'] ?? 'Active') : 'None',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: hasViolation
                  ? ElevatedButton(
                      onPressed: () => doc.reference.update({
                        'status': 'cleared',
                        'activeViolation': FieldValue.delete(),
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8DBB52),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        "Clear",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: LOG NEW VIOLATION (UPDATED WITH COURSE FIELD)
  // ==========================================
  Widget _buildFormView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Log New Violation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _view = 0),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _label("Student ID"),
              TextField(
                controller: _idController,
                onChanged: _searchAndFill,
                decoration: _inputDeco("Type ID (e.g. PDM-2023-000000)"),
              ),

              _label("Student Name"),
              TextField(
                controller: _nameController,
                readOnly: true,
                decoration: _inputDeco("Auto-filled"),
              ),

              // NEW COURSE FIELD ADDED HERE
              _label("Course"),
              TextField(
                controller: _courseController,
                readOnly: true,
                decoration: _inputDeco("Auto-filled"),
              ),

              _label("Violation Type"),
              DropdownButtonFormField<String>(
                value: _selectedViolation,
                decoration: _inputDeco("Select"),
                items:
                    ["Bullying", "Smoking", "Cheating", "Vandalism", "Alcohol"]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => _selectedViolation = v),
              ),
              _label("Description"),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDeco("Details..."),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveViolation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Save Violation",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 15, bottom: 5),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );

  InputDecoration _inputDeco(String h) => InputDecoration(
    hintText: h,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
  );
}
