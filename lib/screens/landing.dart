import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pina/screens/constants.dart';
import 'package:pina/services/lm_studio_service.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/services/submission_service.dart';

// Import the new config model and dialog
import 'package:pina/models/assembly_config.dart';
import 'package:pina/widgets/audio_config_dialog.dart';

class LandingScreen extends StatefulWidget {
  final String title;
  final String userName;
  final String userEmail;

  const LandingScreen({
    required this.title,
    required this.userName,
    required this.userEmail,
    super.key,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController controller = TextEditingController();
  final LmStudioService _aiService = LmStudioService();
  final SubmissionService _submissionService = SubmissionService();

  String? output;
  final List<String> dataTypes = [
    "Text",
    "Image",
    "Audio",
    "Video",
    "Multiple",
  ];
  Map<String, bool> fromSelection = {};
  Map<String, bool> toSelection = {};
  bool isLoading = false;
  int tokenCount = 0;

  // Assembly AI
  final String assemblyApiKey = "574b02a0f19040f1939a5dac7b318bab";
  File? selectedAudioFile;

  // Audio configuration with default settings
  // Changed default language to English for testing
  AssemblyConfig audioConfig = AssemblyConfig(
    languageCode: 'en', // Changed from 'hi' to 'en' for testing
    punctuate: true,
    formatText: true,
  );

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

  Future<String?> _createTranscript(String audioUrl) async {
    try {
      final url = Uri.parse("https://api.assemblyai.com/v2/transcript");

      // Use the audioConfig to build the request body
      final requestBody = {"audio_url": audioUrl, ...audioConfig.toJson()};

      print("=== Assembly AI Request ===");
      print("URL: $url");
      print("Body: ${jsonEncode(requestBody)}");
      print("Config Language: ${audioConfig.languageCode}");
      print("Config Punctuate: ${audioConfig.punctuate}");
      print("Config Format Text: ${audioConfig.formatText}");
      print("Config Redact PII: ${audioConfig.redactPii}");
      print("Config PII Policies: ${audioConfig.redactPiiPolicies}");
      print("Config Speaker Labels: ${audioConfig.speakerLabels}");
      print("Config Filter Profanity: ${audioConfig.filterProfanity}");

      final res = await http.post(
        url,
        headers: {
          "Authorization": assemblyApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      print("=== Assembly AI Response ===");
      print("Status: ${res.statusCode}");
      print("Body: ${res.body}");

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

    if (status == "completed") return data; // Return the FULL JSON object
    if (status == "error") {
      print("Transcription Error: ${data["error"]}");
      return {"error": data["error"]};
    }
    return null; // Still processing
  }

  Future<Map<String, dynamic>?> transcribeSelectedAudio() async {
    if (selectedAudioFile == null) return {"error": "No audio file selected"};

    print("=== Starting Transcription ===");
    final uploadUrl = await _uploadToAssembly(selectedAudioFile!.path);
    if (uploadUrl == null) return {"error": "Failed to upload file"};

    final tId = await _createTranscript(uploadUrl);
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

  @override
  void initState() {
    super.initState();
    for (var t in dataTypes) {
      fromSelection[t] = false;
      toSelection[t] = false;
    }
    _autoSelectFromTitle();
  }

  void _autoSelectFromTitle() {
    List<String> parts = widget.title.split(" to ");
    if (parts.length >= 2) {
      String source = parts[0];
      String target = parts[1];
      setState(() {
        if (fromSelection.containsKey(source)) fromSelection[source] = true;
        if (toSelection.containsKey(target)) toSelection[target] = true;
      });
    }
  }

  List<String> _getSelectedList(Map<String, bool> map) {
    return map.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  int estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    final words = text.trim().split(RegExp(r"\s+")).length;
    return (words * 1.3).round();
  }

  Future<void> pickAudioFile() async {
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        "mp3",
        "wav",
        "m4a",
        "mp4",
        "mov",
        "mkv",
        "avi",
        "webm",
      ],
    );
    if (file != null) {
      setState(() {
        selectedAudioFile = File(file.files.single.path!);
      });
    }
  }

  // Show audio configuration dialog
  Future<void> _showAudioConfig() async {
    final result = await showDialog<AssemblyConfig>(
      context: context,
      builder: (context) => AudioConfigDialog(initialConfig: audioConfig),
    );

    if (result != null) {
      setState(() {
        audioConfig = result;
      });

      // Debug: Print what was saved
      print("=== Settings Updated ===");
      print("Language: ${audioConfig.languageCode}");
      print("Punctuate: ${audioConfig.punctuate}");
      print("Format Text: ${audioConfig.formatText}");
      print("Redact PII: ${audioConfig.redactPii}");
      print("PII Policies: ${audioConfig.redactPiiPolicies}");
      print("Speaker Labels: ${audioConfig.speakerLabels}");
      print("Filter Profanity: ${audioConfig.filterProfanity}");
      print("Sentiment Analysis: ${audioConfig.sentimentAnalysis}");
      print("Summarization: ${audioConfig.summarization}");

      _showSnack("Audio settings updated successfully");
    } else {
      print("Settings dialog cancelled");
    }
  }

  Future<void> _submitData() async {
    final promptText = controller.text.trim();
    final fromList = _getSelectedList(fromSelection);
    final toList = _getSelectedList(toSelection);

    final isAudioToText = fromList.contains("Audio") && toList.contains("Text");

    if (isAudioToText && selectedAudioFile == null) {
      _showSnack("Please upload an audio file first");
      return;
    }
    if (!isAudioToText && promptText.isEmpty) {
      _showSnack("Please enter a prompt");
      return;
    }

    setState(() {
      isLoading = true;
      output = null;
    });

    final result = await _submissionService.validateAndSaveInput(
      userName: widget.userName,
      userEmail: widget.userEmail,
      prompt: isAudioToText ? "Audio Upload" : promptText,
      fromList: fromList,
      toList: toList,
    );

    if (!result.success) {
      setState(() => isLoading = false);

      if (result.statusCode == 401) {
        _showSnack(result.errorMessage!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _showSnack(result.errorMessage!, isError: true);
      }
      return;
    }

    String finalText = "";
    String modelUsed = "";

    try {
      if (isAudioToText) {
        // 1. Capture the full Map response (not a String)
        final Map<String, dynamic>? resultData =
            await transcribeSelectedAudio();

        // 2. Convert the Map to a String using your helper function
        if (resultData != null) {
          finalText = _formatTranscriptOutput(resultData);
        } else {
          finalText = "An unknown error occurred during transcription.";
        }

        modelUsed = "AssemblyAI-STT";
      } else {
        // Existing logic for text-to-text...
        final aiResponse = await _aiService.generateResponse(promptText);
        // ... (rest of your existing else block)
      }
    } catch (e) {
      finalText = "Error: $e";
      modelUsed = "error";
    }

    if (result.promptId != null) {
      await _submissionService.saveOutput(
        promptId: result.promptId!,
        content: finalText,
        modelName: modelUsed,
      );
    }

    setState(() {
      output = finalText;
      isLoading = false;
    });
  }

  String _formatTranscriptOutput(Map<String, dynamic> data) {
    if (data.containsKey("error")) return "Error: ${data['error']}";

    StringBuffer buffer = StringBuffer();

    // 1. The Main Transcript
    buffer.writeln("=== TRANSCRIPT ===");
    buffer.writeln(data['text'] ?? "No text found.");
    buffer.writeln();

    // 2. Summary (if enabled)
    if (data['summary'] != null) {
      buffer.writeln("=== SUMMARY ===");
      buffer.writeln(data['summary']);
      buffer.writeln();
    }

    // 3. Auto Chapters (NEW SECTION)
    if (data['chapters'] != null) {
      buffer.writeln("=== CHAPTERS ===");
      final List chapters = data['chapters'];
      if (chapters.isEmpty) {
        buffer.writeln("No chapters detected.");
      } else {
        for (var chapter in chapters) {
          // Time conversion helper could go here, but raw ms is okay for now
          final start = (chapter['start'] / 1000).toStringAsFixed(1);
          final end = (chapter['end'] / 1000).toStringAsFixed(1);
          buffer.writeln("• [${start}s - ${end}s] ${chapter['headline']}");
          buffer.writeln("  ${chapter['summary']}"); // Chapter summary
          buffer.writeln();
        }
      }
      buffer.writeln();
    }

    // 4. Auto Highlights (if enabled)
    if (data['auto_highlights_result'] != null &&
        data['auto_highlights_result']['results'] != null) {
      buffer.writeln("=== KEY HIGHLIGHTS ===");
      final List results = data['auto_highlights_result']['results'];
      if (results.isEmpty) {
        buffer.writeln("No highlights detected.");
      } else {
        for (var item in results) {
          buffer.writeln("• ${item['text']} (Count: ${item['count']})");
        }
      }
      buffer.writeln();
    }

    // 5. Content Safety (if enabled)
    if (data['content_safety_labels'] != null &&
        data['content_safety_labels']['results'] != null) {
      final List results = data['content_safety_labels']['results'];
      if (results.isNotEmpty) {
        buffer.writeln("=== CONTENT SAFETY FLAGS ===");
        for (var item in results) {
          buffer.writeln(
            "⚠ ${item['text']}: ${item['labels'][0]['label']} (${(item['labels'][0]['confidence'] * 100).toStringAsFixed(1)}%)",
          );
        }
        buffer.writeln();
      }
    }

    // 6. Sentiment Analysis (if enabled)
    if (data['sentiment_analysis_results'] != null) {
      buffer.writeln("=== SENTIMENT ANALYSIS ===");
      final List sentiments = data['sentiment_analysis_results'];
      int positive = 0;
      int negative = 0;
      int neutral = 0;

      for (var s in sentiments) {
        if (s['sentiment'] == 'POSITIVE')
          positive++;
        else if (s['sentiment'] == 'NEGATIVE')
          negative++;
        else
          neutral++;
      }

      buffer.writeln("Overall Sentiment Breakdown:");
      buffer.writeln("😊 Positive: $positive sentences");
      buffer.writeln("😐 Neutral:  $neutral sentences");
      buffer.writeln("😟 Negative: $negative sentences");
    }

    return buffer.toString();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isLoading ? null : _submitData,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit", style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLines: null,
              spellCheckConfiguration: const SpellCheckConfiguration(),
              onChanged: (value) {
                setState(() {
                  tokenCount = estimateTokens(value);
                });
              },
              decoration: const InputDecoration(
                hintText: "Enter your prompt...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Tokens: $tokenCount",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),

            // Audio file selection section
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickAudioFile,
                    child: const Text("Upload Audio File"),
                  ),
                ),
                if (selectedAudioFile != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAudioConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.settings),
                    label: const Text("Settings"),
                  ),
                ],
              ],
            ),

            if (selectedAudioFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Selected: ${selectedAudioFile!.path.split('/').last}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Language: ${SupportedLanguages.getName(audioConfig.languageCode)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (audioConfig.redactPii)
                      Text(
                        "PII Redaction: Enabled (${audioConfig.redactPiiPolicies.length} categories)",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    if (audioConfig.speakerLabels)
                      const Text(
                        "Speaker Labels: Enabled",
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 15),
            const Text(
              "From:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildCheckboxGroup(fromSelection),
            const SizedBox(height: 20),
            const Text(
              "To:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildCheckboxGroup(toSelection),
            const SizedBox(height: 30),
            if (output != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(output!, style: const TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxGroup(Map<String, bool> selection) {
    return Wrap(
      spacing: 8,
      children: dataTypes.map((type) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selection[type],
              onChanged: (v) => setState(() => selection[type] = v ?? false),
              activeColor: Colors.black,
            ),
            Text(type),
          ],
        );
      }).toList(),
    );
  }
}
