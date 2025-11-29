import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pina/screens/constants.dart';
// Import your new LangChain service
import 'package:pina/services/lm_studio_service.dart';

class LandingScreen extends StatefulWidget {
  final String title;
  final String userName;

  const LandingScreen({required this.title, required this.userName, super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController controller = TextEditingController();

  // --- NEW: Initialize the LangChain Service ---
  final LmStudioService _aiService = LmStudioService();

  // Mongo Endpoints (Keep these as they were working)
  final String saveInputUrl = "${ApiConstants.authUrl}/api/save-input";
  final String saveOutputUrl = "${ApiConstants.authUrl}/api/save-output";

  // REMOVED: final String lmUrl... (The service handles this now)

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

  // REMOVED: _callLmStudio function (replaced by _aiService)

  Future<void> _submitData() async {
    final promptText = controller.text.trim();
    if (promptText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a prompt")));
      return;
    }

    setState(() {
      isLoading = true;
      output = null;
    });

    List<String> fromList = _getSelectedList(fromSelection);
    List<String> toList = _getSelectedList(toSelection);
    int? currentPromptId;

    // --- STEP 1: SAVE INPUT (MongoDB) ---
    // (This part remains exactly the same)
    try {
      final res = await http.post(
        Uri.parse(saveInputUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": widget.userName,
          "prompt": promptText,
          "from": fromList.isEmpty ? ["Text"] : fromList,
          "to": toList.isEmpty ? ["Image"] : toList,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        currentPromptId = data['promptId'];
      }
    } catch (e) {
      debugPrint("Mongo Input Error: $e");
    }

    // --- STEP 2: GET AI RESPONSE (UPDATED to use LangChain) ---
    // We switched from manual HTTP to your new Service
    final aiResponse = await _aiService.generateResponse(promptText);

    String aiContent;
    String aiModel;

    // Handle the response map from the service
    if (aiResponse['status'] == 'success') {
      aiContent = aiResponse['content'];
      aiModel = aiResponse['model'];
    } else {
      aiContent = "AI Error: ${aiResponse['content']}";
      aiModel = "error";
    }

    // --- STEP 3: SAVE OUTPUT (MongoDB) ---
    // (This part remains exactly the same)
    if (currentPromptId != null) {
      try {
        await http.post(
          Uri.parse(saveOutputUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "promptId": currentPromptId,
            "content": aiContent,
            "modelName": aiModel,
          }),
        );
      } catch (e) {
        debugPrint("Mongo Output Error: $e");
      }
    }

    setState(() {
      output = aiContent;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // UI remains exactly identical to your working version
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
