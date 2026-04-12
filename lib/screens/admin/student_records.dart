import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentRecords extends StatefulWidget {
  const StudentRecords({super.key});

  @override
  State<StudentRecords> createState() => _StudentRecordsState();
}

class _StudentRecordsState extends State<StudentRecords> {
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);
  final Color _bgColor = const Color(0xFFF9F7F2);

  // LOGIC: Approve a Pending Student
  Future<void> _approveStudent(String docId, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isApproved': true,
        'isActive': true,
        'status': 'cleared', // Moves them to the Active/Clear tab
      });
      _showSnackBar("$name has been approved and activated!", Colors.green);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  // LOGIC: Toggle between Active and Deactivated
  Future<void> _toggleAccount(String docId, bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isActive': !currentlyActive,
        'status': !currentlyActive ? 'cleared' : 'deactivated',
      });
      _showSnackBar(
        currentlyActive ? "Account Deactivated" : "Account Reactivated",
        currentlyActive ? Colors.orange : Colors.green,
      );
    } catch (e) {
      _showSnackBar("Error updating status: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Changed to 3 for better organization
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              labelColor: _darkBrown,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _yellow,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: "Active"),
                Tab(text: "Pending"),
                Tab(text: "Inactive"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildFilteredList('active'), // isActive == true
            _buildFilteredList('pending'), // status == 'Pending'
            _buildFilteredList(
              'inactive',
            ), // status == 'Disabled' or 'deactivated'
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredList(String filterType) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student');

    // Apply specific filters based on Tab
    if (filterType == 'active') {
      query = query.where('isActive', isEqualTo: true);
    } else if (filterType == 'pending') {
      query = query.where('status', isEqualTo: 'Pending');
    } else {
      query = query
          .where('isActive', isEqualTo: false)
          .where('status', whereIn: ['Disabled', 'deactivated']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyState(filterType);

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildStudentCard(doc.id, data, filterType);
          },
        );
      },
    );
  }

  Widget _buildStudentCard(
    String docId,
    Map<String, dynamic> data,
    String type,
  ) {
    bool isActive = data['isActive'] ?? false;
    String status = data['status'] ?? '';

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
              "ID: ${data['studentID']}",
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              "Course: ${data['course']}",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: _buildActionButton(docId, data, type),
      ),
    );
  }

  Widget _buildActionButton(
    String docId,
    Map<String, dynamic> data,
    String type,
  ) {
    if (type == 'pending') {
      return ElevatedButton(
        onPressed: () => _approveStudent(docId, data['fullName']),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          elevation: 0,
        ),
        child: const Text(
          "Approve",
          style: TextStyle(fontSize: 11, color: Colors.white),
        ),
      );
    }

    bool isActive = data['isActive'] ?? false;
    // Show Toggle button for Active and Inactive tabs
    return TextButton(
      onPressed: () => _toggleAccount(docId, isActive),
      child: Text(
        isActive ? "Deactivate" : "Activate",
        style: TextStyle(
          color: isActive ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 50,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 10),
          Text(
            "No $type students found.",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
