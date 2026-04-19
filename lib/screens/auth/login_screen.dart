import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // LOCKOUT LOGIC
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  int _secondsRemaining = 0;
  Timer? _lockoutTimer;

  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _bgColor = const Color(0xFFF9F7F2);

  // ✅ Your Live Ngrok URL for the PDM Presentation
  final String _apiBaseUrl =
      "https://railway-hurray-uncurled.ngrok-free.dev/pdm_admin";

  void _startLockout() {
    setState(() {
      _isLockedOut = true;
      _secondsRemaining = 60;
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _isLockedOut = false;
            _failedAttempts = 0;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (_isLockedOut) return;

    String input = _identifierController.text.trim();
    String password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showError("Please enter your credentials.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String emailToSignIn = "";

      // 1. ID LOOKUP
      if (input.contains('@')) {
        emailToSignIn = input;
      } else {
        var userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('studentID', isEqualTo: input)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'ID not found.',
          );
        }
        emailToSignIn = userQuery.docs.first.get('email');
      }

      // 2. FIREBASE SIGN IN
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailToSignIn, password: password);

      if (!mounted) return;

      // 3. FETCH USER DATA
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) throw "User profile not found in database.";

      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      String role = data['role']?.toString().toLowerCase() ?? 'student';

      if (role == 'admin') {
        _failedAttempts = 0;
        _navigateSafe('/admin_home');
      } else {
        // --- STUDENT GATEKEEPING LOGIC ---
        String studentID = data['studentID'] ?? '';
        bool isActive = data['isActive'] ?? false;

        if (studentID.isEmpty) throw "Student ID missing in profile.";

        // 🛡️ MYSQL MASTER LIST SECURITY CHECK
        final response = await http
            .get(
              Uri.parse("$_apiBaseUrl/check_status.php?student_id=$studentID"),
              headers: {
                "ngrok-skip-browser-warning": "true",
                "Accept": "application/json",
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final mysqlData = json.decode(response.body);

          if (mysqlData['status'] == 'Active' && isActive) {
            _failedAttempts = 0;
            _navigateSafe('/student_home');
          } else {
            await FirebaseAuth.instance.signOut();
            _showError("Access Denied: Account is disabled or pending.");
          }
        } else {
          throw "Unable to reach Master List server.";
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _failedAttempts++;
          if (_failedAttempts >= 3) {
            _startLockout();
          } else {
            String msg = "Invalid credentials. Attempt $_failedAttempts/3";
            if (e.code == 'user-not-found') msg = "ID not found.";
            if (e.code == 'wrong-password') msg = "Incorrect password.";
            _showError(msg);
          }
        });
      }
    } catch (e) {
      _showError("System Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // A safe navigation helper to prevent GPU crashes during transitions
  void _navigateSafe(String route) async {
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Tiny delay to let the UI stabilize before pushing a new route
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        // Ensures content doesn't hit the status bar
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _darkBrown,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.amber,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Discipline Portal",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  "Violation & Handbook Management",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 50),
                _buildInputLabel("Student ID / Email"),
                TextField(
                  controller: _identifierController,
                  enabled: !_isLockedOut,
                  decoration: _inputDecoration("e.g. PDM-2024-000001"),
                ),
                if (_isLockedOut)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Locked out. Try again in $_secondsRemaining seconds.",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildInputLabel("Password"),
                TextField(
                  controller: _passwordController,
                  enabled: !_isLockedOut,
                  obscureText: !_isPasswordVisible,
                  decoration: _inputDecoration(
                    "********",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: _isLockedOut
                          ? null
                          : () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLockedOut
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          ),
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: _isLockedOut ? Colors.grey : Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLockedOut
                          ? Colors.grey.shade400
                          : _darkBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_isLoading || _isLockedOut) ? null : loginUser,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLockedOut ? "LOCKED" : "Sign In",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "New student? ",
                      style: TextStyle(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: _isLockedOut
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            ),
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          color: _isLockedOut ? Colors.grey : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _isLockedOut ? const Color(0xFFFFF5F5) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkBrown, width: 1.5),
      ),
    );
  }
}
