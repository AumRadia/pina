import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/registration.dart'; // Import Registration Screen
import 'package:pina/screens/trial.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- HIVE SETUP ---
  await Hive.initFlutter();
  await Hive.openBox('chat_storage_v2');

  // 1. Check for valid session
  final prefs = await SharedPreferences.getInstance();
  final String? userEmail = prefs.getString('userEmail');
  final String? userName = prefs.getString('userName');

  // 2. DETERMINE START SCREEN
  Widget startScreen;

  if (userEmail != null) {
    // If user is already logged in, go to Trial (Home) directly
    startScreen = Trial(userEmail: userEmail, userName: userName ?? "User");
  } else {
    // If no user is found, go to Registration
    startScreen = const Registration();
  }

  runApp(Mainapp(startScreen: startScreen));
}

class Mainapp extends StatelessWidget {
  final Widget startScreen;

  const Mainapp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: startScreen);
  }
}
