import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationService {
  static const String _cloudName = "dnk4oieux";
  static const String _uploadPreset = "pdm_upload";

  // ✅ Keep your current live Ngrok URL
  final String _apiBaseUrl =
      "https://railway-hurray-uncurled.ngrok-free.dev/pdm_admin";

  Future<Map<String, dynamic>?> fetchMasterData({
    required File imageFile,
  }) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // 1. OCR: Read the text on the card
      final RecognizedText recognizedText = await textRecognizer.processImage(
        InputImage.fromFile(imageFile),
      );

      String scannedText = recognizedText.text;
      RegExp pdmRegex = RegExp(r"PDM-?\d{4}-?\d{6}");
      String? detectedID = pdmRegex.stringMatch(scannedText);

      if (detectedID == null) return null;

      // ---------------------------------------------------------
      // 2. FIREBASE CHECK: Is this ID already registered?
      // ---------------------------------------------------------
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('studentID', isEqualTo: detectedID)
          .get();

      if (existingUser.docs.isNotEmpty) {
        return {'status': 'already_registered', 'studentID': detectedID};
      }

      // 3. SEARCH THE MYSQL MASTER LIST (XAMPP)
      final response = await http.get(
        Uri.parse("$_apiBaseUrl/verify_student.php?student_id=$detectedID"),
        headers: {
          "ngrok-skip-browser-warning": "true",
          "Accept": "application/json",
        },
      );

      if (response.statusCode != 200) return null;
      final result = json.decode(response.body);

      // Stop if student not found
      if (result['status'] != 'success') return null;

      // ---------------------------------------------------------
      // 4. XAMPP STATUS CHECK: Is the student "Disabled"?
      // ---------------------------------------------------------
      if (result['data']['status'] == 'Disabled') {
        return {'status': 'inactive', 'studentID': detectedID};
      }

      // 5. UPLOAD TO CLOUDINARY
      var uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      uploadRequest.fields['upload_preset'] = _uploadPreset;
      uploadRequest.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var uploadResponse = await uploadRequest.send();
      if (uploadResponse.statusCode != 200) return null;

      var uploadData = await uploadResponse.stream.bytesToString();
      String imageUrl = jsonDecode(uploadData)['secure_url'];

      // 6. RETURN DATA FOR SUCCESSFUL NEW REGISTRATION
      return {
        'status': 'success',
        'first_name': result['data']['first_name'],
        'middle_name': result['data']['middle_name'],
        'last_name': result['data']['last_name'],
        'suffix': result['data']['suffix'],
        'sex': result['data']['sex'],
        'parentContact': result['data']['parentContact'],
        'course': result['data']['course'],
        'studentID': detectedID,
        'idCardUrl': imageUrl,
      };
    } catch (e) {
      print("System Error in VerificationService: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }
}
