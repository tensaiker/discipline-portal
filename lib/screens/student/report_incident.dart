import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReportIncident extends StatefulWidget {
  const ReportIncident({super.key});

  @override
  State<ReportIncident> createState() => _ReportIncidentState();
}

class _ReportIncidentState extends State<ReportIncident> {
  final _detailsController = TextEditingController();
  String? _selectedViolation;
  DateTime? _pickedDate;
  bool _isSubmitting = false;

  final Color _darkBrown = const Color(0xFF4A3424);
  final Color _bgColor = const Color(0xFFF9F7F2);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _darkBrown,
              onPrimary: Colors.white,
              onSurface: _darkBrown,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _darkBrown),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _pickedDate) {
      setState(() => _pickedDate = picked);
    }
  }

  Future<void> _submitReport() async {
    if (_selectedViolation == null ||
        _detailsController.text.trim().isEmpty ||
        _pickedDate == null) {
      _showSnackBar("Please fill out all fields and select a date.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Fetch the latest user profile data
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("User profile not found. Please log out and back in.");
      }

      // Convert to Map to prevent "Bad State" errors
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      String formattedDate = DateFormat('MMMM d, yyyy').format(_pickedDate!);

      // 2. SAVE TO DATABASE
      await FirebaseFirestore.instance.collection('violations').add({
        'studentUid': null, // This is NOT your violation
        'reporterUid': user.uid, // This IS your report
        // Use the EXACT names from your Firestore screenshot
        'reporterName': userData['fullName'] ?? "Unknown Name",
        'reporterID': userData['studentID'] ?? "N/A",

        'type': _selectedViolation,
        'description': _detailsController.text.trim(),
        'date': formattedDate,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _detailsController.clear();
      setState(() {
        _selectedViolation = null;
        _pickedDate = null;
      });
      _showSnackBar("Report submitted successfully!", isSuccess: true);
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Report Incident',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _darkBrown,
                ),
              ),
              const SizedBox(height: 35),

              const Text(
                'Choose a violation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedViolation,
                decoration: _inputDecoration("Select violation"),
                items:
                    [
                          'Bullying',
                          'Vandalism',
                          'Cheating',
                          'Uniform Violation',
                          'Smoking',
                          'Alcohol',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (val) => setState(() => _selectedViolation = val),
              ),

              const SizedBox(height: 25),

              const Text(
                'Date of Incident:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _pickedDate == null
                            ? "Tap to choose date"
                            : DateFormat('MMMM d, yyyy').format(_pickedDate!),
                        style: TextStyle(
                          color: _pickedDate == null
                              ? Colors.grey
                              : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                      Icon(Icons.calendar_month, color: _darkBrown),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Violation details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 5,
                decoration: _inputDecoration("Describe the incident..."),
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkBrown),
      ),
    );
  }
}
