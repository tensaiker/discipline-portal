import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Design Colors
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3);
  final Color _cardColor = const Color(0xFFF9F7F2);

  // LOGIC: Auto-fill Student Info when ID is typed
  Future<void> _searchAndFill(String id) async {
    if (id.length < 5) return;
    var res = await FirebaseFirestore.instance
        .collection('users')
        .where('studentID', isEqualTo: id)
        .limit(1)
        .get();

    if (res.docs.isNotEmpty) {
      var d = res.docs.first.data();
      setState(() {
        _nameController.text = d['fullName'] ?? '';
        _courseController.text = d['course'] ?? '';
      });
    }
  }

  // LOGIC: Save Violation (This updates your Dashboard)
  Future<void> _saveViolation() async {
    if (_idController.text.isEmpty || _selectedViolation == null) return;

    // 1. Save to 'violations' (This triggers the Pie Chart and Stat Card)
    await FirebaseFirestore.instance.collection('violations').add({
      'studentID': _idController.text,
      'studentName': _nameController.text,
      'type': _selectedViolation,
      'description': _descController.text,
      'status':
          'approved', // Saving as approved so it counts as a violation immediately
      'date': DateTime.now().toString(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update the student's status in 'users' (Turns their record red)
    var student = await FirebaseFirestore.instance
        .collection('users')
        .where('studentID', isEqualTo: _idController.text)
        .get();

    if (student.docs.isNotEmpty) {
      await student.docs.first.reference.update({
        'status': 'violations',
        'activeViolation': _selectedViolation,
      });
    }

    _resetForm();
  }

  void _resetForm() {
    _idController.clear();
    _nameController.clear();
    _courseController.clear();
    _descController.clear();
    setState(() {
      _selectedViolation = null;
      _view = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _view == 0 ? _buildListView() : _buildFormView(),
    );
  }

  // ==========================================
  // VIEW 1: THE VIOLATION LIST (Matches image_d7da67.png)
  // ==========================================
  Widget _buildListView() {
    return Column(
      children: [
        // Search & Add Header
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

        // Filter Tabs
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

        // Data Table Container
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
                        var name = doc['fullName'].toString().toLowerCase();
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
                  data['fullName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  data['studentID'],
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  data['course'],
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
  // VIEW 2: LOG NEW VIOLATION (Matches your logic)
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
                decoration: _inputDeco("Type ID (e.g. PDM-202...)"),
              ),
              _label("Student Name"),
              TextField(
                controller: _nameController,
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
