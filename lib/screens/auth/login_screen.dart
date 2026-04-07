import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Required for Timer
import 'register_screen.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // LOCKOUT LOGIC VARIABLES
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
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _isLockedOut = false;
          _failedAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (_isLockedOut) return;

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc.get('role');
        _failedAttempts = 0;

        if (role == 'admin') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/admin_home');
        } else if (role == 'student') {
          bool isApproved = userDoc.get('isApproved') ?? false;
          if (isApproved) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/student_home');
          } else {
            await FirebaseAuth.instance.signOut();
            _showError("Your account is pending admin approval.");
          }
        }
      }
    } catch (e) {
      setState(() {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _startLockout();
        } else {
          _showError("Invalid credentials. Attempt $_failedAttempts/3");
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
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

              // 1. EMAIL FIELD
              _buildInputLabel("Email/Student ID"),
              TextField(
                controller: _emailController,
                enabled: !_isLockedOut,
                decoration: _inputDecoration("example@gmail.com"),
              ),

              // 2. TIMER MESSAGE (Directly under the Email Field)
              if (_isLockedOut)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Too many failed attempts. Try again in $_secondsRemaining seconds.",
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // 3. PASSWORD FIELD
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
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
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

              // 4. SIGN IN BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLockedOut
                        ? Colors.grey.shade400
                        : _darkBrown,
                    disabledBackgroundColor: Colors.grey.shade400,
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
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
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
      // If locked, background stays slightly red/white as per your screenshot
      fillColor: _isLockedOut ? const Color(0xFFFFF5F5) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),

      // THE RED BORDER LOGIC
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
