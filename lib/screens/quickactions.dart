import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pina/screens/secrets.dart'; // Ensure this points to your API Key

class QuickActionScreen extends StatefulWidget {
  final String articleUrl;
  final String title;
  final String description;

  const QuickActionScreen({
    super.key,
    required this.articleUrl,
    required this.title,
    required this.description,
  });

  @override
  State<QuickActionScreen> createState() => _QuickActionScreenState();
}

class _QuickActionScreenState extends State<QuickActionScreen> {
  String? _actionText;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFullActions();
  }

  Future<void> _fetchFullActions() async {
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "max_tokens": 1500, // Large limit for detailed steps
          "messages": [
            {
              "role": "user",
              // FIXED: Uses title and description instead of URL
              "content":
                  "Analyze this news event:\n"
                  "HEADLINE: ${widget.title}\n"
                  "DETAILS: ${widget.description}\n\n"
                  "TASK: Create a comprehensive 'Action Plan' based on this news.\n"
                  "OUTPUT FORMAT:\n"
                  "1. Immediate Actions (Do this now)\n"
                  "2. Long-term Strategy (Plan for later)\n"
                  "3. Key Risks to Watch\n\n"
                  "Use bullet points and clear, professional language.",
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
          String content = data['choices'][0]['message']['content'];
          if (mounted) {
            setState(() {
              _actionText = content.trim();
              _isLoading = false;
            });
          }
        } else {
          throw Exception("Empty response from AI");
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              "Could not generate action plan. Please check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Action Plan"),
        // Green theme to differentiate from Impact Analysis (Blue)
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green.shade700),
                    const SizedBox(height: 16),
                    Text(
                      "Consulting Strategist AI...",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _fetchFullActions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Text(
                  _actionText!,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6, // Good line height for reading lists
                    color: Colors.black87,
                  ),
                ),
              ),
      ),
    );
  }
}
