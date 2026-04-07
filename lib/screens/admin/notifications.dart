import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'incident_detail.dart'; // Make sure this import is here!

class AdminNotifications extends StatelessWidget {
  const AdminNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final Color _darkBrown = const Color(0xFF513C2C);
    final Color _bgColor = const Color(0xFFF9F7F2);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _darkBrown,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('violations')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No new notifications.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(docs[index], context);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(DocumentSnapshot doc, BuildContext context) {
    var data = doc.data() as Map<String, dynamic>;
    String type = data['type'] ?? "Incident";
    String student = data['studentName'] ?? "Unknown Student";
    String status = (data['status'] ?? 'pending').toString().toLowerCase();

    // --- UNREAD LOGIC ---
    // If 'isRead' doesn't exist yet (for older reports), it defaults to false (unread)
    bool isRead = data['isRead'] ?? false;

    Color statusColor;
    IconData statusIcon;
    String titleText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.report_problem_outlined;
        titleText = "New Report: $type";
        break;
      case 'approved':
        statusColor = Colors.blue;
        statusIcon = Icons.fact_check_outlined;
        titleText = "Report Approved";
        break;
      case 'declined':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        titleText = "Report Declined";
        break;
      case 'resolved':
      case 'cleared':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        titleText = "Report Resolved";
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
        titleText = "Update: $type";
    }

    String timeLabel = "Just now";
    if (data['timestamp'] != null) {
      Timestamp t = data['timestamp'];
      timeLabel = DateFormat('MMM d, h:mm a').format(t.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Slightly change background if unread so it pops out more
        color: isRead ? Colors.white : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
        // Add a subtle border if it's unread
        border: isRead
            ? null
            : Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          titleText,
          // Make the text bolder if it's unread
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "From: $student",
              style: TextStyle(
                fontSize: 12,
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        // Adding the Unread Red Dot Indicator
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRead)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () async {
          // --- MARK AS READ IN DATABASE ---
          if (!isRead) {
            await FirebaseFirestore.instance
                .collection('violations')
                .doc(doc.id)
                .update({'isRead': true});
          }

          // Navigate to the Incident Detail screen
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminIncidentDetailScreen(docId: doc.id),
            ),
          );
        },
      ),
    );
  }
}
