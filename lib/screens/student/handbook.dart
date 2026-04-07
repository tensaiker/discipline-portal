import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HandbookScreen extends StatelessWidget {
  const HandbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Handbook", style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF4E342E),
      ),
      body: const Center(child: Text("University Policies and Guidelines")),
    );
  }
}
