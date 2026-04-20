import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../verification_service.dart'; // [cite: 5]
import 'package:discipline/screens/auth/register_screen.dart'; // [cite: 6]

class VerifyIdentityPage extends StatefulWidget {
  const VerifyIdentityPage({super.key});

  @override
  State<VerifyIdentityPage> createState() => _VerifyIdentityPageState();
}

class _VerifyIdentityPageState extends State<VerifyIdentityPage> {
  final _service = VerificationService(); // [cite: 13]
  File? _selectedIdPhoto; // [cite: 14]
  bool _isVerifying = false; // [cite: 15]

  // Design Colors (PDM Theme)
  final Color _darkBrown = const Color(0xFF513C2C); // [cite: 17]
  final Color _yellow = const Color(0xFFFFC107); // [cite: 18]
  final Color _bgColor = const Color(0xFFF9F7F2); // [cite: 19]

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70, // [cite: 26]
      );
      if (image != null) {
        setState(() {
          _selectedIdPhoto = File(image.path); // [cite: 30]
        });
      }
    } catch (e) {
      _showSnackBar("Access Error: $e", Colors.red);
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Identity Verification",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _darkBrown,
              ),
            ), // [cite: 50-54]
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(
                Icons.document_scanner_rounded,
                color: Colors.orange,
              ),
              title: const Text(
                "Scan ID Card (Camera)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera); // [cite: 83]
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Colors.blue,
              ),
              title: const Text(
                "Find in Gallery",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery); // [cite: 110]
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ LOGIC: OCR SCAN & FIREBASE HANDSHAKE
  Future<void> _handleVerification() async {
    if (_selectedIdPhoto == null) return; // [cite: 121]
    setState(() => _isVerifying = true); // [cite: 122]

    try {
      final Map<String, dynamic>? studentData = await _service.fetchMasterData(
        imageFile: _selectedIdPhoto!,
      ); // [cite: 124-126]

      if (studentData != null) {
        if (!mounted) return;

        // 🛑 STOP: Check if ID is already in Firebase
        if (studentData['status'] == 'already_registered') {
          _showErrorPopup(
            "Already Registered",
            "The ID ${studentData['studentID']} is already linked to an account. Please log in instead.",
          );
          return;
        }

        // 🛑 STOP: Check if student is Disabled in XAMPP
        if (studentData['status'] == 'inactive') {
          _showErrorPopup(
            "Account Disabled",
            "This PDM ID is currently disabled. Please contact the SDO.",
          );
          return;
        }

        // ✅ SUCCESS: Proceed to Registration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RegisterScreen(autoFillData: studentData), // [cite: 132]
          ),
        );
      } else {
        if (!mounted) return;
        _showSnackBar(
          "ID not found. Make sure the photo is clear.",
          Colors.red,
        ); // [cite: 137-140]
      }
    } catch (e) {
      _showSnackBar("System Error: $e", Colors.red); // [cite: 143]
    } finally {
      if (mounted) setState(() => _isVerifying = false); // [cite: 145]
    }
  }

  // ✅ HELPER: POPUP FOR ERRORS
  void _showErrorPopup(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // [cite: 153]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFile = _selectedIdPhoto != null; // [cite: 159]
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Verify Identity",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _darkBrown,
          ),
        ), // [cite: 163-167]
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context), // [cite: 175]
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildStepDots(),
            const SizedBox(height: 20),
            const Text(
              "Please scan your PDM Student ID to verify your identity.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ), // [cite: 185-188]
            const SizedBox(height: 40),
            Expanded(
              child: GestureDetector(
                onTap: _isVerifying ? null : _showPickerOptions,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasFile ? Colors.green.shade200 : Colors.black12,
                      width: 2,
                    ), // [cite: 197-203]
                  ),
                  child: hasFile
                      ? _buildFilePreview()
                      : _buildUploadPlaceholder(), // [cite: 211-213]
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasFile ? _darkBrown : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: (hasFile && !_isVerifying)
                    ? _handleVerification
                    : null, // [cite: 229-231]
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Scan & Continue",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ), // [cite: 232-241]
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: i == 0 ? _yellow : Colors.grey.shade300,
            shape: BoxShape.circle,
          ), // [cite: 255-262]
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 70),
        const SizedBox(height: 15),
        const Text(
          "ID Successfully Captured",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ), // [cite: 274-279]
        TextButton(
          onPressed: () => setState(() => _selectedIdPhoto = null),
          child: const Text(
            "Remove and Rescan",
            style: TextStyle(color: Colors.red),
          ), // [cite: 284-285]
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.document_scanner_outlined,
          color: Colors.amber.shade900,
          size: 60,
        ), // [cite: 295-298]
        const SizedBox(height: 20),
        const Text(
          "Tap to Scan Student ID",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ), // [cite: 302-303]
        const Text(
          "Use Camera or Upload from Gallery",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ), // [cite: 306-307]
      ],
    );
  }
}
