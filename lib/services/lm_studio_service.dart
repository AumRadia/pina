//Aum
//v1.3 added Image Skip logic for Local Gemma

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/constants.dart';

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
  localGemma, // <--- Local Text Model (LM Studio)
  assemblyAi, // Audio (Cloud)
  localWhisper, // Audio (Local)
  stableDiffusion, // Image
}

// Helper to get the display name
extension ProviderDisplay on LlmProvider {
  String get displayName {
    switch (this) {
      case LlmProvider.openRouter:
        return "A1 (OpenRouter)";
      case LlmProvider.portkey:
        return "A2 (Portkey)";
      case LlmProvider.kongAi:
        return "A3 (Kong)";
      case LlmProvider.liteLlm:
        return "A4 (LiteLLM)";
      case LlmProvider.orqAi:
        return "A5 (Orq)";
      case LlmProvider.togetherAi:
        return "A6 (Together)";
      case LlmProvider.openAI:
        return "L1 (OpenAI)";
      case LlmProvider.anthropic:
        return "L2 (Anthropic)";
      case LlmProvider.mistral:
        return "L3 (Mistral)";
      case LlmProvider.deepSeek:
        return "L4 (DeepSeek)";
      case LlmProvider.localGemma:
        return "Local Gemma (1B)";
      case LlmProvider.assemblyAi:
        return "Assembly AI (Audio)";
      case LlmProvider.localWhisper:
        return "Local Whisper";
      case LlmProvider.stableDiffusion:
        return "Stable Diffusion (Image)";
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

  // --- MAIN GENERATION FUNCTION ---
  Future<Map<String, dynamic>> generateResponse(
    String prompt,
    LlmProvider selectedProvider, {
    bool hasImages = false, // <--- NEW PARAMETER
  }) async {
    List<LlmProvider> providerQueue = [];

    // 1. First Priority: The user selected provider
    providerQueue.add(selectedProvider);

    // Define the strict order lists
    final List<LlmProvider> aSeries = [
      LlmProvider.openRouter,
      LlmProvider.portkey,
      LlmProvider.kongAi,
      LlmProvider.liteLlm,
      LlmProvider.orqAi,
      LlmProvider.togetherAi,
    ];

    final List<LlmProvider> lSeries = [
      LlmProvider.openAI,
      LlmProvider.anthropic,
      LlmProvider.mistral,
      LlmProvider.deepSeek,
    ];

    // 2. Second Priority: Remaining A-Series
    for (var p in aSeries) {
      if (!providerQueue.contains(p)) providerQueue.add(p);
    }

    // 3. Third Priority: Remaining L-Series
    for (var p in lSeries) {
      if (!providerQueue.contains(p)) providerQueue.add(p);
    }

    // --- EXECUTE QUEUE ---
    for (var provider in providerQueue) {
      // Skip Special Providers (Audio/Image) in this loop
      if (provider == LlmProvider.assemblyAi ||
          provider == LlmProvider.localWhisper ||
          provider == LlmProvider.stableDiffusion) {
        continue;
      }

      // --- NEW SKIP LOGIC ---
      // If user selected Local Gemma but has attached images, skip it.
      if (provider == LlmProvider.localGemma && hasImages) {
        print(
          "⚠️ Skipping ${provider.displayName} (Text-Only) because images are attached.",
        );
        continue; // Moves to the next provider in the queue
      }

      try {
        print(
          "🔄 Trying provider: ${provider.displayName} (${provider.name})...",
        );

        var response = await _makeRequest(prompt: prompt, provider: provider);

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
        }
      } catch (e) {
        print(
          "⚠️ Exception with ${provider.displayName}: $e. Moving to next...",
        );
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

    if (_uploadedDocumentContext.isNotEmpty) {
      finalPrompt =
          "CONTEXT DOCUMENT:\n$_uploadedDocumentContext\n\nUSER QUESTION:\n$prompt";
    }

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

    String url = "";
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {"messages": messages, "stream": false};

    switch (provider) {
      // --- LOCAL GEMMA ---
      case LlmProvider.localGemma:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "gemma-3-1b";
        body['temperature'] = 0.7;
        break;

      // --- A SERIES ---
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

      // --- L SERIES ---
      case LlmProvider.openAI:
        url = "https://api.openai.com/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_openAIKey';
        body['model'] = "gpt-4o";
        break;

      case LlmProvider.anthropic:
        url = "https://api.anthropic.com/v1/messages";
        headers['x-api-key'] = _anthropicKey;
        headers['anthropic-version'] = '2023-06-01';
        body['model'] = "claude-3-opus-20240229";
        body['max_tokens'] = 1024;
        break;

      case LlmProvider.mistral:
        url = "https://api.mistral.ai/v1/chat/completions";
        headers['Authorization'] = 'Bearer $_mistralKey';
        body['model'] = "mistral-large-latest";
        break;

      case LlmProvider.deepSeek:
        url = "https://api.deepseek.com/chat/completions";
        headers['Authorization'] = 'Bearer $_deepSeekKey';
        body['model'] = "deepseek-chat";
        break;

      // --- SPECIAL PROVIDERS ---
      case LlmProvider.assemblyAi:
      case LlmProvider.localWhisper:
      case LlmProvider.stableDiffusion:
        throw UnimplementedError(
          "AssemblyAI, LocalWhisper, and StableDiffusion are handled by dedicated services, not via _makeRequest.",
        );
    }

    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // ... (Rest of the class methods remain unchanged) ...
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
