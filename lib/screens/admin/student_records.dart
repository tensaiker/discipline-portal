import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRecords extends StatefulWidget {
  const StudentRecords({super.key});

  @override
  State<StudentRecords> createState() => _StudentRecordsState();
}

class _StudentRecordsState extends State<StudentRecords> {
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFF9F7F2);

  // FUNCTION: Logic to move a student from Pending to Approved
  Future<void> _approveStudent(String docId, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'isApproved': true, // This changes the account status in Firestore
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$name has been approved!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error approving student: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              labelColor: _darkBrown,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _darkBrown,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: "Active Students"),
                Tab(text: "Pending Approval"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudentList(true), // Show Approved
            _buildStudentList(false), // Show Pending
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(bool showApproved) {
    return StreamBuilder<QuerySnapshot>(
      // Filter by role AND the approval status
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('isApproved', isEqualTo: showApproved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  showApproved
                      ? "No active students yet."
                      : "No pending approvals.",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var students = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: students.length,
          itemBuilder: (context, index) {
            var data = students[index].data() as Map<String, dynamic>;
            String docId = students[index].id;
            String fullName = data['fullName'] ?? "Unnamed Student";
            String studentID = data['studentID'] ?? "No ID Provided";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: _darkBrown.withOpacity(0.1),
                  child: Icon(Icons.person, color: _darkBrown),
                ),
                title: Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  "Student ID: $studentID",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: showApproved
                    ? const Icon(Icons.verified, color: Colors.blue, size: 20)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _approveStudent(docId, fullName),
                        child: const Text(
                          "Approve",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
