//
//
// v1.8 Added Error Logging Support

import 'dart:convert';
import 'dart:async';
import 'dart:io'; // Required for File handling
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pina/screens/constants.dart';

import 'package:pina/services/audio_transcription_service.dart';
import 'package:pina/models/assembly_config.dart';
import 'package:pina/models/local_whisper_config.dart';

// 1. Provider List
enum LlmProvider {
  openRouter, // A1
  portkey, // A2
  kongAi, // A3
  liteLlm, // A4
  orqAi, // A5
  togetherAi, // A6
  openAI, // L1
  anthropic,
  anthropicHaiku, // L2
  mistral, // L3
  deepSeek, // L4
  localGemma, // Text-Only (1B)
  localGemma4b,
  localLlama3_2_1b,
  localPhi3_5_mini, // Gemma 3 4B (Vision)
  qwen, // Local Qwen Support
  assemblyAi, // Audio (Cloud)
  localWhisper, // Audio (Local CLI)
  distilWhisper, // Audio (Local LM Studio API)
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
      case LlmProvider.anthropicHaiku:
        return "L2.5 (Claude Haiku)";
      case LlmProvider.mistral:
        return "L3 (Mistral)";
      case LlmProvider.deepSeek:
        return "L4 (DeepSeek)";
      case LlmProvider.localGemma:
        return "Local Gemma (1B)";
      case LlmProvider.localLlama3_2_1b:
        return "Local Llama 3.2 (1B)";
      case LlmProvider.localPhi3_5_mini:
        return "Phi-3.5 Mini (3.8B)";
      case LlmProvider.localGemma4b:
        return "Local Gemma 3 (4B - Vision)";
      case LlmProvider.qwen:
        return "Local Qwen";
      case LlmProvider.assemblyAi:
        return "Assembly AI (Audio)";
      case LlmProvider.localWhisper:
        return "Local Whisper (CLI)";
      case LlmProvider.distilWhisper:
        return "Distil-Whisper";
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
  final AudioTranscriptionService _audioService = AudioTranscriptionService();

  String _uploadedDocumentContext = "";
  List<Map<String, dynamic>> _history = [];

  LmStudioService() {
    _loadHistory();
  }

  // --- MAIN GENERATION FUNCTION ---
  Future<Map<String, dynamic>> generateResponse(
    String prompt,
    LlmProvider selectedProvider, {
    bool hasImages = false,
    List<File>? imageFiles, // Accept image files
    // NEW ARGUMENTS FOR AUDIO
    File? audioFile,
    AssemblyConfig? assemblyConfig,
    LocalWhisperConfig? whisperConfig,
    double temperature = 0.7,
  }) async {
    List<LlmProvider> providerQueue = [];

    // --- NEW: Error Logs Collection ---
    // Stores provider name and error message only.
    List<Map<String, String>> errorLogs = [];

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
      LlmProvider.anthropicHaiku,
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

    // 4. AUTO-ADD AUDIO PROVIDERS IF AUDIO IS UPLOADED
    if (audioFile != null) {
      if (!providerQueue.contains(LlmProvider.assemblyAi)) {
        providerQueue.add(LlmProvider.assemblyAi);
      }
      if (!providerQueue.contains(LlmProvider.localWhisper)) {
        providerQueue.add(LlmProvider.localWhisper);
      }
      if (!providerQueue.contains(LlmProvider.distilWhisper)) {
        providerQueue.add(LlmProvider.distilWhisper);
      }
    }

    // --- EXECUTE QUEUE ---
    for (var provider in providerQueue) {
      // === HANDLE ASSEMBLY AI ===
      if (provider == LlmProvider.assemblyAi) {
        if (audioFile != null && assemblyConfig != null) {
          print(
            "🔄 Switching to provider: Assembly AI (Audio Input Detected)...",
          );
          try {
            final result = await _audioService.transcribeAudio(
              audioFile,
              assemblyConfig,
            );
            if (result != null && !result.containsKey('error')) {
              print("✅ Success with Assembly AI!");
              return {
                'success': true,
                'content': result['text'] ?? result.toString(),
                'model': 'AssemblyAI',
                'status': 'success',
                'errorLogs': errorLogs, // Pass logs
              };
            } else {
              // Capture API Error (No Timestamp)
              errorLogs.add({
                'provider': 'AssemblyAI',
                'error': result?['error'] ?? 'Unknown API Error',
              });
            }
          } catch (e) {
            // Capture Exception
            print("⚠️ AssemblyAI failed: $e");
            errorLogs.add({'provider': 'AssemblyAI', 'error': e.toString()});
          }
        }
        continue;
      }

      // === HANDLE LOCAL WHISPER (CLI) ===
      if (provider == LlmProvider.localWhisper) {
        if (audioFile != null && whisperConfig != null) {
          print("🔄 Switching to provider: Local Whisper (CLI)...");
          try {
            final result = await _audioService.transcribeWithLocalWhisper(
              audioFile,
              whisperConfig,
            );
            if (result.containsKey('text')) {
              print("✅ Success with Local Whisper!");
              return {
                'success': true,
                'content': result['text'],
                'model': 'LocalWhisper',
                'status': 'success',
                'errorLogs': errorLogs,
              };
            } else {
              errorLogs.add({
                'provider': 'LocalWhisper',
                'error': result['error'] ?? 'CLI Error',
              });
            }
          } catch (e) {
            print("⚠️ Local Whisper failed: $e");
            errorLogs.add({'provider': 'LocalWhisper', 'error': e.toString()});
          }
        }
        continue;
      }

      // === HANDLE DISTIL-WHISPER (API / LOCAL SERVER) ===
      if (provider == LlmProvider.distilWhisper) {
        if (audioFile != null) {
          print("🔄 Switching to provider: Distil-Whisper (LM Studio API)...");
          try {
            final text = await _transcribeWithLmStudioApi(audioFile);
            if (text != null && text.isNotEmpty) {
              print("✅ Success with Distil-Whisper!");
              return {
                'success': true,
                'content': text,
                'model': 'Distil-Whisper',
                'status': 'success',
                'errorLogs': errorLogs,
              };
            } else {
              errorLogs.add({
                'provider': 'Distil-Whisper',
                'error': 'API returned null text',
              });
            }
          } catch (e) {
            print("⚠️ Distil-Whisper failed: $e");
            errorLogs.add({
              'provider': 'Distil-Whisper',
              'error': e.toString(),
            });
          }
        }
        continue;
      }

      // === HANDLE TEXT/IMAGE MODELS ===

      // Skip Stable Diffusion in this text/audio loop
      if (provider == LlmProvider.stableDiffusion) continue;

      // 1. Skip Text-Only models if images are attached
      if ((provider == LlmProvider.localGemma ||
              provider == LlmProvider.localLlama3_2_1b ||
              provider == LlmProvider.localPhi3_5_mini ||
              provider == LlmProvider.qwen) &&
          hasImages) {
        // We don't log this as an "Error" because it's skipped logic,
        // but if you want to log skips, you could do it here.
        print("⚠️ Skipping ${provider.displayName} (Images attached).");
        continue;
      }

      // 2. Skip Text Models if Audio is present
      if (audioFile != null) {
        print("⚠️ Skipping ${provider.displayName} (Audio Input).");
        continue;
      }

      // --- STANDARD TEXT REQUEST ---
      try {
        print(
          "🔄 Trying provider: ${provider.displayName} (${provider.name})...",
        );

        var response = await _makeRequest(
          prompt: prompt,
          provider: provider,
          temperature: temperature,
          imageFiles: (provider == LlmProvider.localGemma4b)
              ? imageFiles
              : null,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("✅ Success with ${provider.displayName}!");
          var result = _parseResponse(
            response,
            originalPrompt: prompt,
            providerName: provider.displayName,
          );
          // --- ATTACH LOGS TO RESULT ---
          result['errorLogs'] = errorLogs;
          return result;
        } else {
          print(
            "⚠️ Failed ${provider.displayName} with status ${response.statusCode}. Moving to next...",
          );
          // Capture HTTP Error
          errorLogs.add({
            'provider': provider.displayName,
            'error': 'HTTP ${response.statusCode}: ${response.body}',
          });
        }
      } catch (e) {
        print(
          "⚠️ Exception with ${provider.displayName}: $e. Moving to next...",
        );
        // Capture Exception
        errorLogs.add({
          'provider': provider.displayName,
          'error': e.toString(),
        });
      }
    }

    // 4. FINAL FALLBACK
    print("❌ All providers failed. Fallback to Google Message.");
    return {
      'success': false,
      'content': 'All providers failed. Moved to local fallback.',
      'model': 'Fallback-Google',
      'status': 'failed',
      'errorLogs': errorLogs, // Return accumulated errors
    };
  }

  // --- API HELPER FOR DISTIL WHISPER ---
  Future<String?> _transcribeWithLmStudioApi(File audioFile) async {
    // Standard OpenAI-compatible audio endpoint on the local server
    final uri = Uri.parse(
      "${ApiConstants.lmStudioUrl}/v1/audio/transcriptions",
    );

    try {
      var request = http.MultipartRequest('POST', uri);

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      // Add Model Name (Required by API spec)
      request.fields['model'] = 'distil-whisper-large-v3';
      request.fields['temperature'] = '0.0';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'];
      } else {
        print(
          "LM Studio Audio Error: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print("Exception calling LM Studio Audio: $e");
      return null;
    }
  }

  Future<http.Response> _makeRequest({
    required String prompt,
    required LlmProvider provider,
    double temperature = 0.7,
    List<File>? imageFiles, // Accept images
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

    // --- CONSTRUCT CURRENT MESSAGE (TEXT + IMAGES) ---
    if (imageFiles != null &&
        imageFiles.isNotEmpty &&
        provider == LlmProvider.localGemma4b) {
      List<Map<String, dynamic>> contentParts = [
        {"type": "text", "text": finalPrompt},
      ];

      for (var file in imageFiles) {
        try {
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          contentParts.add({
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
          });
        } catch (e) {
          print("Error encoding image: $e");
        }
      }

      messages.add({"role": "user", "content": contentParts});
    } else {
      messages.add({"role": "user", "content": finalPrompt});
    }

    String url = "";
    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {
      "messages": messages,
      "stream": false,
      "temperature": temperature,
    };

    switch (provider) {
      // --- LOCAL MODELS (LM Studio) ---
      case LlmProvider.localGemma:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "gemma-3-1b";
        break;

      case LlmProvider.localGemma4b:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "gemma-3-4b";
        break;

      case LlmProvider.localPhi3_5_mini:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "phi-3.5-mini-3.8b-instruct";
        break;

      case LlmProvider.qwen:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "qwen2.5-1.5b-instruct";
        break;

      case LlmProvider.localLlama3_2_1b:
        url = "${ApiConstants.lmStudioUrl}/v1/chat/completions";
        body['model'] = "llama-3.2-1b-instruct";
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
      case LlmProvider.anthropicHaiku:
        url = "https://api.anthropic.com/v1/messages";
        headers['x-api-key'] = _anthropicKey;
        headers['anthropic-version'] = '2023-06-01';
        body['model'] = (provider == LlmProvider.anthropicHaiku)
            ? "claude-3-haiku-20240307"
            : "claude-3-opus-20240229";
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
      case LlmProvider.distilWhisper:
      case LlmProvider.stableDiffusion:
        throw UnimplementedError(
          "Special providers (Audio/Image) should be handled before _makeRequest.",
        );
    }

    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // --- RESPONSE PARSING ---
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

  // --- RAG & HISTORY HELPERS ---
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
