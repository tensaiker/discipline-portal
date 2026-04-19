import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/student/student_main_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("--- DEBUG: Firebase Success! ---");
  } catch (e) {
    print("--- DEBUG: Firebase Error: $e ---");
  }

  runApp(const DisciplineApp());
}

class DisciplineApp extends StatelessWidget {
  const DisciplineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDM Discipline Portal',

      // 1. FORCING THE GPU: 'home' tells the phone to draw the LoginScreen immediately.
      home: const LoginScreen(),

      // 2. THE MAP: This allows Navigator.pushReplacementNamed to find your other screens.
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin_home': (context) => const AdminDashboard(),
        '/student_home': (context) => const StudentMainWrapper(),
      },
    );
  }
}
