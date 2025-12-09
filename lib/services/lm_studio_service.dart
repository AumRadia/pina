import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/constants.dart';

// 1. Define the supported providers
enum LlmProvider { openRouter, portkey, kongAi, liteLlm, orqAi, togetherAi }

class LmStudioService {
  // --- API KEYS ---
  static const String _openRouterKey = "sk-or-v1-YOUR_KEY_HERE";
  static const String _portkeyKey = "YOUR_PORTKEY_KEY";
  static const String _kongAiKey = "YOUR_KONGAI_KEY";
  static const String _liteLlmKey = "YOUR_LITELLM_KEY";
  static const String _orqAiKey = "YOUR_ORQAI_KEY";
  static const String _togetherAiKey = "YOUR_TOGETHER_KEY";

  final Box _box = Hive.box('chat_storage_v2');
  String _uploadedDocumentContext = "";
  List<Map<String, dynamic>> _history = [];

  LmStudioService() {
    _loadHistory();
  }

  // --- MAIN GENERATION FUNCTION WITH FALLBACK LOOP ---
  Future<Map<String, dynamic>> generateResponse(
    String prompt,
    LlmProvider selectedProvider,
  ) async {
    // 1. Build the priority list: Selected Provider -> Others -> ...
    List<LlmProvider> providerQueue = [selectedProvider];

    // Add all other providers to the queue (excluding the selected one)
    for (var p in LlmProvider.values) {
      if (p != selectedProvider) {
        providerQueue.add(p);
      }
    }

    // 2. Iterate through the queue
    for (var provider in providerQueue) {
      try {
        print("🔄 Trying provider: ${provider.name.toUpperCase()}...");

        var response = await _makeRequest(prompt: prompt, provider: provider);

        // Check if API call was successful (200-299)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("✅ Success with ${provider.name}!");
          return _parseResponse(
            response,
            originalPrompt: prompt,
            providerName: provider.name,
          );
        } else {
          print(
            "⚠️ Failed ${provider.name} with status ${response.statusCode}. Moving to next...",
          );
          // Continue loop to try next provider
        }
      } catch (e) {
        print("⚠️ Exception with ${provider.name}: $e. Moving to next...");
        // Continue loop to try next provider
      }
    }

    // 3. FINAL FALLBACK (If all providers failed)
    print("❌ All providers failed. Fallback to Google Message.");
    return {
      'success':
          true, // We treat this as a "success" so no error snackbar shows
      'content': 'Moved to Google LLM',
      'model': 'Fallback-Google',
      'status': 'success',
    };
  }

  Future<http.Response> _makeRequest({
    required String prompt,
    required LlmProvider provider,
  }) async {
    String finalPrompt = prompt;

    // Add context if file was uploaded
    if (_uploadedDocumentContext.isNotEmpty) {
      finalPrompt =
          "CONTEXT DOCUMENT:\n$_uploadedDocumentContext\n\nUSER QUESTION:\n$prompt";
    }

    // --- Prepare Messages ---
    List<Map<String, dynamic>> messages = [];
    for (var item in _history) {
      String role = item['role'] ?? 'user';
      if (role == 'model') role = 'assistant';

      String content = "";
      if (item['parts'] != null && (item['parts'] as List).isNotEmpty) {
        content = item['parts'][0]['text'];
      }
      if (content.isNotEmpty) {
        messages.add({"role": role, "content": content});
      }
    }
    messages.add({"role": "user", "content": finalPrompt});

    // --- Switch Configuration ---
    String url = "";
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {"messages": messages, "stream": false};

    switch (provider) {
      case LlmProvider.openRouter:
        url = "https://openrouter.ai/api/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_openRouterKey';
        headers['HTTP-Referer'] = 'http://localhost';
        headers['X-Title'] = 'App Fallback Test';
        body['model'] = "mistralai/mistral-7b-instruct";
        break;

      case LlmProvider.portkey:
        url = "https://api.portkey.ai/v1/chat/completions";
        headers['x-portkey-api-key'] = _portkeyKey;
        headers['x-portkey-provider'] = "openai";
        body['model'] = "gpt-3.5-turbo";
        break;

      case LlmProvider.kongAi:
        url = "https://YOUR_KONG_GATEWAY/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_kongAiKey';
        body['model'] = "default";
        break;

      case LlmProvider.liteLlm:
        url = "http://0.0.0.0:4000/chat/completions";
        headers['Authorization'] = 'Bearer $_liteLlmKey';
        body['model'] = "gpt-3.5-turbo";
        break;

      case LlmProvider.orqAi:
        url = "https://api.orq.ai/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_orqAiKey';
        body['model'] = "default";
        break;

      case LlmProvider.togetherAi:
        url = "https://api.together.xyz/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_togetherAiKey';
        body['model'] = "meta-llama/Llama-3-8b-chat-hf";
        break;
    }

    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _parseResponse(
    http.Response response, {
    required String originalPrompt,
    required String providerName,
  }) {
    final data = jsonDecode(response.body);
    String text = "No text response.";

    try {
      if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
        text = data['choices'][0]['message']['content'];
      } else if (data['content'] != null) {
        text = data['content'];
      }
    } catch (e) {
      print("Error parsing JSON: $e");
    }

    _addToHistory("user", originalPrompt);
    _addToHistory("model", text);

    return {
      'success': true,
      'content': text,
      'model': providerName,
      'status': 'success',
    };
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
