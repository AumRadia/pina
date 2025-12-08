import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/constants.dart';

class LmStudioService {
  // 1. SETUP: Paste your API Key here
  static const String lmapiKey = ApiConstants.lmapiKey;

  // URL - Using gemini-2.5-flash with Google Search support
  static const String _url =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

  final Box _box = Hive.box('chat_storage_v2');
  String _uploadedDocumentContext = "";
  List<Map<String, dynamic>> _history = [];

  LmStudioService() {
    _loadHistory();
  }

  Future<Map<String, dynamic>> generateResponse(String prompt) async {
    try {
      if (lmapiKey.contains("PASTE")) {
        return {
          'content': '⚠️ Please add your API Key in lm_studio_service.dart',
          'status': 'error',
        };
      }

      var response = await _makeRequest(
        url: _url,
        prompt: prompt,
        enableSearch: true,
      );

      return _parseResponse(response, originalPrompt: prompt);
    } catch (e) {
      print("🔥 EXCEPTION: $e");
      return {'content': 'Error: $e', 'status': 'error'};
    }
  }

  Future<http.Response> _makeRequest({
    required String url,
    required String prompt,
    required bool enableSearch,
  }) async {
    String finalPrompt = prompt;
    if (_uploadedDocumentContext.isNotEmpty) {
      finalPrompt =
          "CONTEXT DOCUMENT:\n$_uploadedDocumentContext\n\nUSER QUESTION:\n$prompt";
    }

    // --- Sanitize Roles ---
    List<Map<String, dynamic>> validHistory = [];

    for (var item in _history) {
      String role = item['role'] ?? 'user';

      // 1. Fix Role Name
      if (role == 'assistant') role = 'model';
      if (role != 'user' && role != 'model') role = 'user';

      // 2. Fix Structure (flat text vs parts)
      if (item.containsKey('parts') && item['parts'] != null) {
        List<dynamic> parts = item['parts'];
        if (parts.isNotEmpty) {
          validHistory.add({"role": role, "parts": parts});
        }
      } else if (item.containsKey('text') &&
          item['text'] != null &&
          item['text'].toString().isNotEmpty) {
        validHistory.add({
          "role": role,
          "parts": [
            {"text": item['text']},
          ],
        });
      }
    }

    final requestBody = {
      "contents": [
        ...validHistory,
        {
          "role": "user",
          "parts": [
            {"text": finalPrompt},
          ],
        },
      ],
      if (enableSearch)
        "tools": [
          {
            // FIXED: Use "google_search" for Gemini 2.5
            // (older models use "google_search_retrieval")
            "google_search": {},
          },
        ],
    };

    print("📤 Sending to: $url");
    print("📤 History items: ${validHistory.length}");
    print("📤 Search enabled: $enableSearch");

    return await http.post(
      Uri.parse("$url?key=$lmapiKey"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
  }

  Map<String, dynamic> _parseResponse(
    http.Response response, {
    required String originalPrompt,
    bool isFallback = false,
  }) {
    if (response.statusCode != 200) {
      print("❌ API Error ${response.statusCode}");
      print("❌ Response: ${response.body}");

      if (response.statusCode == 400) {
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
          print("❌ ERROR DETAILS: $errorMsg");
        } catch (e) {
          print("❌ Could not parse error: $e");
        }

        print("⚠️ Clearing corrupted history...");
        clearMemory();
        return {
          'content':
              '⚠️ Memory was corrupted. History cleared. Please try again.',
          'status': 'error',
        };
      }
      return {
        'content': 'Error ${response.statusCode}: ${response.body}',
        'status': 'error',
      };
    }

    final data = jsonDecode(response.body);
    String text =
        data['candidates']?[0]['content']?['parts']?[0]?['text'] ??
        "No text response.";

    String source = "Gemini 2.5 Flash";

    // Check if Google Search was used
    try {
      if (data['candidates']?[0]?['groundingMetadata']?['groundingChunks'] !=
              null &&
          data['candidates'][0]['groundingMetadata']['groundingChunks']
              .isNotEmpty) {
        source += " + 🌐 Google Search";
        print("✅ Search grounding was used!");
      }
    } catch (e) {
      print("⚠️ No grounding metadata found");
    }

    // Save with actual prompt
    _addToHistory("user", originalPrompt);
    _addToHistory("model", text);

    return {'content': text, 'model': source, 'status': 'success'};
  }

  // --- Helpers ---
  Future<void> addDocumentToRAG(String text) async {
    _uploadedDocumentContext = text;
    await _box.put('current_document_text', text);
  }

  void removeDocument() {
    _uploadedDocumentContext = "";
    _box.delete('current_document_text');
  }

  void _addToHistory(String role, String text) {
    // Force "model" if code accidentally sends "assistant"
    if (role == 'assistant') role = 'model';

    // Don't save empty messages
    if (text.isEmpty) return;

    final msg = {
      "role": role,
      "parts": [
        {"text": text},
      ],
    };
    _history.add(msg);

    List<Map<String, dynamic>> saveList = [];
    if (_box.containsKey('history_list')) {
      final raw = _box.get('history_list') as List;
      saveList = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    saveList.add(msg);
    _box.put('history_list', saveList);
  }

  void _loadHistory() {
    if (_box.containsKey('current_document_text'))
      _uploadedDocumentContext = _box.get('current_document_text');
    if (_box.containsKey('history_list')) {
      final raw = _box.get('history_list') as List;
      _history = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  void clearMemory() {
    _history.clear();
    _uploadedDocumentContext = "";
    _box.delete('history_list');
    _box.delete('current_document_text');
  }
}
