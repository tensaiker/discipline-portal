import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminIncidentReports extends StatefulWidget {
  const AdminIncidentReports({super.key});

  @override
  State<AdminIncidentReports> createState() => _AdminIncidentReportsState();
}

class _AdminIncidentReportsState extends State<AdminIncidentReports> {
  String _searchQuery = "";
  String _selectedTab = "All"; // Filter: All, Pending, Approved, Resolved

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3); // Matching your background
  final Color _cardColor = const Color(0xFFF9F7F2);

  // --- DATABASE LOGIC ---

  // This updates the status and automatically notifies the student's Alerts tab
  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('violations')
          .doc(docId)
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Report $newStatus successfully")));
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. SEARCH BAR
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search Student ID",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // 2. CATEGORY TABS (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ["All", "Pending", "Approved", "Resolved"].map((tab) {
              bool isSelected = _selectedTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(tab),
                  selected: isSelected,
                  selectedColor: _darkBrown,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedTab = tab);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // 3. INCIDENT LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getFilteredStream(),
            builder: (context, snapshot) {
              // --- 1. SAFETY NET: Catch Firebase Errors without crashing ---
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Firestore Error: ${snapshot.error}\n\nCheck VS Code Debug Console for the index link!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              // --- 2. LOADING STATE ---
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // --- 3. SAFE DATA CHECK: Prevents the Null Operator Crash ---
              if (!snapshot.hasData) {
                return const Center(child: Text("Loading data..."));
              }

              var docs = snapshot.data!.docs.where((doc) {
                String studentID = (doc['studentID'] ?? "")
                    .toString()
                    .toLowerCase();
                return studentID.contains(_searchQuery.toLowerCase());
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text("No incident reports found."));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _buildIncidentCard(docs[index], index + 1);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance.collection('violations');
    if (_selectedTab != "All") {
      query = query.where('status', isEqualTo: _selectedTab.toLowerCase());
    }
    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Widget _buildIncidentCard(DocumentSnapshot doc, int displayNum) {
    var data = doc.data() as Map<String, dynamic>;
    String status = (data['status'] ?? 'pending').toString().toLowerCase();

    // Date formatting
    String dateStr = "N/A";
    if (data['timestamp'] != null) {
      dateStr = DateFormat('MMMM d, yyyy').format(data['timestamp'].toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Incident # and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "INCIDENT #$displayNum",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const Divider(height: 30),

          _infoRow("REPORTED BY:", data['studentID'] ?? "N/A"),
          _infoRow("VIOLATION TYPE:", data['type'] ?? "Other"),
          _infoRow("DATE:", dateStr),

          const SizedBox(height: 15),
          const Text(
            "DESCRIPTION:",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(data['description'] ?? "No description provided."),
          ),

          // ACTION BUTTONS logic
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    "APPROVE",
                    Colors.green,
                    () => _updateStatus(doc.id, 'approved'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    "DECLINE",
                    Colors.red,
                    () => _updateStatus(doc.id, 'declined'),
                  ),
                ),
              ],
            )
          else if (status == 'approved')
            _actionButton(
              "MARK AS DONE",
              _darkBrown,
              () => _updateStatus(doc.id, 'resolved'),
            )
          else if (status == 'resolved')
            const Center(
              child: Text(
                "✅ TASK COMPLETED",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label  ",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'pending'
        ? Colors.amber
        : (status == 'approved' ? Colors.green : Colors.brown);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
