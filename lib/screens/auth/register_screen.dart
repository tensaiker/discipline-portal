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

  // Controllers
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentController = TextEditingController();
  final _passwordController = TextEditingController();

  // State Variables
  String? _selectedCourse;
  bool _isPasswordVisible = false;
  final List<String> _courses = [
    "BS Information Technology",
    "BS Computer Science",
    "BCED",
  ];

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _yellow = const Color(0xFFFFC107);

  // ==========================================
  // NEW: VALIDATION LOGIC
  // ==========================================
  bool _validateStep1() {
    // 1. Full Name Check
    if (_nameController.text.trim().isEmpty) {
      _showValidationError("Full Name");
      return false;
    }
    // 2. Course Check
    if (_selectedCourse == null) {
      _showValidationError("Course");
      return false;
    }
    // 3. Student ID Check (Expecting XXXX-XXXXXX = 11 characters)
    if (_idController.text.length < 11) {
      _showValidationError("Student ID");
      return false;
    }
    // 4. Email Check (Basic format check)
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _showValidationError("Email");
      return false;
    }
    // 5. Parent Contact Check (Must be 12 digits)
    if (_parentController.text.length != 12) {
      _showValidationError("Parent Contact");
      return false;
    }
    // 6. Password Check (Minimum 6 characters)
    if (_passwordController.text.length < 6) {
      _showValidationError("Password");
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
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      StudentModel student = StudentModel(
        uid: cred.user!.uid,
        fullName: _nameController.text.trim(),
        course: _selectedCourse!,
        studentID: "PDM-${_idController.text.trim()}",
        email: _emailController.text.trim(),
        parentContact: _parentController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set(student.toMap());

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
          _textField("Full Name", _nameController, hint: "Juan Dela Cruz"),

          // Dropdown
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

          _textField(
            "Student ID (Numbers Only)",
            _idController,
            hint: "2026-000000",
            prefix: "PDM-",
            isNumeric: true,
            maxLength: 11,
          ),
          _textField("Email", _emailController, hint: "example@gmal.com"),
          _textField(
            "Parent Contact",
            _parentController,
            hint: "639XXXXXXXXX",
            isNumeric: true,
            maxLength: 12,
          ),

          // Password
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

          // CONTINUE BUTTON
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // ONLY go to next page if validation is true
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

  // REUSABLE UI HELPERS
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
        decoration: _inputDecoration(
          label,
        ).copyWith(hintText: hint, prefixText: prefix, counterText: ""),
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
