import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Color _darkBrown = const Color(0xFF513C2C);
    final Color _bgColor = const Color(0xFFF9F7F2);

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        // 1. GET PROFILE INFO
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String name = userData['fullName'] ?? "Student";
          String studentID = userData['studentID'] ?? "No ID";
          String course = userData['course'] ?? "No Course";

          return StreamBuilder<QuerySnapshot>(
            // 2. GET VIOLATIONS (Filtered by YOUR Unique ID)
            stream: FirebaseFirestore.instance
                .collection('violations')
                .where('studentUid', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, violationSnapshot) {
              if (!violationSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              // Calculate dynamic counts from the database
              var docs = violationSnapshot.data!.docs;
              int totalOffenses = docs.length;
              int pending = docs.where((d) => d['status'] == 'pending').length;
              int resolved = docs
                  .where(
                    (d) =>
                        d['status'] == 'resolved' || d['status'] == 'cleared',
                  )
                  .length;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 60,
                  left: 25,
                  right: 25,
                  bottom: 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _darkBrown,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFFFC107),
                            size: 35,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              studentID,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              course,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () => FirebaseAuth.instance.signOut().then(
                            (_) => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Text(
                      "Welcome, ${name.split(' ')[0].toLowerCase()}",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      "Here's an overview of your discipline record",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // --- STATUS CARD (Changes color based on data) ---
                    _buildActiveViolationCard(totalOffenses),
                    const SizedBox(height: 25),

                    // --- STATS GRID ---
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard(
                          "Total Incidents",
                          totalOffenses.toString(),
                          Colors.indigo,
                        ),
                        _statCard("Pending", pending.toString(), Colors.pink),
                        _statCard(
                          "Resolved",
                          resolved.toString(),
                          Colors.green,
                        ),
                        _statCard(
                          "Alerts",
                          totalOffenses >= 3 ? "!" : "0",
                          Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),
                    const Text(
                      "Recent Records",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- RECENT RECORDS LIST ---
                    if (docs.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            "No records found.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) =>
                            _buildViolationItem(docs[index]),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActiveViolationCard(int count) {
    bool isClear = count == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isClear ? const Color(0xFFEFFFF4) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClear ? Colors.green.shade200 : Colors.red.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isClear ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: isClear ? Colors.green : Colors.red,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            isClear ? "Clean Record" : "Active Violation",
            style: TextStyle(
              color: isClear ? Colors.green.shade900 : Colors.red.shade900,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isClear)
            Text(
              "You have $count recorded offenses", // <--- THIS IS NOW DYNAMIC
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViolationItem(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String type = data['type'] ?? "Violation";
    String desc = data['description'] ?? "No details provided.";

    // FORMAT DATE FROM FIRESTORE TIMESTAMP
    String formattedDate = "N/A";
    if (data['timestamp'] != null) {
      Timestamp t = data['timestamp'];
      formattedDate = DateFormat('MMM d, yyyy').format(t.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Vertical color bar
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: type.contains("Uniform") ? Colors.orange : Colors.red,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                val,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 35,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
