import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pina/models/assembly_config.dart';
import 'package:pina/models/local_whisper_config.dart';
import 'package:pina/screens/constants.dart'; // Import your constants

class AudioTranscriptionService {
  final String assemblyApiKey = ApiConstants.assemblyApiKey;

  // =========================================================
  // SECTION 1: AssemblyAI Cloud Methods (Existing)
  // =========================================================

  Future<String?> _uploadToAssembly(String path) async {
    try {
      final url = Uri.parse("https://api.assemblyai.com/v2/upload");
      final request = http.MultipartRequest('POST', url)
        ..headers["Authorization"] = assemblyApiKey
        ..files.add(await http.MultipartFile.fromPath("file", path));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      return jsonDecode(body)["upload_url"];
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  Future<String?> _createTranscript(
    String audioUrl,
    AssemblyConfig config,
  ) async {
    try {
      final url = Uri.parse("https://api.assemblyai.com/v2/transcript");
      final requestBody = {"audio_url": audioUrl, ...config.toJson()};

      print("=== Assembly AI Request ===");
      print("URL: $url");
      print("Body: ${jsonEncode(requestBody)}");

      final res = await http.post(
        url,
        headers: {
          "Authorization": assemblyApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(res.body);

      if (res.statusCode == 200 && responseData["id"] != null) {
        return responseData["id"];
      } else {
        print(
          "Error creating transcript: ${responseData["error"] ?? "Unknown error"}",
        );
        return null;
      }
    } catch (e) {
      print("Exception in _createTranscript: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getTranscriptResult(String id) async {
    final url = Uri.parse("https://api.assemblyai.com/v2/transcript/$id");
    final res = await http.get(url, headers: {"Authorization": assemblyApiKey});
    final data = jsonDecode(res.body);
    final status = data["status"];

    if (status == "completed") return data;
    if (status == "error") {
      print("Transcription Error: ${data["error"]}");
      return {"error": data["error"]};
    }
    return null; // Still processing
  }

  Future<Map<String, dynamic>?> transcribeAudio(
    File audioFile,
    AssemblyConfig config,
  ) async {
    print("=== Starting AssemblyAI Transcription ===");
    final uploadUrl = await _uploadToAssembly(audioFile.path);
    if (uploadUrl == null) return {"error": "Failed to upload file"};

    final tId = await _createTranscript(uploadUrl, config);
    if (tId == null) return {"error": "Failed to start transcription"};

    print("Polling for results (ID: $tId)...");

    Map<String, dynamic>? data;
    int attempts = 0;

    // Poll for up to 3 minutes (60 * 3s)
    while (data == null && attempts < 60) {
      await Future.delayed(const Duration(seconds: 3));
      data = await _getTranscriptResult(tId);
      attempts++;
    }

    if (data == null) return {"error": "Transcription timeout"};
    if (data.containsKey("error")) return data;

    return data;
  }

  // =========================================================
  // SECTION 2: Local Whisper Method (UPDATED)
  // =========================================================

  Future<Map<String, dynamic>> transcribeWithLocalWhisper(
    File audioFile,
    LocalWhisperConfig config, // <--- ADD CONFIG PARAMETER
  ) async {
    final String baseUrl = ApiConstants.baseUrl;
    final uri = Uri.parse("$baseUrl:4000/whisper"); // Ensure port 4000

    try {
      print("=== Local Whisper: ${config.modelSize} | ${config.language} ===");

      var request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      // === ADD CONFIG FIELDS ===
      request.fields['model'] = config.modelSize;
      request.fields['language'] = config.language;
      request.fields['task'] = config.translateToEnglish
          ? 'translate'
          : 'transcribe';
      request.fields['fp16'] = config.useGpu.toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "error": "Server error: ${response.statusCode}",
          "details": response.body,
        };
      }
    } catch (e) {
      return {"error": "Connection failed", "details": e.toString()};
    }
  }
}
