import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  // Use this to get a specific student's info
  Future<Map<String, dynamic>?> getStudentData(String studentID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentID)
          .get();

      if (doc.exists) {
        return doc.data();
      } else {
        print("No student found with ID: $studentID");
        return null;
      }
    } catch (e) {
      print("Error fetching student: $e");
      return null;
    }
  }
}
