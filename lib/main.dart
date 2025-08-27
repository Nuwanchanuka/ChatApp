import 'package:chatapp/screens/new_home_screen.dart';
import 'package:chatapp/screens/profile_setup_screen.dart';
import 'package:chatapp/services/settings.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF075E54),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
        ).copyWith(
          secondary: Color(0xFF128C7E), // replaces accentColor
        ),
      ),
      home: SettingsService().hasUsername ? const NewHomeScreen() : const ProfileSetupScreen(),
    );
  }
}
