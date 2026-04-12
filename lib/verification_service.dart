import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationService {
  static const String _cloudName = "dnk4oieux";
  static const String _uploadPreset = "pdm_upload";

  /// This function now returns the Student Data (Map) if the ID matches
  /// the master list, allowing the UI to auto-fill the form.
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
      RegExp pdmRegex = RegExp(r"PDM-\d{4}-\d{6}");
      String? detectedID = pdmRegex.stringMatch(scannedText);

      if (detectedID == null) return null;

      // 2. SEARCH THE MASTER LIST (The 'students' collection)
      // We look for students who are currently 'Disabled' (not yet registered)
      var masterQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('studentID', isEqualTo: detectedID)
          .where(
            'status',
            isEqualTo: 'Disabled',
          ) // ✅ Only finds pre-registered/inactive accounts
          .limit(1)
          .get();

      if (masterQuery.docs.isEmpty) return null;

      // 3. Upload the ID photo to Cloudinary for the Admin to see later
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send();
      if (response.statusCode != 200) return null;

      var responseData = await response.stream.bytesToString();
      String imageUrl = jsonDecode(responseData)['secure_url'];

      // 4. PREPARE THE DATA FOR AUTO-FILL
      var studentData = masterQuery.docs.first.data();
      studentData['idCardUrl'] =
          imageUrl; // Attach the photo link for the registration step

      return studentData;
    } catch (e) {
      print("System Error in VerificationService: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }
}
