import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ensure this matches your file name
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/student/student_main_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This tells Flutter which Firebase project to connect to
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // This is the "Engine Start" button for your app
  runApp(const DisciplineApp());
}

class DisciplineApp extends StatelessWidget {
  const DisciplineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin_home': (context) => const AdminDashboard(),
        '/student_home': (context) => const StudentMainWrapper(),
      },
    );
  }
}
