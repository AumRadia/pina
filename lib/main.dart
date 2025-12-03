import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import MainMenuScreen
import 'package:pina/screens/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Check for valid session
  final prefs = await SharedPreferences.getInstance();

  final int? userId = prefs.getInt('userId');
  final String? userName = prefs.getString('userName');
  final String? userEmail = prefs.getString('userEmail');

  // 2. ALWAYS start at MainMenuScreen
  // We pass the user details if they exist, otherwise null (indicating guest/logged out)
  Widget startScreen = MainMenuScreen(
    userName: userName, // Can be null
    userEmail: userEmail, // Can be null
  );

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
