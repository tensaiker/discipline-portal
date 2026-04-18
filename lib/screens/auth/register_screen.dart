import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../verification_service.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? autoFillData;
  const RegisterScreen({super.key, this.autoFillData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  final _service = VerificationService();

  // Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _idController = TextEditingController();
  final _parentController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State Variables
  String? _selectedCourse;
  String? _selectedSex;
  String? _idCardUrl;
  bool _isPasswordVisible = false;
  File? _selectedIdPhoto;
  bool _isVerifying = false;
  bool _isRegistering = false;

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);
  final Color _creamyWhite = const Color(0xFFF9F7F2);

  @override
  void initState() {
    super.initState();
    if (widget.autoFillData != null) {
      _fillFormWithData(widget.autoFillData!);
    }
  }

  void _fillFormWithData(Map<String, dynamic> data) {
    setState(() {
      _firstNameController.text = data['first_name'] ?? '';
      _middleNameController.text = data['middle_name'] ?? '';
      _lastNameController.text = data['last_name'] ?? '';
      _suffixController.text = data['suffix'] ?? '';

      // Auto-format ID for display
      String rawID = data['studentID'] ?? '';
      _idController.text = rawID.replaceAll("PDM-", "").replaceAll("-", "");

      _selectedSex = data['sex'] ?? 'Male';
      _selectedCourse = data['course'] ?? 'BSIT';

      String rawParent = (data['parentContact'] ?? '').toString();
      _parentController.text = rawParent.replaceFirst("639", "");

      _idCardUrl = data['idCardUrl'];
    });
  }

  Future<void> _handleIDScan() async {
    if (_selectedIdPhoto == null) return;
    setState(() => _isVerifying = true);
    try {
      final data = await _service.fetchMasterData(imageFile: _selectedIdPhoto!);
      if (data != null) {
        _fillFormWithData(data);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      } else {
        _showSnackBar(
          "ID not found in Master List. Ensure the text is clear.",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("Scan Error: Check your Ngrok connection.", Colors.red);
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleFinalRegister() async {
    if (_emailController.text.isEmpty || _passwordController.text.length < 6) {
      _showSnackBar(
        "Please check your email and password (min 6 chars).",
        Colors.orange,
      );
      return;
    }

    setState(() => _isRegistering = true);
    try {
      String rawIdInput = _idController.text.trim();

      // Ensure formatted ID matches DB style (PDM-YYYY-XXXXXX)
      String formattedID = rawIdInput.length > 4
          ? "PDM-${rawIdInput.substring(0, 4)}-${rawIdInput.substring(4)}"
          : rawIdInput;

      // 🛑 STEP 1: PREVENT DUPLICATE REGISTRATION
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('studentID', isEqualTo: formattedID)
          .get();

      if (existingUser.docs.isNotEmpty) {
        _showSnackBar("This Student ID is already registered!", Colors.red);
        setState(() => _isRegistering = false);
        return;
      }

      // STEP 2: CREATE AUTH USER
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // STEP 3: BUILD FULL NAME
      String fName = _firstNameController.text.trim();
      String mName = _middleNameController.text.trim();
      String lName = _lastNameController.text.trim();
      String sfx = _suffixController.text.trim();

      String combinedFullName =
          "$fName ${mName.isNotEmpty ? '$mName ' : ''}$lName${sfx.isNotEmpty ? ' $sfx' : ''}"
              .toUpperCase()
              .trim();

      // STEP 4: SAVE TO FIRESTORE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'uid': cred.user!.uid,
            'firstName': fName.toUpperCase(),
            'middleName': mName.toUpperCase(),
            'lastName': lName.toUpperCase(),
            'suffix': sfx.toUpperCase(),
            'fullName': combinedFullName,
            'studentID': formattedID,
            'email': _emailController.text.trim(),
            'parentContact': "639${_parentController.text.trim()}",
            'course': _selectedCourse,
            'sex': _selectedSex,
            'idCardUrl': _idCardUrl,
            'role': 'student',
            'status': 'Pending', // Setting to pending until admin approves
            'isActive': false,
            'isApproved': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } catch (e) {
      _showSnackBar("Registration Error: $e", Colors.red);
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
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
    return Scaffold(
      backgroundColor: _creamyWhite,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2(), _buildStep3()],
      ),
    );
  }

  // UI BUILDERS
  Widget _buildStep1() {
    bool hasFile = _selectedIdPhoto != null;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          _stepIndicator(1),
          const SizedBox(height: 30),
          Text(
            "Verify Identity",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Scan your PDM ID to unlock the registration form.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera, // Better for demo
                  imageQuality: 70,
                );
                if (image != null)
                  setState(() => _selectedIdPhoto = File(image.path));
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black12),
                ),
                child: hasFile
                    ? _buildFilePreview()
                    : _buildUploadPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasFile ? _darkBrown : Colors.grey,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: hasFile && !_isVerifying ? _handleIDScan : null,
            child: _isVerifying
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "Scan & Continue",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                ),
              ),
              _stepIndicator(2),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Complete Registration",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Official PDM details detected. Please set your credentials.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: _textField(
                  "First Name",
                  _firstNameController,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "Middle Name",
                  _middleNameController,
                  readOnly: true,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _textField(
                  "Last Name",
                  _lastNameController,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _textField(
                  "Suffix",
                  _suffixController,
                  hint: "N/A",
                  readOnly: true,
                ),
              ),
            ],
          ),
          _textField(
            "Student ID",
            _idController,
            prefix: "PDM-",
            readOnly: true,
          ),
          _textField(
            "Course",
            TextEditingController(text: _selectedCourse),
            readOnly: true,
          ),
          _textField(
            "Parent Contact",
            _parentController,
            prefix: "639",
            readOnly: true,
          ),
          const Divider(height: 40),
          _textField(
            "Email Address",
            _emailController,
            hint: "example@gmail.com",
          ),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: _inputDecoration("Set Password").copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: _darkBrown,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _isRegistering ? null : _handleFinalRegister,
            child: _isRegistering
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    "Submit Registration",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: Colors.orange,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            "Success! Registration Sent",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Your ID matched our official record. Our registrar will verify and activate your account shortly.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkBrown,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Return to Login",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildFilePreview() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.check_circle, color: Colors.green, size: 40),
      const Text(
        "ID Captured Successfully",
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
      ),
      TextButton(
        onPressed: () => setState(() => _selectedIdPhoto = null),
        child: const Text("Retake", style: TextStyle(color: Colors.red)),
      ),
    ],
  );

  Widget _buildUploadPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.camera_alt_outlined, color: Colors.amber.shade900, size: 40),
      const Text(
        "Tap to Scan PDM ID",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          "Ensure student name and ID are readable",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ),
    ],
  );

  Widget _stepIndicator(int currentStep) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      3,
      (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: i < currentStep ? _yellow : Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? prefix,
    String? hint,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 13),
      decoration: _inputDecoration(label).copyWith(
        prefixText: prefix,
        hintText: hint,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
      ),
    ),
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    labelStyle: const TextStyle(fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.grey),
    ),
  );
}
