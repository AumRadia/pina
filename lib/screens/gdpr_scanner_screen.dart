import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import this

class GDPRScannerScreen extends StatefulWidget {
  const GDPRScannerScreen({super.key});

  @override
  State<GDPRScannerScreen> createState() => _GDPRScannerScreenState();
}

class _GDPRScannerScreenState extends State<GDPRScannerScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  // Variable to store the real logged-in User ID
  int? _currentUserId;

  // TODO: Replace with your actual Server URL
  // Android Emulator: 'http://10.0.2.2:4000'
  // Real Device: 'http://192.168.x.x:4000' (Your PC's local IP)
  // Deployed: 'https://your-app.vercel.app'
  final String _baseUrl = "http://10.187.191.23:4000";

  @override
  void initState() {
    super.initState();
    _loadUserData(); // <--- 1. Load User ID when screen opens
  }

  /// Retrieve the User ID stored by LoginScreen
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Debug: Print ALL stored keys and values
    print("═══════════════════════════════════");
    print("DEBUG: All SharedPreferences keys: ${prefs.getKeys()}");
    print("DEBUG: userId = ${prefs.getInt('userId')}");
    print("DEBUG: userName = ${prefs.getString('userName')}");
    print("DEBUG: userEmail = ${prefs.getString('userEmail')}");
    print("═══════════════════════════════════");

    setState(() {
      _currentUserId = prefs.getInt('userId');
    });

    if (_currentUserId == null) {
      print("❌ No User ID found. User might not be logged in.");
    } else {
      print("✅ Loaded User ID: $_currentUserId");
    }
  }

  /// PRIMARY METHOD: Call the Free API
  Future<void> _checkCompliance() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      // API Endpoint (Free Public API)
      final apiUrl = Uri.parse(
        "https://www.gdprvalidator.eu/api/v1/scan/check?url=$url",
      );

      final response = await http
          .get(apiUrl)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final resultData = {
          "source": "API",
          "url": url,
          "score": data['score'] ?? 0,
          "ssl": data['ssl_secure'] ?? false,
          "privacy_policy": data['privacy_policy_found'] ?? false,
          "cookie_banner": data['cookie_banner_found'] ?? false,
        };

        setState(() {
          _result = resultData;
        });

        // 2. Save result using the REAL User ID
        await _saveResultToBackend(resultData);
      } else {
        await _performLocalCheck(url);
      }
    } catch (e) {
      await _performLocalCheck(url);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// BACKUP METHOD: Local Check
  Future<void> _performLocalCheck(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      final content = response.body.toLowerCase();

      bool hasSsl = url.startsWith("https");
      bool hasPrivacy = content.contains("privacy policy");
      bool hasCookie =
          content.contains("cookie") && content.contains("consent");

      int score = 0;
      if (hasSsl) score += 40;
      if (hasPrivacy) score += 30;
      if (hasCookie) score += 30;

      final resultData = {
        "source": "Local Scan (Backup)",
        "url": url,
        "score": score,
        "ssl": hasSsl,
        "privacy_policy": hasPrivacy,
        "cookie_banner": hasCookie,
      };

      setState(() {
        _result = resultData;
      });

      await _saveResultToBackend(resultData);
    } catch (e) {
      setState(() {
        _errorMessage = "Could not reach website. Please check the URL.";
      });
    }
  }

  /// 3. Save data to Node.js backend using the Logged-In User ID
  Future<void> _saveResultToBackend(Map<String, dynamic> result) async {
    // If we don't have a user ID, we can't associate the data
    if (_currentUserId == null) {
      print("Cannot save to DB: User ID is null (Not logged in?)");
      return;
    }

    try {
      final uri = Uri.parse("$_baseUrl/api/gdpr/save");

      final body = json.encode({
        "userId":
            _currentUserId, // <--- Using the Real ID from SharedPreferences
        "url": result['url'],
        "score": result['score'],
        "sslSecure": result['ssl'],
        "privacyPolicyFound": result['privacy_policy'],
        "cookieBannerFound": result['cookie_banner'],
      });

      print("Saving to backend for User $_currentUserId...");

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        print("GDPR Scan saved successfully!");
      } else {
        print("Failed to save: ${response.body}");
      }
    } catch (e) {
      print("Backend Connection Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GDPR Compliance Checker")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: "Enter Website URL",
                  hintText: "example.com",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // We disable the button if the User ID hasn't loaded yet
                  // to prevent saving data without an owner.
                  onPressed: (_isLoading || _currentUserId == null)
                      ? null
                      : _checkCompliance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Check Compliance"),
                ),
              ),

              // Optional: Helper text if ID is missing (for debugging)
              if (_currentUserId == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Loading User Session...",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.shade100,
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_result != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final int score = _result!['score'];
    final bool isSafe = score >= 70;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Compliance Score",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSafe ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$score/100",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _buildCheckItem("SSL Secure Connection", _result!['ssl']),
            _buildCheckItem("Privacy Policy Found", _result!['privacy_policy']),
            _buildCheckItem("Cookie Consent Banner", _result!['cookie_banner']),
            const SizedBox(height: 10),
            Text(
              "Source: ${_result!['source']}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String title, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
