import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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

  // ==========================================
  // UPDATED LOGIN LOGIC (THE GATEKEEPER)
  // ==========================================
  Future<void> loginUser() async {
    if (_isLockedOut) return;

    String input = _identifierController.text.trim();
    String password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showError("Please enter your Student ID and Password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String emailToSignIn = "";

      // 1. ID LOOKUP: Check if input is email or ID
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

      // 3. FETCH USER DATA FOR GATEKEEPING
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc.get('role') ?? 'student';

        if (role == 'admin') {
          // Admins bypass gatekeeping
          _failedAttempts = 0;
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/admin_home');
        } else {
          // STUDENT GATEKEEPING LOGIC
          bool isActive = userDoc.get('isActive') ?? false;
          String status = userDoc.get('status') ?? '';

          if (isActive) {
            // ✅ SUCCESS: Student is active and cleared
            _failedAttempts = 0;
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/student_home');
          } else {
            // ❌ BLOCKED: Handle different inactive states
            await FirebaseAuth.instance.signOut();

            if (status == 'Pending') {
              _showError("Account Pending: Waiting for admin approval.");
            } else if (status == 'deactivated') {
              _showError("Account Deactivated: Please contact the PDM admin.");
            } else {
              _showError("Access Denied: Your account is currently disabled.");
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _startLockout();
        } else {
          String msg = "Invalid credentials. Attempt $_failedAttempts/3";
          if (e.code == 'user-not-found')
            msg = "ID not found. Attempt $_failedAttempts/3";
          if (e.code == 'wrong-password')
            msg = "Incorrect password. Attempt $_failedAttempts/3";
          _showError(msg);
        }
      });
    } catch (e) {
      _showError("System Error: Please try again later.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: Column(
            children: [
              // Logo Section
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
                        fontWeight: FontWeight.w500,
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
                            builder: (context) => const ForgotPasswordScreen(),
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
                      ? const CircularProgressIndicator(color: Colors.white)
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: _isLockedOut ? Colors.red.shade400 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkBrown, width: 1.5),
      ),
    );
  }
}
