import 'package:flutter/material.dart';
import 'package:pina/models/news_article.dart';
import 'package:pina/screens/impact.dart';
import 'package:pina/screens/my_ai_screen.dart';
import 'package:pina/screens/secrets.dart';
import 'package:pina/services/news_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/widgets/hamburger_menu.dart';
import 'dart:convert'; // <--- NEW: For JSON encoding/decoding
import 'package:http/http.dart' as http; // <--- NEW: For API calls
import 'dart:async';

class Trial extends StatefulWidget {
  final String userName;
  final String userEmail;

  const Trial({super.key, this.userName = "User", required this.userEmail});

  @override
  State<Trial> createState() => _TrialState();
}

class _TrialState extends State<Trial> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<NewsArticle> articles = [];
  bool isLoading = true;
  int expandedindex = -1; // Tracks which article description is expanded.

  String _currentLanguage = 'English';

  final String staticDesc =
      "Microsoft AI CEO Mustafa Suleyman has highlighted...";

  @override
  void initState() {
    super.initState();
    fetchNewsData();
  }

  Future<void> fetchNewsData() async {
    try {
      final data = await Apiservice().fetchNews();
      if (mounted) {
        setState(() {
          articles = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading news: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // <--- NEW: Function to call AI and show dialog
  // ... inside _TrialState class ...

  Future<void> _showImpactAnalysis(
    BuildContext context,
    String articleUrl,
  ) async {
    // 1. Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    String aiResponse = "";

    try {
      // 2. Call the Groq API (FREE)
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $groqApiKey',
            },
            body: jsonEncode({
              "model": "llama-3.1-8b-instant",
              "messages": [
                {
                  "role": "user",
                  "content":
                      "Analyze and tell me the impact analysis of this news in short on all stakeholders. Source: $articleUrl",
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              throw TimeoutException("AI API timed out. Please retry.");
            },
          );

      // Close the loading indicator
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiResponse = data['choices'][0]['message']['content'];
      } else {
        aiResponse = "Failed to get analysis. Status: ${response.statusCode}";
      }
    } catch (e) {
      // Close loading indicator on error
      if (mounted) Navigator.pop(context);
      aiResponse = "Error connecting to AI: $e";
    }

    // 3. Navigate to the New Screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImpactAnalysisScreen(analysisText: aiResponse),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: HamburgerMenu(
        userName: widget.userName,
        onLogout: _handleLogout,
        selectedLanguage: _currentLanguage,
        onLanguageChanged: (newLanguage) {
          setState(() => _currentLanguage = newLanguage);
          Navigator.pop(context);
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyAiScreen(
                      userName: widget.userName,
                      userEmail: widget.userEmail,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "MyAi",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.separated(
                itemCount: articles.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final bool isEven = index % 2 == 0;
                  return buildNewsCard(
                    index: index,
                    title: article.title,
                    desc: staticDesc,
                    // <--- NEW: Pass the real URL from your model
                    // Ensure your NewsArticle model has a 'url' field.
                    // If it is named 'sourceUrl', change it below.
                    articleUrl: article.link,
                    bg: isEven ? Colors.blue.shade100 : Colors.purple.shade100,
                    border: isEven
                        ? Colors.blue.shade300
                        : Colors.purple.shade300,
                    titleColor: isEven
                        ? Colors.blue.shade900
                        : Colors.purple.shade900,
                    btnColor: isEven
                        ? Colors.blue.shade700
                        : Colors.purple.shade700,
                  );
                },
              ),
            ),
    );
  }

  Widget buildNewsCard({
    required String title,
    required String desc,
    required String articleUrl, // <--- NEW: Accept URL
    required Color bg,
    required Color border,
    required Color titleColor,
    required Color btnColor,
    required int index,
  }) {
    bool isexapanded = expandedindex == index;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          ExpandableText(
            text: desc,
            expanded: isexapanded,
            onToggle: () {
              setState(() {
                expandedindex = isexapanded ? -1 : index;
              });
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              // <--- NEW: OnPressed Logic
              onPressed: () {
                _showImpactAnalysis(context, articleUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Show Impact',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Quick Action',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpandableText extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const ExpandableText({
    super.key,
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            expanded ? "Show Less" : "More",
            style: TextStyle(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
