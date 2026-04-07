import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Place your asset image here
            Image.asset('assets/images/brain_char.png', height: 150),
            const SizedBox(height: 20),
            Text(
              "Forgot Password?",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const Text(
              "Please write your email to receive a confirmation code to set a new password",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const TextField(
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {}, // Navigate to Code Verification
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF4E342E,
                ), // Brown from image_08af88.png
                minimumSize: const Size(double.infinity, 55),
              ),
              child: const Text(
                "Confirm Mail",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
