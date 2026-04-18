import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class VerificationService {
  static const String _cloudName = "dnk4oieux";
  static const String _uploadPreset = "pdm_upload";

  // ✅ UPDATED: Your Live Ngrok URL for the PDM Presentation
  static const String _apiBaseUrl =
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

      // Matches PDM-2026-123456 or PDM2026123456
      RegExp pdmRegex = RegExp(r"PDM-?\d{4}-?\d{6}");
      String? detectedID = pdmRegex.stringMatch(scannedText);

      if (detectedID == null) return null;

      // 2. SEARCH THE MYSQL MASTER LIST (Through Ngrok Tunnel)
      final response = await http.get(
        Uri.parse("$_apiBaseUrl/verify_student.php?student_id=$detectedID"),
        headers: {
          // ✅ MANDATORY: This skips the Ngrok warning page so the scanner can work
          "ngrok-skip-browser-warning": "true",
          "Accept": "application/json",
        },
      );

      if (response.statusCode != 200) return null;

      final result = json.decode(response.body);

      // Stop if the student isn't in the XAMPP Master List
      if (result['status'] != 'success') return null;

      // 3. Upload the ID photo to Cloudinary (Standard Cloud Upload)
      var uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      // Note: Cloudinary is separate from Ngrok, so no extra header needed here.
      uploadRequest.fields['upload_preset'] = _uploadPreset;
      uploadRequest.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var uploadResponse = await uploadRequest.send();
      if (uploadResponse.statusCode != 200) return null;

      var uploadData = await uploadResponse.stream.bytesToString();
      String imageUrl = jsonDecode(uploadData)['secure_url'];

      // 4. PREPARE THE DATA FOR AUTO-FILL
      // This maps the MySQL results to your Registration UI fields
      Map<String, dynamic> studentData = {
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

      return studentData;
    } catch (e) {
      print("System Error in VerificationService: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }
}
