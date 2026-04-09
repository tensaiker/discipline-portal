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
                  // 1. GET VIOLATIONS COMMITTED BY THE STUDENT
                  stream: FirebaseFirestore.instance
                      .collection('violations')
                      .where('studentUid', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, offenderSnapshot) {
                    if (offenderSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<QuerySnapshot>(
                      // 2. GET INCIDENTS REPORTED BY THE STUDENT
                      stream: FirebaseFirestore.instance
                          .collection('violations')
                          .where('reporterUid', isEqualTo: user?.uid)
                          .snapshots(),
                      builder: (context, reporterSnapshot) {
                        if (reporterSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // --- MERGE AND SORT THE LISTS ---
                        var offenderDocs = offenderSnapshot.hasData
                            ? offenderSnapshot.data!.docs
                            : [];
                        var reporterDocs = reporterSnapshot.hasData
                            ? reporterSnapshot.data!.docs
                            : [];

                        // Combine both lists into one timeline
                        List<DocumentSnapshot> allAlerts = [
                          ...offenderDocs,
                          ...reporterDocs,
                        ];

                        // Sort them by timestamp (newest first)
                        allAlerts.sort((a, b) {
                          var dataA = a.data() as Map<String, dynamic>;
                          var dataB = b.data() as Map<String, dynamic>;
                          Timestamp? tA = dataA['timestamp'];
                          Timestamp? tB = dataB['timestamp'];
                          if (tA == null || tB == null) return 0;
                          return tB.compareTo(tA); // Descending order
                        });

                        if (allAlerts.isEmpty) {
                          return const Center(
                            child: Text(
                              "No notifications yet.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: allAlerts.length,
                          itemBuilder: (context, index) {
                            var doc = allAlerts[index];
                            var data = doc.data() as Map<String, dynamic>;

                            // Check if this document is an OFFENSE or a REPORT
                            bool isOffense = data['studentUid'] == user?.uid;

                            return _buildDynamicAlertCard(data, isOffense);
                          },
                        );
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

  Widget _buildDynamicAlertCard(Map<String, dynamic> data, bool isOffense) {
    String status = (data['status'] ?? 'pending').toString().toLowerCase();
    String type = data['type'] ?? 'Incident';

    // --- UI CONFIGURATION ---
    Color themeColor = Colors.grey;
    IconData icon = Icons.info_outline;
    String title = "Update";
    String description = "";

    // 1. IF THEY ARE THE OFFENDER (They did the bad thing)
    if (isOffense) {
      if (status == 'resolved' || status == 'cleared') {
        title = "✅ Violation Cleared";
        description = "Your disciplinary record for $type has been resolved.";
        themeColor = Colors.green;
        icon = Icons.check_circle_outline;
      } else {
        title = "⚠️ Violation Notice";
        description =
            "You have been cited for a violation: $type. Check your handbook.";
        themeColor = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
      }
    }
    // 2. IF THEY ARE THE REPORTER (They reported someone else)
    else {
      switch (status) {
        case 'pending':
          title = "📝 Report Submitted";
          description =
              "The incident you reported ($type) is waiting for Admin review.";
          themeColor = Colors.orange;
          icon = Icons.access_time;
          break;
        case 'approved':
          title = "🔍 Report Under Review";
          description =
              "An Admin is now actively investigating the $type incident you reported.";
          themeColor = Colors.blue;
          icon = Icons.remove_red_eye;
          break;
        case 'declined':
          title = "❌ Report Dismissed";
          description =
              "The $type incident you reported was reviewed but declined by the Admin.";
          themeColor = Colors.blueGrey;
          icon = Icons.cancel_outlined;
          break;
        case 'resolved':
        case 'cleared':
          title = "✅ Report Closed";
          description =
              "Action has been taken on the $type incident you reported. Thank you.";
          themeColor = Colors.green;
          icon = Icons.task_alt;
          break;
        default:
          title = "Status Update";
          description =
              "There is an update regarding the $type incident you reported.";
          themeColor = Colors.brown;
          icon = Icons.notifications;
      }
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
