import 'package:flutter/material.dart';
import 'package:pina/models/news_article.dart';
import 'package:pina/screens/impact.dart';
import 'package:pina/screens/quickactions.dart'; // IMPORT ADDED
import 'package:pina/screens/my_ai_screen.dart';
import 'package:pina/screens/secrets.dart'; // Ensure API Key is here
import 'package:pina/services/news_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/widgets/hamburger_menu.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:visibility_detector/visibility_detector.dart';

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
  String _currentLanguage = 'English';

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
        title: const Text("News Feed", style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyAiScreen(
                      userName: widget.userName,
                      userEmail: widget.userEmail,
                    ),
                  ),
                );
              },
              // icon: const Icon(Icons.smart_toy, color: Colors.white),
              label: const Text(
                "My Ai",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchNewsData,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                itemCount: articles.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final bool isEven = index % 2 == 0;

                  return NewsCard(
                    key: ValueKey(article.link),
                    title: article.title,
                    desc: article.description.isNotEmpty
                        ? article.description
                        : "No description available.",
                    articleUrl: article.link,
                    bg: isEven ? Colors.blue.shade50 : Colors.purple.shade50,
                    border: isEven
                        ? Colors.blue.shade200
                        : Colors.purple.shade200,
                    titleColor: isEven
                        ? Colors.blue.shade900
                        : Colors.purple.shade900,
                  );
                },
              ),
            ),
    );
  }
}

// --- NEWS CARD ---
class NewsCard extends StatefulWidget {
  final String title;
  final String desc;
  final String articleUrl;
  final Color bg;
  final Color border;
  final Color titleColor;

  const NewsCard({
    super.key,
    required this.title,
    required this.desc,
    required this.articleUrl,
    required this.bg,
    required this.border,
    required this.titleColor,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with AutomaticKeepAliveClientMixin {
  // Independent States for expansion
  bool _titleExpanded = false;
  bool _descExpanded = false;
  bool _impactExpanded = false;
  bool _actionExpanded = false;

  // Data Storage
  String? _impactSummary;
  String? _actionSummary;

  bool _isFetched = false;
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => _isFetched || _titleExpanded || _descExpanded;

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (_isFetched || _isLoading) return;
    if (info.visibleFraction > 0.6) {
      _debounceTimer ??= Timer(const Duration(milliseconds: 200), () {
        _fetchAiData();
        _debounceTimer = null;
      });
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = null;
    }
  }

  // Optimized API Call: Fetches Impact AND Action summaries together
  Future<void> _fetchAiData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    const String splitMarker = "|||";

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "max_tokens": 600,
          "messages": [
            {
              "role": "user",
              // FIXED: Now uses Title and Desc
              "content":
                  "Analyze this news event:\n"
                  "HEADLINE: ${widget.title}\n"
                  "CONTEXT: ${widget.desc}\n\n"
                  "TASK: Provide two short summaries separated by '$splitMarker'.\n"
                  "1. Impact Summary (approx 5-6 lines).\n"
                  "2. Quick Action Summary (approx 5-6 lines).\n\n"
                  "FORMAT: [Impact Text] $splitMarker [Action Text]",
            },
          ],
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
          String content = data['choices'][0]['message']['content'];
          List<String> parts = content.split(splitMarker);

          setState(() {
            _impactSummary = parts[0].trim();
            _actionSummary = parts.length > 1
                ? parts[1].trim()
                : "Action analysis unavailable.";
            _isFetched = true;
            _isLoading = false;
          });
          updateKeepAlive();
          return;
        }
      }
      setState(() {
        _error = "Analysis unavailable.";
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Network error.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return VisibilityDetector(
      key: widget.key!,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.border, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TITLE
            ControllableSmartText(
              text: widget.title,
              isExpanded: _titleExpanded,
              wordLimit: 25,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.titleColor,
              ),
              onToggle: () => setState(() => _titleExpanded = !_titleExpanded),
            ),
            const SizedBox(height: 8),

            // 2. DESCRIPTION
            ControllableSmartText(
              text: widget.desc,
              isExpanded: _descExpanded,
              wordLimit: 25,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              onToggle: () => setState(() => _descExpanded = !_descExpanded),
            ),

            const Divider(height: 24),

            // 3. IMPACT SECTION
            _buildSectionHeader("Impact Summary:"),
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_error != null)
              _buildErrorText()
            else if (_impactSummary != null)
              ControllableSmartText(
                text: _impactSummary!,
                isExpanded: _impactExpanded,
                wordLimit: 25,
                style: const TextStyle(fontSize: 15, height: 1.4),
                onToggle: () =>
                    setState(() => _impactExpanded = !_impactExpanded),
                extraContent: _buildNavButton(
                  "Show Full Impact Analysis",
                  Colors.deepPurple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImpactAnalysisScreen(
                        articleUrl: widget.articleUrl,
                        title: widget.title,
                        description: widget.desc,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 4. QUICK ACTION SECTION
            _buildSectionHeader("Quick Actions:"),
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_actionSummary != null)
              ControllableSmartText(
                text: _actionSummary!,
                isExpanded: _actionExpanded,
                wordLimit: 25,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.black87,
                ),
                onToggle: () =>
                    setState(() => _actionExpanded = !_actionExpanded),
                extraContent: _buildNavButton(
                  "Show All Actions",
                  Colors.green.shade700,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      // FIXED: Passes Title/Desc correctly
                      builder: (context) => QuickActionScreen(
                        articleUrl: widget.articleUrl,
                        title: widget.title,
                        description: widget.desc,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.titleColor,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "AI is analyzing...",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildErrorText() {
    return Text(
      _error!,
      style: const TextStyle(color: Colors.red, fontSize: 12),
    );
  }

  Widget _buildNavButton(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// --- CONTROLLABLE SMART TEXT (Reusable) ---
class ControllableSmartText extends StatelessWidget {
  final String text;
  final int wordLimit;
  final TextStyle? style;
  final Widget? extraContent;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ControllableSmartText({
    super.key,
    required this.text,
    required this.isExpanded,
    required this.onToggle,
    this.wordLimit = 25,
    this.style,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    final isLong = words.length > wordLimit;

    final String displayedText = (!isExpanded && isLong)
        ? "${words.take(wordLimit).join(' ')}..."
        : text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayedText, style: style),
        if (isLong)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
              child: Text(
                isExpanded ? "Show Less" : "More",
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (isExpanded && extraContent != null) extraContent!,
      ],
    );
  }
}
