import 'package:flutter/material.dart';
import 'package:pina/screens/loginscreen.dart';

import 'package:pina/screens/main_menu_screen.dart';

void main() async {
  // Ensure Flutter services (such as Google Sign-In) are ready before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const Mainapp());
}

class Mainapp extends StatelessWidget {
  const Mainapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(), // Entry point of the flow.
    );
  }
}
