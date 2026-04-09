import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminIncidentDetailScreen extends StatefulWidget {
  final String docId;

  const AdminIncidentDetailScreen({super.key, required this.docId});

  @override
  State<AdminIncidentDetailScreen> createState() =>
      _AdminIncidentDetailScreenState();
}

class _AdminIncidentDetailScreenState extends State<AdminIncidentDetailScreen> {
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFF9F7F2);
  final Color _cardColor = const Color(0xFFE5DCD3);

  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('violations')
          .doc(widget.docId)
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Report $newStatus successfully")));

      if (newStatus == 'resolved' || newStatus == 'declined') {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          "Report Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _darkBrown,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('violations')
            .doc(widget.docId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Report not found."));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String status = (data['status'] ?? 'pending')
              .toString()
              .toLowerCase();

          String dateStr = "N/A";
          if (data['timestamp'] != null) {
            dateStr = DateFormat(
              'MMMM d, yyyy - h:mm a',
            ).format(data['timestamp'].toDate());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "INCIDENT DETAILS",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                  const Divider(height: 40),

                  // --- CORRECTED DATA KEYS ---
                  _infoRow("REPORTED BY:", data['reporterName'] ?? "Unknown"),
                  _infoRow("STUDENT ID:", data['reporterID'] ?? "N/A"),
                  _infoRow("VIOLATION TYPE:", data['type'] ?? "Other"),
                  _infoRow("DATE & TIME:", dateStr),

                  const SizedBox(height: 25),
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
                    margin: const EdgeInsets.only(top: 10, bottom: 30),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      data['description'] ?? "No description provided.",
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  // --- ACTION BUTTONS LOGIC ---
                  if (status == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            "APPROVE",
                            Colors.green,
                            () => _updateStatus('approved'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionButton(
                            "DECLINE",
                            Colors.red,
                            () => _updateStatus('declined'),
                          ),
                        ),
                      ],
                    )
                  else if (status == 'approved')
                    _actionButton(
                      "MARK AS DONE",
                      _darkBrown,
                      () => _updateStatus('resolved'),
                    )
                  else if (status == 'resolved' || status == 'cleared')
                    const Center(
                      child: Text(
                        "✅ TASK COMPLETED",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (status == 'declined')
                    const Center(
                      child: Text(
                        "❌ REPORT DECLINED",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'pending'
        ? Colors.amber
        : (status == 'approved'
              ? Colors.blue
              : (status == 'declined' ? Colors.red : Colors.green));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
