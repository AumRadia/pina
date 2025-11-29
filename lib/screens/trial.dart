import 'package:flutter/material.dart';
import 'package:pina/models/news_article.dart';
import 'package:pina/screens/impact.dart';
import 'package:pina/screens/quickactions.dart';
import 'package:pina/screens/my_ai_screen.dart';
import 'package:pina/screens/secrets.dart'; // Ensure API Key is here
import 'package:pina/services/news_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/widgets/hamburger_menu.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

// --- ENUM FOR ACCORDION LOGIC ---
enum ActiveSection { none, title, desc, impact, action }

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

  // --- GLOBAL ACCORDION STATE ---
  String? _expandedArticleUrl;
  ActiveSection _expandedSection = ActiveSection.none;

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

  // Logic to handle expansion across ALL cards
  void _onSectionToggle(String url, ActiveSection section) {
    setState(() {
      if (_expandedArticleUrl == url && _expandedSection == section) {
        _expandedSection = ActiveSection.none;
        _expandedArticleUrl = null;
      } else {
        _expandedArticleUrl = url;
        _expandedSection = section;
      }
    });
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

                  final bool isThisCardActive =
                      _expandedArticleUrl == article.link;
                  final ActiveSection currentCardSection = isThisCardActive
                      ? _expandedSection
                      : ActiveSection.none;

                  return NewsCard(
                    key: ValueKey(article.link),
                    title: article.title,
                    desc: article.description.isNotEmpty
                        ? article.description
                        : "No description available.",
                    articleUrl: article.link,
                    userEmail: widget.userEmail, // <--- PASSED EMAIL HERE
                    bg: isEven ? Colors.blue.shade50 : Colors.purple.shade50,
                    border: isEven
                        ? Colors.blue.shade200
                        : Colors.purple.shade200,
                    titleColor: isEven
                        ? Colors.blue.shade900
                        : Colors.purple.shade900,
                    activeSection: currentCardSection,
                    onSectionChange: (section) =>
                        _onSectionToggle(article.link, section),
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
  final String userEmail; // <--- ADDED EMAIL FIELD
  final Color bg;
  final Color border;
  final Color titleColor;

  final ActiveSection activeSection;
  final Function(ActiveSection) onSectionChange;

  const NewsCard({
    super.key,
    required this.title,
    required this.desc,
    required this.articleUrl,
    required this.userEmail, // <--- REQUIRED
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.activeSection,
    required this.onSectionChange,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with AutomaticKeepAliveClientMixin {
  // AI Data
  String? _impactSummary;
  String? _actionSummary;
  bool _isFetched = false;
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  // Interaction State
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;

  @override
  bool get wantKeepAlive =>
      _isFetched || widget.activeSection != ActiveSection.none;

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

  // --- API CALLS ---

  // 1. Fetch AI Summary
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

  // 2. Log Interaction (Like, Share, etc.)
  Future<void> _logInteraction(String action) async {
    // NOTE: Use 10.0.2.2 for Android Emulator, 'localhost' for iOS Sim, or your PC's IP for physical device
    const String apiUrl = "http://10.74.182.23:4000/api/interactions/log";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userEmail": widget.userEmail,
          "newsId": widget.articleUrl,
          "action": action,
          "platform": "mobile",
        }),
      );

      if (response.statusCode == 200) {
        print("Logged $action successfully");
      } else {
        print("Failed to log $action: ${response.body}");
      }
    } catch (e) {
      print("Error logging interaction: $e");
    }
  }

  // --- Interaction Event Handlers ---

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _isDisliked = false;
        _logInteraction("like"); // Log API
      }
    });
  }

  void _toggleDislike() {
    setState(() {
      _isDisliked = !_isDisliked;
      if (_isDisliked) {
        _isLiked = false;
        _logInteraction("dislike"); // Log API
      }
    });
  }

  void _toggleSubscribe() {
    setState(() {
      _isSubscribed = !_isSubscribed;
    });
    // Log either subscribe or unsubscribe based on the new state
    _logInteraction(_isSubscribed ? "subscribe" : "unsubscribe");
  }

  void _handleShare() {
    final StringBuffer contentToShare = StringBuffer();
    contentToShare.writeln("堂 *${widget.title}*");
    contentToShare.writeln();
    contentToShare.writeln("迫 ${widget.articleUrl}");

    if (_impactSummary != null && _impactSummary!.isNotEmpty) {
      contentToShare.writeln();
      contentToShare.writeln("､*AI Impact Analysis:*");
      contentToShare.writeln(_impactSummary);
    }

    if (_actionSummary != null && _actionSummary!.isNotEmpty) {
      contentToShare.writeln();
      contentToShare.writeln("噫 *Quick Actions:*");
      contentToShare.writeln(_actionSummary);
    }

    // 1. Trigger Native Share
    Share.share(contentToShare.toString());

    // 2. Log to Backend
    _logInteraction("share");
  }

  void _handleStickToExpert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Stick to Expert feature coming soon!")),
    );
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
              isExpanded: widget.activeSection == ActiveSection.title,
              wordLimit: 25,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.titleColor,
              ),
              onExpand: () => widget.onSectionChange(ActiveSection.title),
            ),

            const SizedBox(height: 8),

            // 2. DESCRIPTION
            ControllableSmartText(
              text: widget.desc,
              isExpanded: widget.activeSection == ActiveSection.desc,
              wordLimit: 25,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              onExpand: () => widget.onSectionChange(ActiveSection.desc),
            ),

            const Divider(height: 16),

            // 3. IMPACT SECTION
            _buildSectionHeader("Impact Summary:"),
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_error != null)
              _buildErrorText()
            else if (_impactSummary != null)
              ControllableSmartText(
                text: _impactSummary!,
                isExpanded: widget.activeSection == ActiveSection.impact,
                wordLimit: 25,
                style: const TextStyle(fontSize: 15, height: 1.4),
                onExpand: () => widget.onSectionChange(ActiveSection.impact),
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
                isExpanded: widget.activeSection == ActiveSection.action,
                wordLimit: 25,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.black87,
                ),
                onExpand: () => widget.onSectionChange(ActiveSection.action),
                extraContent: _buildNavButton(
                  "Show All Actions",
                  Colors.green.shade700,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuickActionScreen(
                        articleUrl: widget.articleUrl,
                        title: widget.title,
                        description: widget.desc,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const Divider(),

            // --- ACTION BUTTONS ROW (Like, Dislike, Share, Subscribe) ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. LIKE
                  InkWell(
                    onTap: _toggleLike,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 12.0,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Icon(
                        _isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                        color: _isLiked ? Colors.blue : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                  ),

                  // 2. DISLIKE
                  InkWell(
                    onTap: _toggleDislike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8,
                      ),
                      child: Icon(
                        _isDisliked
                            ? Icons.thumb_down
                            : Icons.thumb_down_off_alt,
                        color: _isDisliked
                            ? Colors.black
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                  ),

                  // 3. SHARE
                  InkWell(
                    onTap: _handleShare,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.share,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                  ),

                  // SPACER
                  const SizedBox(width: 16),

                  // 4. SUBSCRIBE BUTTON
                  GestureDetector(
                    onTap: _toggleSubscribe,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isSubscribed
                            ? Colors.grey.shade300
                            : widget.titleColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isSubscribed
                              ? Colors.grey
                              : widget.titleColor,
                        ),
                      ),
                      child: Text(
                        _isSubscribed ? "Subscribed" : "Subscribe",
                        style: TextStyle(
                          color: _isSubscribed
                              ? Colors.grey.shade700
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- STICK TO EXPERT ---
            Center(
              child: ElevatedButton(
                onPressed: _handleStickToExpert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  "Stick to Expert",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
  final VoidCallback onExpand;

  const ControllableSmartText({
    super.key,
    required this.text,
    required this.isExpanded,
    required this.onExpand,
    this.wordLimit = 25,
    this.style,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    final isLong = words.length > wordLimit;

    if (isExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: style),
          if (extraContent != null) extraContent!,
        ],
      );
    }

    if (isLong) {
      final truncatedText = "${words.take(wordLimit).join(' ')}...";
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(truncatedText, style: style),
          GestureDetector(
            onTap: onExpand,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
              child: Text(
                "More",
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Text(text, style: style);
  }
}
