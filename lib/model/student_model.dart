import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String uid;
  final String fullName;
  final String course;
  final String studentID; // Format: PDM-XXXX-XXXXXX
  final String email;
  final String parentContact;
  final String role;
  final String status;
  final bool isApproved;

  StudentModel({
    required this.uid,
    required this.fullName,
    required this.course,
    required this.studentID,
    required this.email,
    required this.parentContact,
    this.role = 'student',
    this.status = 'pending',
    this.isApproved = false,
  });

  // Converts the Student object into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'course': course,
      'studentID': studentID,
      'email': email,
      'parentContact': parentContact,
      'role': role,
      'status': status,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
