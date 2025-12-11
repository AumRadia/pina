//conversion
//1 Dec 25
//Aum
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

// 1. Provider List
enum LlmProvider {
  openRouter, // A1
  portkey, // A2
  kongAi, // A3
  liteLlm, // A4
  orqAi, // A5
  togetherAi, // A6
  openAI, // L1
  anthropic, // L2
  mistral, // L3
  deepSeek, // L4
}

// Helper to get the display name
extension ProviderDisplay on LlmProvider {
  String get displayName {
    switch (this) {
      case LlmProvider.openRouter:
        return "A1";
      case LlmProvider.portkey:
        return "A2";
      case LlmProvider.kongAi:
        return "A3";
      case LlmProvider.liteLlm:
        return "A4";
      case LlmProvider.orqAi:
        return "A5";
      case LlmProvider.togetherAi:
        return "A6";
      case LlmProvider.openAI:
        return "L1";
      case LlmProvider.anthropic:
        return "L2";
      case LlmProvider.mistral:
        return "L3";
      case LlmProvider.deepSeek:
        return "L4";
    }
  }
}

class LmStudioService {
  // --- API KEYS (A-Series) ---
  static const String _openRouterKey = "sk-or-v1-YOUR_KEY_HERE";
  static const String _portkeyKey = "YOUR_PORTKEY_KEY";
  static const String _kongAiKey = "YOUR_KONGAI_KEY";
  static const String _liteLlmKey = "YOUR_LITELLM_KEY";
  static const String _orqAiKey = "YOUR_ORQAI_KEY";
  static const String _togetherAiKey = "YOUR_TOGETHER_KEY";

  // --- API KEYS (L-Series) ---
  static const String _openAIKey = "YOUR_OPENAI_KEY";
  static const String _anthropicKey = "YOUR_ANTHROPIC_KEY";
  static const String _mistralKey = "YOUR_MISTRAL_KEY";
  static const String _deepSeekKey = "YOUR_DEEPSEEK_KEY";

  final Box _box = Hive.box('chat_storage_v2');
  String _uploadedDocumentContext = "";
  List<Map<String, dynamic>> _history = [];

  LmStudioService() {
    _loadHistory();
  }

  // --- MAIN GENERATION FUNCTION WITH NEW PRIORITY LOGIC ---
  Future<Map<String, dynamic>> generateResponse(
    String prompt,
    LlmProvider selectedProvider,
  ) async {
    List<LlmProvider> providerQueue = [];

    // 1. First Priority: The user selected provider
    providerQueue.add(selectedProvider);

    // Define the strict order lists
    final List<LlmProvider> aSeries = [
      LlmProvider.openRouter, // A1
      LlmProvider.portkey, // A2
      LlmProvider.kongAi, // A3
      LlmProvider.liteLlm, // A4
      LlmProvider.orqAi, // A5
      LlmProvider.togetherAi, // A6
    ];

    final List<LlmProvider> lSeries = [
      LlmProvider.openAI, // L1
      LlmProvider.anthropic, // L2
      LlmProvider.mistral, // L3
      LlmProvider.deepSeek, // L4
    ];

    // 2. Second Priority: Remaining A-Series
    for (var p in aSeries) {
      if (!providerQueue.contains(p)) {
        providerQueue.add(p);
      }
    }

    // 3. Third Priority: Remaining L-Series
    for (var p in lSeries) {
      if (!providerQueue.contains(p)) {
        providerQueue.add(p);
      }
    }

    // --- EXECUTE QUEUE ---
    for (var provider in providerQueue) {
      try {
        print(
          "🔄 Trying provider: ${provider.displayName} (${provider.name})...",
        );

        var response = await _makeRequest(prompt: prompt, provider: provider);

        // Check if API call was successful (200-299)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("✅ Success with ${provider.displayName}!");
          return _parseResponse(
            response,
            originalPrompt: prompt,
            providerName: provider.displayName,
          );
        } else {
          print(
            "⚠️ Failed ${provider.displayName} with status ${response.statusCode}. Moving to next...",
          );
          // Continue loop to try next provider
        }
      } catch (e) {
        print(
          "⚠️ Exception with ${provider.displayName}: $e. Moving to next...",
        );
        // Continue loop to try next provider
      }
    }

    // 4. FINAL FALLBACK
    print("❌ All providers failed. Fallback to Google Message.");
    return {
      'success': true,
      'content': 'All providers failed. Moved to local fallback.',
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
      // --- A SERIES ---
      case LlmProvider.openRouter: // A1
        url = "https://openrouter.ai/api/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_openRouterKey';
        headers['HTTP-Referer'] = 'http://localhost';
        headers['X-Title'] = 'App Fallback Test';
        body['model'] = "mistralai/mistral-7b-instruct";
        break;

      case LlmProvider.portkey: // A2
        url = "https://api.portkey.ai/v1/chat/completions";
        headers['x-portkey-api-key'] = _portkeyKey;
        headers['x-portkey-provider'] = "openai";
        body['model'] = "gpt-3.5-turbo";
        break;

      case LlmProvider.kongAi: // A3
        url = "https://YOUR_KONG_GATEWAY/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_kongAiKey';
        body['model'] = "default";
        break;

      case LlmProvider.liteLlm: // A4
        url = "http://0.0.0.0:4000/chat/completions";
        headers['Authorization'] = 'Bearer $_liteLlmKey';
        body['model'] = "gpt-3.5-turbo";
        break;

      case LlmProvider.orqAi: // A5
        url = "https://api.orq.ai/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_orqAiKey';
        body['model'] = "default";
        break;

      case LlmProvider.togetherAi: // A6
        url = "https://api.together.xyz/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_togetherAiKey';
        body['model'] = "meta-llama/Llama-3-8b-chat-hf";
        break;

      // --- L SERIES ---
      case LlmProvider.openAI: // L1
        url = "https://api.openai.com/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_openAIKey';
        body['model'] = "gpt-4o";
        break;

      case LlmProvider.anthropic: // L2
        // Note: Anthropic uses a slightly different API structure (messages array is same, but top-level params differ)
        // If using a proxy that mimics OpenAI, use that URL. If using direct Anthropic API:
        url = "https://api.anthropic.com/v1/messages";
        headers['x-api-key'] = _anthropicKey;
        headers['anthropic-version'] = '2023-06-01';
        body['model'] = "claude-3-opus-20240229";
        body['max_tokens'] = 1024;
        break;

      case LlmProvider.mistral: // L3
        url = "https://api.mistral.ai/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_mistralKey';
        body['model'] = "mistral-large-latest";
        break;

      case LlmProvider.deepSeek: // L4
        url = "https://api.deepseek.com/chat/completions";
        headers['Authorization'] = 'Bearer $_deepSeekKey';
        body['model'] = "deepseek-chat";
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
        // Handle Anthropic or direct content responses
        if (data['content'] is List && (data['content'] as List).isNotEmpty) {
          text = data['content'][0]['text'];
        } else if (data['content'] is String) {
          text = data['content'];
        }
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
