import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:discipline/model/student_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();

  // Controllers (Updated for new Name format)
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();

  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentController = TextEditingController();
  final _passwordController = TextEditingController();

  // State Variables
  String? _selectedCourse;
  String? _selectedSex; // New Sex Dropdown Variable
  bool _isPasswordVisible = false;

  final List<String> _courses = [
    "BS Information Technology",
    "BS Computer Science",
    "BCED",
  ];

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);

  // ==========================================
  // VALIDATION LOGIC
  // ==========================================
  bool _validateStep1() {
    // 1. Name Check (First & Last are required)
    if (_firstNameController.text.trim().isEmpty) {
      _showValidationError("First Name");
      return false;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showValidationError("Last Name");
      return false;
    }
    // 2. Sex Check
    if (_selectedSex == null) {
      _showValidationError("Sex");
      return false;
    }
    // 3. Course Check
    if (_selectedCourse == null) {
      _showValidationError("Course");
      return false;
    }
    // 4. Student ID Check (Expecting exactly 10 digits to match PDM-XXXX-XXXXXX)
    if (_idController.text.length != 10) {
      _showValidationError("Student ID (Must be 10 digits)");
      return false;
    }
    // 5. Email Check
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _showValidationError("Email");
      return false;
    }
    // 6. Parent Contact Check (Expecting exactly 8 digits to match 639XXXXXXXX)
    if (_parentController.text.length != 8) {
      _showValidationError("Parent Contact (Must be 8 numbers)");
      return false;
    }
    // 7. Password Check
    if (_passwordController.text.length < 6) {
      _showValidationError("Password (Min 6 characters)");
      return false;
    }

    return true; // All fields are correct!
  }

  void _showValidationError(String fieldName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Please input the $fieldName correctly."),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // FIREBASE REGISTRATION
  // ==========================================
  Future<void> _handleRegister() async {
    try {
      // 1. Combine Name
      String fName = _firstNameController.text.trim();
      String mName = _middleNameController.text.trim();
      String lName = _lastNameController.text.trim();
      String suffix = _suffixController.text.trim();

      String combinedFullName =
          "$fName ${mName.isNotEmpty ? '$mName ' : ''}$lName${suffix.isNotEmpty ? ' $suffix' : ''}"
              .trim();

      // 2. Format ID and Phone
      // Grabs the 10 digits and forces the hyphen: PDM-XXXX-XXXXXX
      String idString = _idController.text.trim();
      String formattedId =
          "PDM-${idString.substring(0, 4)}-${idString.substring(4)}";

      // Combines the fixed 639 with the 8 typed digits
      String formattedParent = "639${_parentController.text.trim()}";

      // 3. Auth Creation
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 4. Save to Database
      StudentModel student = StudentModel(
        uid: cred.user!.uid,
        fullName: combinedFullName,
        course: _selectedCourse!,
        studentID: formattedId,
        email: _emailController.text.trim(),
        parentContact: formattedParent,
      );

      // We add the specific fields to the map so your Admin app has clean data
      Map<String, dynamic> studentData = student.toMap();
      studentData['firstName'] = fName;
      studentData['middleName'] = mName;
      studentData['lastName'] = lName;
      studentData['suffix'] = suffix;
      studentData['sex'] = _selectedSex;
      studentData['role'] = 'student';
      studentData['status'] =
          'pending'; // Ensure they go to your Admin pending tab!
      studentData['isApproved'] = false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(studentData);

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2(), _buildStep3()],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Text(
            "Create Account",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),

          // --- ROW 1: First & Middle Name ---
          Row(
            children: [
              Expanded(
                child: _textField(
                  "First Name",
                  _firstNameController,
                  hint: "Juan",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "Middle Name",
                  _middleNameController,
                  hint: "Dela (Opt)",
                ),
              ),
            ],
          ),

          // --- ROW 2: Last Name & Suffix ---
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _textField(
                  "Last Name",
                  _lastNameController,
                  hint: "Cruz",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _textField("Suffix", _suffixController, hint: "Jr."),
              ),
            ],
          ),

          // --- SEX DROPDOWN ---
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: DropdownButtonFormField<String>(
              value: _selectedSex,
              decoration: _inputDecoration("Sex"),
              items: ["Male", "Female"]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedSex = val),
            ),
          ),

          // --- COURSE DROPDOWN ---
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: _inputDecoration("Course"),
              items: _courses
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCourse = val),
            ),
          ),

          // --- ID & CONTACT FIELDS (With Fixed Formatting) ---
          _textField(
            "Student ID",
            _idController,
            hint: "2024123456", // 10 digits typed
            prefix: "PDM-", // Prefix hardcoded
            isNumeric: true,
            maxLength: 10, // Limits to exactly 10 digits
          ),

          _textField("Email", _emailController, hint: "example@gmail.com"),

          _textField(
            "Parent Contact",
            _parentController,
            hint: "12345678", // 8 digits typed
            prefix: "639", // Prefix hardcoded
            isNumeric: true,
            maxLength: 8, // 3 prefix + 8 typed = 11 digits total
          ),

          // --- PASSWORD ---
          Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: _inputDecoration("Password").copyWith(
                hintText: "Min. 6 characters",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
          ),

          // --- CONTINUE BUTTON ---
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              if (_validateStep1()) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              }
            },
            child: const Text(
              "Continue",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REUSABLE UI HELPERS (Unchanged from your original design!)
  Widget _textField(
    String label,
    TextEditingController controller, {
    String? hint,
    String? prefix,
    bool isNumeric = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        maxLength: maxLength,
        decoration: _inputDecoration(label).copyWith(
          hintText: hint,
          prefixText: prefix,
          counterText: "", // Hides the 0/10 character counter text
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
    );
  }

  // Placeholder Step 2 & 3
  Widget _buildStep2() => Center(
    child: ElevatedButton(
      onPressed: _handleRegister,
      child: const Text("Submit"),
    ),
  );
  Widget _buildStep3() => const Center(child: Text("Verification Pending"));
}
