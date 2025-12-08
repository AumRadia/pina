import 'dart:convert';
import 'dart:io';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPrefs
import 'package:pina/screens/constants.dart'; // Import Constants for URL

void main() {
  runApp(
    const MaterialApp(
      home: CopyleaksScanScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class CopyleaksScanScreen extends StatefulWidget {
  const CopyleaksScanScreen({super.key});

  @override
  State<CopyleaksScanScreen> createState() => _CopyleaksScanScreenState();
}

class _CopyleaksScanScreenState extends State<CopyleaksScanScreen> {
  // CONFIGURATION: Copyleaks Credentials
  final String _email = "aumradia18@gmail.com";
  final String _apiKey = "50fd3d2d-941b-4e7d-98e0-37f47fae37e0";

  // Use your centralized API URL
  final String _myBackendUrl = ApiConstants.authUrl;

  String? _fileName;
  String? _fileContent;
  bool _isLoading = false;
  String? _resultMessage;
  double? _aiScore;

  // Unique Scan ID generator (timestamp based)
  String get _scanId => "scan-${DateTime.now().millisecondsSinceEpoch}";

  /// Step 1: Pick a file and read its content
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'docx'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String filename = result.files.single.name;
        String extension = result.files.single.extension?.toLowerCase() ?? "";
        String extractedText = "";

        setState(() {
          _isLoading = true;
        });

        if (extension == 'txt') {
          extractedText = await file.readAsString();
        } else if (extension == 'pdf') {
          try {
            extractedText = await ReadPdfText.getPDFtext(file.path);
          } catch (e) {
            extractedText =
                "Error reading PDF: This might be an image-only PDF.";
          }
        } else if (extension == 'docx') {
          final bytes = await file.readAsBytes();
          extractedText = docxToText(bytes);
        }

        setState(() {
          _fileName = filename;
          _fileContent = extractedText;
          _resultMessage = null;
          _aiScore = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error reading file: $e")));
    }
  }

  /// Step 2: Save to DB, Login, and Scan
  Future<void> _scanDocument() async {
    if (_fileContent == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "Preparing scan...";
    });

    try {
      // 1. Get User ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('userId');
      final String userIdStr = userId?.toString() ?? "guest";

      // 2. Save Input to MongoDB -> Get plagId
      // NOTE: We used the new route '/api/plagiarism/input'
      int plagId = await _saveInputToMyDb(userIdStr, _fileContent!);

      if (plagId == 0) {
        throw Exception("Failed to save input to database. Aborting scan.");
      }

      setState(() {
        _resultMessage = "Scanning content...";
      });

      // 3. Authenticate with Copyleaks
      final String token = await _getAccessToken();

      // 4. Submit to Copyleaks
      final String url =
          "https://api.copyleaks.com/v2/writer-detector/$_scanId/check";
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"text": _fileContent, "sandbox": true}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'];
        final double aiProb = summary['ai']; // 0.0 to 1.0
        final double humanProb = 1.0 - aiProb;

        setState(() {
          _aiScore = aiProb;
          _resultMessage = "Scan Complete";
        });

        // 5. Save Output to MongoDB using plagId
        // NOTE: We used the new route '/api/plagiarism/output'
        await _saveOutputToMyDb(plagId, aiProb, humanProb);
      } else {
        throw Exception(
          "Scan failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      setState(() {
        _resultMessage = "Error: ${e.toString().replaceAll("Exception: ", "")}";
      });
      print("ERROR: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- API HELPER: Save Input ---
  Future<int> _saveInputToMyDb(String userId, String text) async {
    try {
      // Updated to the new route structure
      final url = Uri.parse("$_myBackendUrl/api/plagiarism/input");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId, "inputDocument": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Input saved. ID: ${data['plagId']}");
        return data['plagId'];
      } else {
        print("❌ Failed to save input: ${response.body}");
        return 0;
      }
    } catch (e) {
      print("❌ Backend connection error (Input): $e");
      return 0;
    }
  }

  // --- API HELPER: Save Output ---
  Future<void> _saveOutputToMyDb(
    int plagId,
    double aiProb,
    double humanProb,
  ) async {
    try {
      // Updated to the new route structure
      final url = Uri.parse("$_myBackendUrl/api/plagiarism/output");

      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "plagId": plagId,
          "aiProbability": aiProb,
          "humanProbability": humanProb,
        }),
      );
      print("✅ Results saved to DB");
    } catch (e) {
      print("❌ Backend connection error (Output): $e");
    }
  }

  /// Helper: Authenticate with Copyleaks
  Future<String> _getAccessToken() async {
    final response = await http.post(
      Uri.parse("https://id.copyleaks.com/v3/account/login/api"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": _email, "key": _apiKey}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception("Authentication Failed. Check API Key/Email.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Copyleaks AI Scanner"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Upload Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file, size: 50, color: Colors.blueAccent),
                  const SizedBox(height: 10),
                  Text(
                    _fileName ?? "No file selected",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickFile,
                    child: const Text("Select Document"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Action Button
            ElevatedButton(
              onPressed: (_fileContent != null && !_isLoading)
                  ? _scanDocument
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Scan for AI Content"),
            ),

            const SizedBox(height: 30),

            // 3. Results Section
            if (_aiScore != null) ...[
              const Text(
                "Scan Results",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildScoreCard("AI Probability", _aiScore!, Colors.redAccent),
              const SizedBox(height: 10),
              _buildScoreCard(
                "Human Probability",
                1.0 - _aiScore!,
                Colors.green,
              ),
            ],

            if (_resultMessage != null && _aiScore == null)
              Text(
                _resultMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, double score, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            "${(score * 100).toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
