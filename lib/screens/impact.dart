import 'package:flutter/material.dart';

// Simple detail screen that renders the impact analysis returned from OpenAI.
class ImpactAnalysisScreen extends StatelessWidget {
  final String analysisText; // Pre-computed AI summary.

  const ImpactAnalysisScreen({super.key, required this.analysisText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impact Analysis"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            analysisText,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5, // Better readability
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
