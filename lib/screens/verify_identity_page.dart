import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../verification_service.dart'; // ✅ Path to your service logic
import 'package:discipline/screens/auth/register_screen.dart'; // ✅ Project-level import

class VerifyIdentityPage extends StatefulWidget {
  const VerifyIdentityPage({super.key});

  @override
  State<VerifyIdentityPage> createState() => _VerifyIdentityPageState();
}

class _VerifyIdentityPageState extends State<VerifyIdentityPage> {
  final _service = VerificationService();
  File? _selectedIdPhoto;
  bool _isVerifying = false;

  // Design Colors (PDM Theme)
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);
  final Color _bgColor = const Color(0xFFF9F7F2);

  // ✅ LOGIC: OPEN CAMERA OR GALLERY
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70, // Compresses to 70% for faster OCR processing
      );

      if (image != null) {
        setState(() {
          _selectedIdPhoto = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar("Access Error: $e", Colors.red);
    }
  }

  // ✅ UI: CHOICE MENU (Pop-up from bottom)
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
            ),
            const SizedBox(height: 8),
            const Text(
              "Select a method to provide your Student ID.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 30),

            // OPTION 1: SCAN WITH CAMERA
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.orange,
                ),
              ),
              title: const Text(
                "Scan ID Card (Camera)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Point your camera at the ID"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera); // ✅ LAUNCHES CAMERA
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Divider(),
            ),

            // OPTION 2: FIND IN GALLERY
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                "Find in Gallery",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Upload a photo you already took"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery); // ✅ LAUNCHES GALLERY
              },
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  // LOGIC: OCR SCAN & FIREBASE HANDSHAKE
  Future<void> _handleVerification() async {
    if (_selectedIdPhoto == null) return;
    setState(() => _isVerifying = true);

    try {
      final Map<String, dynamic>? studentData = await _service.fetchMasterData(
        imageFile: _selectedIdPhoto!,
      );

      if (studentData != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterScreen(autoFillData: studentData),
          ),
        );
      } else {
        if (!mounted) return;
        _showSnackBar(
          "ID not found. Make sure the photo is clear.",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("System Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFile = _selectedIdPhoto != null;
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Verify Identity",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _darkBrown,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
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
            ),
            const SizedBox(height: 40),

            // ✅ INTERACTIVE BOX: Opens the Selection Menu
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
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: hasFile
                      ? _buildFilePreview()
                      : _buildUploadPlaceholder(),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // MAIN BUTTON
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
                    : null,
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Scan & Continue",
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
          ),
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
        ),
        TextButton(
          onPressed: () => setState(() => _selectedIdPhoto = null),
          child: const Text(
            "Remove and Rescan",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.document_scanner_outlined, // ✅ Pro Scanner Icon
          color: Colors.amber.shade900,
          size: 60,
        ),
        const SizedBox(height: 20),
        const Text(
          "Tap to Scan Student ID",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Text(
          "Use Camera or Upload from Gallery",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
