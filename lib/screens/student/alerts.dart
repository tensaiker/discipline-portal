import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentAlerts extends StatelessWidget {
  const StudentAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Color _bgColor = const Color(0xFFF9F7F2);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alerts',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // Filters by the student's unique UID so they only see their own reports
                  stream: FirebaseFirestore.instance
                      .collection('violations')
                      .where('studentUid', isEqualTo: user?.uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No notifications yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    var alerts = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        return _buildDynamicAlertCard(alerts[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicAlertCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String status = (data['status'] ?? 'pending').toString().toLowerCase();
    String type = data['type'] ?? 'Incident';

    // --- UI CONFIGURATION BASED ON ADMIN ACTION ---
    Color themeColor = Colors.grey;
    IconData icon = Icons.info_outline;
    String title = "Update";
    String description = "";

    switch (status) {
      case 'pending':
        title = "Report Submitted";
        description = "Your report for $type is currently under review.";
        themeColor = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'approved':
        title = "Incident Approved";
        description = "The Admin has verified your report for $type.";
        themeColor = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case 'declined':
        title = "Report Declined";
        description =
            "Your report for $type was not approved by the administration.";
        themeColor = Colors.blueGrey;
        icon = Icons.cancel_outlined;
        break;
      case 'resolved':
      case 'cleared':
        title = "Record Resolved";
        description = "Your $type violation has been successfully cleared.";
        themeColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      default:
        title = "Status Update";
        description = "There is an update regarding your $type record.";
        themeColor = Colors.brown;
        icon = Icons.notifications;
    }

    // Time formatting using intl
    String timeAgo = "N/A";
    if (data['timestamp'] != null) {
      timeAgo = DateFormat('MMM d, h:mm a').format(data['timestamp'].toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Side Indicator Strip
            Container(
              width: 8,
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            const SizedBox(width: 15),

            // Icon Background Circle
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: themeColor, size: 20),
            ),

            const SizedBox(width: 15),

            // Text Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
