import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- HIVE SETUP ---
  await Hive.initFlutter();
  await Hive.openBox('chat_storage_v2');

  // 1. Check for valid session
  final prefs = await SharedPreferences.getInstance();

  // Note: We handle userId as nullable. If it's an int in prefs, we convert to String.
  final int? userIdInt = prefs.getInt('userId');
  final String? userName = prefs.getString('userName');
  final String? userEmail = prefs.getString('userEmail');

  // Convert int ID to String for consistency with the rest of the app
  final String? userId = userIdInt?.toString();

  // 2. PASS USER ID HERE
  Widget startScreen = MainMenuScreen(
    userName: userName,
    userEmail: userEmail,
    userId: userId, // <--- FIXED: Passing the ID
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
