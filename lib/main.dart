import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <--- 1. Import Hive
import 'package:pina/screens/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- HIVE SETUP START ---
  await Hive.initFlutter(); // 2. Initialize Hive
  await Hive.openBox('chat_storage_v2'); // 3. Open the box (database)
  // --- HIVE SETUP END ---

  // 1. Check for valid session
  final prefs = await SharedPreferences.getInstance();

  final int? userId = prefs.getInt('userId');
  final String? userName = prefs.getString('userName');
  final String? userEmail = prefs.getString('userEmail');

  Widget startScreen = MainMenuScreen(userName: userName, userEmail: userEmail);

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
