import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ReportIncident extends StatefulWidget {
  const ReportIncident({super.key});

  @override
  State<ReportIncident> createState() => _ReportIncidentState();
}

class _ReportIncidentState extends State<ReportIncident> {
  final _detailsController = TextEditingController();
  String? _selectedViolation;
  DateTime? _pickedDate;
  File? _imageFile;
  bool _isSubmitting = false;

  final Color _darkBrown = const Color(0xFF4A3424);
  final Color _bgColor = const Color(0xFFF9F7F2);

  // --- CLOUDINARY CONFIGURATION ---
  final String _cloudName = "dnk4oieux";
  final String _uploadPreset = "pdm_preset";

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/image/upload",
      );
      var request = http.MultipartRequest("POST", url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonResponse = jsonDecode(responseString);
        return jsonResponse['secure_url'];
      }
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkBrown,
              onPrimary: Colors.white,
              onSurface: _darkBrown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _pickedDate) {
      setState(() => _pickedDate = picked);
    }
  }

  Future<void> _submitReport() async {
    // 1. Force keyboard to close immediately
    FocusScope.of(context).unfocus();

    if (_selectedViolation == null ||
        _detailsController.text.trim().isEmpty ||
        _pickedDate == null ||
        _imageFile == null) {
      _showSnackBar("Please fill out all fields.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!userDoc.exists) throw Exception("User profile not found.");
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // 2. Upload to Cloudinary
      String? imageUrl = await _uploadToCloudinary(_imageFile!);
      if (!mounted) return;
      if (imageUrl == null) throw Exception("Image upload failed.");

      String formattedDate = DateFormat('MMMM d, yyyy').format(_pickedDate!);

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('violations').add({
        'reporterUid': user.uid,
        'reporterName': userData['fullName'] ?? "Unknown Student",
        'reporterID': userData['studentID'] ?? "N/A",
        'type': _selectedViolation,
        'description': _detailsController.text.trim(),
        'date': formattedDate,
        'evidenceUrl': imageUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 4. STOP SPINNER
      setState(() => _isSubmitting = false);

      // 5. BRUTE FORCE EXIT: Skip the pop animation and force-rebuild the Home screen.
      // This is the only way to prevent the Mali GPU from crashing on your device.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/student_home',
        (route) => false,
      );

      // Show success on the fresh home screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incident reported successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: _darkBrown),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Incident',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _darkBrown,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Help maintain order by reporting violations accurately.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              const Text(
                'Violation Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedViolation,
                decoration: _inputDecoration("Select type"),
                items:
                    [
                          'Bullying',
                          'Vandalism',
                          'Cheating',
                          'Uniform Violation',
                          'Smoking',
                          'Alcohol',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (val) => setState(() => _selectedViolation = val),
              ),
              const SizedBox(height: 20),
              const Text(
                'Date of Incident',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _pickedDate == null
                            ? "Select Date"
                            : DateFormat('MMMM d, yyyy').format(_pickedDate!),
                        style: TextStyle(
                          color: _pickedDate == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      Icon(Icons.calendar_today, color: _darkBrown, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Photo Evidence',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: _darkBrown,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap to upload photo evidence",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Violation Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: _inputDecoration(
                  "Briefly describe what happened...",
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkBrown, width: 2),
      ),
    );
  }
}
