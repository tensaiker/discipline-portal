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
  String _selectedTab = "All";

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFE5DCD3);
  final Color _cardColor = const Color(0xFFF9F7F2);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Incident marked as ${newStatus.toUpperCase()}"),
        ),
      );
    } catch (e) {
      print("Error: $e");
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
              hintText: "Search Student ID...",
              prefixIcon: Icon(Icons.search, color: _darkBrown),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // 2. CATEGORY TABS
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No incident reports found."));
              }

              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String sID = (data['reporterID'] ?? "")
                    .toString()
                    .toLowerCase();
                return sID.contains(_searchQuery.toLowerCase());
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) =>
                    _buildIncidentCard(docs[index]),
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

  Widget _buildIncidentCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String status = (data['status'] ?? 'pending').toString().toLowerCase();
    String evidenceUrl = data['evidenceUrl'] ?? "";

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (data['type'] ?? "VIOLATION").toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const Divider(height: 30),
          _infoRow("REPORTER ID:", data['reporterID'] ?? "N/A"),
          _infoRow("REPORTER NAME:", data['reporterName'] ?? "Unknown"),

          const SizedBox(height: 15),

          // --- EVIDENCE VIEWING SECTION ---
          const Text(
            "EVIDENCE:",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          if (evidenceUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                evidenceUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            )
          else
            const Text(
              "No photo evidence provided.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),

          const SizedBox(height: 15),
          const Text(
            "DESCRIPTION:",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
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
            child: Text(data['description'] ?? "No details provided."),
          ),

          // --- ACTION BUTTONS ---
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
              "MARK AS RESOLVED",
              _darkBrown,
              () => _updateStatus(doc.id, 'resolved'),
            )
          else
            const Center(
              child: Text(
                "✅ ACTION COMPLETED",
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            "$label ",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'pending'
        ? Colors.amber
        : (status == 'approved' ? Colors.blue : Colors.green);
    if (status == 'declined') color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
