import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LogViolationDialog extends StatefulWidget {
  const LogViolationDialog({super.key});

  @override
  State<LogViolationDialog> createState() => _LogViolationDialogState();
}

class _LogViolationDialogState extends State<LogViolationDialog> {
  // Controllers
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _courseController = TextEditingController();
  final _descController = TextEditingController();

  // Internal State
  String? _selectedViolation;
  String? _targetStudentUid;
  String? _gender;
  bool _isSearching = false;
  bool _isSaving = false;

  // Your Design Theme
  final Color _darkBrown = const Color(0xFF513C2C);
  final Color _cardColor = const Color(0xFFF9F7F2);

  @override
  void initState() {
    super.initState();
    // This listens to every character typed in the Student ID field
    _idController.addListener(_onIdChanged);
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _courseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- 1. AUTO-FILL LOGIC ---
  void _onIdChanged() {
    String input = _idController.text.trim();
    // Trigger search when ID looks complete (e.g., PDM-2023-000000 is 15 chars)
    if (input.length == 15 && !_isSearching) {
      _fetchStudentData(input);
    }
  }

  Future<void> _fetchStudentData(String studentID) async {
    setState(() => _isSearching = true);
    try {
      var result = await FirebaseFirestore.instance
          .collection('users')
          .where('studentID', isEqualTo: studentID)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        var userData = result.docs.first.data();
        setState(() {
          _nameController.text = userData['fullName'] ?? "";
          _courseController.text = userData['course'] ?? "";
          _gender = userData['sex'] ?? "N/A";
          _targetStudentUid = userData['uid'];
        });
      } else {
        // Clear if ID is not found
        _clearAutoFields();
      }
    } catch (e) {
      print("Search Error: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _clearAutoFields() {
    _nameController.clear();
    _courseController.clear();
    _targetStudentUid = null;
    _gender = null;
  }

  // --- 2. SAVE LOGIC (Updates both Student & Admin Dashboards) ---
  Future<void> _saveViolation() async {
    if (_targetStudentUid == null || _selectedViolation == null) {
      _showSnackBar(
        "Please enter a valid Student ID and select a violation type.",
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Step A: Log the record in 'violations' (For Admin lists and Student Alerts)
      await FirebaseFirestore.instance.collection('violations').add({
        'studentUid': _targetStudentUid,
        'studentID': _idController.text.trim(),
        'studentName': _nameController.text,
        'gender': _gender ?? "N/A",
        'type': _selectedViolation,
        'description': _descController.text.trim(),
        'status': 'approved', // Logged by admin = automatically approved
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateFormat('MMMM d, yyyy').format(DateTime.now()),
      });

      // Step B: Update the Student's status in 'users' (Turns their Home Screen Banner RED)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetStudentUid)
          .update({
            'status': 'violations',
            'activeViolation': _selectedViolation,
          });

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      _showSnackBar("Violation logged successfully!", isError: false);
    } catch (e) {
      _showSnackBar("Failed to save violation: $e", isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Log New Violation",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Form Fields
            _buildLabel("Student ID"),
            TextField(
              controller: _idController,
              decoration: _inputDecoration(
                "e.g. PDM-2023-000000",
                suffix: _isSearching
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),

            _buildLabel("Student Name"),
            TextField(
              controller: _nameController,
              readOnly: true,
              decoration: _inputDecoration("Auto-filled"),
            ),

            _buildLabel("Violation Type"),
            DropdownButtonFormField<String>(
              value: _selectedViolation,
              decoration: _inputDecoration("Select"),
              items: [
                "Bullying",
                "Cheating",
                "Vandalism",
                "Uniform Violation",
                "Smoking",
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedViolation = val),
            ),

            _buildLabel("Description"),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: _inputDecoration("Additional details..."),
            ),

            const SizedBox(height: 35),

            // Action Button
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
                onPressed: _isSaving ? null : _saveViolation,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Violation",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE UI HELPERS ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.all(12), child: suffix)
          : null,
      filled: true,
      fillColor: _cardColor.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkBrown, width: 1.5),
      ),
    );
  }
}
