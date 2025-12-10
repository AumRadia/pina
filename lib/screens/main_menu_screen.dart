// lib/screens/main_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:pina/screens/landing.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/services/submission_service.dart';

class MainMenuScreen extends StatefulWidget {
  final String? userId; // <--- NEW FIELD
  final String? userName;
  final String? userEmail;

  const MainMenuScreen({
    super.key,
    this.userId, // <--- Add to constructor
    this.userName,
    this.userEmail,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final SubmissionService _submissionService = SubmissionService();
  bool _isLoading = false;

  final Map<String, List<String>> menu = {
    "Text": [
      "Text to Text",
      "Text to Image",
      "Text to Audio",
      "Text to Video",
      "Text to Multiple",
    ],
    "Image": [
      "Image to Text",
      "Image to Image",
      "Image to Audio",
      "Image to Video",
      "Image to Multiple",
    ],
    "Audio": [
      "Audio to Text",
      "Audio to Image",
      "Audio to Audio",
      "Audio to Video",
      "Audio to Multiple",
    ],
    "Video": [
      "Video to Text",
      "Video to Image",
      "Video to Audio",
      "Video to Video",
      "Video to Multiple",
    ],
    "Multiple": [
      "Multiple to Text",
      "Multiple to Image",
      "Multiple to Audio",
      "Multiple to Video",
      "Multiple to Multiple",
    ],
  };

  Future<void> _handleOptionClick(
    BuildContext context,
    String optionTitle,
  ) async {
    // CHECK 1: Local Null Check (Added userId)
    if (widget.userName == null ||
        widget.userEmail == null ||
        widget.userId == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // CHECK 2: Server-side Eligibility Check
    setState(() => _isLoading = true);

    final result = await _submissionService.checkUserEligibility(
      userEmail: widget.userEmail!,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LandingScreen(
            title: optionTitle,
            userId: widget.userId!, // <--- PASS USER ID
            userName: widget.userName!,
            userEmail: widget.userEmail!,
          ),
        ),
      );
    } else {
      if (!mounted) return;

      if (result.statusCode == 401) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? "Access Denied"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userName != null ? "Hi, ${widget.userName}" : "Main Menu",
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: menu.entries.map((entry) {
              return ExpansionTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: entry.value.map((sub) {
                  return ListTile(
                    title: Text(sub),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () => _handleOptionClick(context, sub),
                  );
                }).toList(),
              );
            }).toList(),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
