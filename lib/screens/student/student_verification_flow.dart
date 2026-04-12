import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../verification_service.dart';
import '../auth/register_screen.dart'; // Ensure this path is correct

class StudentVerificationFlow extends StatefulWidget {
  const StudentVerificationFlow({super.key});

  @override
  State<StudentVerificationFlow> createState() =>
      _StudentVerificationFlowState();
}

class _StudentVerificationFlowState extends State<StudentVerificationFlow> {
  final PageController _pageController = PageController();
  final _verificationService = VerificationService();

  File? _selectedIdPhoto;
  bool _isUploading = false;

  final Color _creamyWhite = const Color(0xFFF9F7F2);
  final Color _creamyYellow = const Color(0xFFF9EFCC);
  final Color _darkBrown = const Color(0xFF4E342E);
  final Color _approvalGreen = const Color(0xFFE5F5E0);
  final Color _approvalGreenText = const Color(0xFF006400);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedIdPhoto = File(image.path);
      });
    }
  }

  // ==========================================
  // UPDATED LOGIC: SCAN ID & FETCH MASTER DATA
  // ==========================================
  Future<void> _submitForVerification() async {
    if (_selectedIdPhoto == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Call the new fetchMasterData method from your service
      final Map<String, dynamic>? studentData = await _verificationService
          .fetchMasterData(imageFile: _selectedIdPhoto!);

      if (studentData != null) {
        // 2. SUCCESS: Navigate to RegisterScreen and pass the data for auto-fill
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterScreen(autoFillData: studentData),
          ),
        );
      } else {
        // 3. FAIL: Show error if ID is not in the Master List
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "ID not found in Master List. Please ensure the photo is clear.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: BackButton(
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildUploadScreen(),
    );
  }

  Widget _buildUploadScreen() {
    bool hasFile = _selectedIdPhoto != null;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepDot(isActive: true),
              const SizedBox(width: 5),
              _stepDot(isActive: false),
              const SizedBox(width: 5),
              _stepDot(isActive: false),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Step 1 of 2",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Verify Identity",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            "Upload your PDM ID to unlock the registration form.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _creamyWhite,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: hasFile
                      ? _buildFileSelectedPreview()
                      : _buildUploadPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: hasFile && !_isUploading
                  ? _submitForVerification
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasFile ? _darkBrown : Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Scan & Continue",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectedPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _approvalGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: _approvalGreenText, size: 30),
        ),
        const SizedBox(height: 15),
        Text(
          "ID Card Selected",
          style: TextStyle(
            color: _approvalGreenText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _selectedIdPhoto = null),
          child: const Text(
            "Change Photo",
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
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _creamyYellow,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.camera_alt_outlined,
            color: Colors.amber.shade900,
            size: 30,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Tap to Scan Student ID",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const Text(
          "Ensure text is clear and readable",
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _stepDot({required bool isActive}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.amber : _creamyWhite,
        shape: BoxShape.circle,
        border: isActive ? null : Border.all(color: Colors.black12),
      ),
    );
  }
}
