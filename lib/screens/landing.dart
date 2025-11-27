import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LandingScreen extends StatefulWidget {
  final String title;

  const LandingScreen({required this.title, super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController controller = TextEditingController();

  // MongoDB route (your server)
  final String backendUrl = "http://10.74.182.23:4000/api/save-input";

  // LM Studio local model endpoint
  final String lmUrl = "http://127.0.0.1:1234/v1/chat/completions";

  // Output text from LM Studio
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

  // 🔥 LM Studio call
  Future<String?> _callLmStudio(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(lmUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": "google/gemma-3-4b",
          "messages": [
            {"role": "user", "content": prompt},
          ],
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["choices"][0]["message"]["content"];
      } else {
        return "LM Studio Error: ${res.body}";
      }
    } catch (e) {
      return "LM Studio Connection Error: $e";
    }
  }

  // 🔥 Submit: Save + Call LM Studio + Show Output
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
      output = null; // reset output
    });

    List<String> fromList = _getSelectedList(fromSelection);
    List<String> toList = _getSelectedList(toSelection);

    // 🔹 Step 1 — Save to MongoDB
    try {
      await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": "AppUser",
          "prompt": promptText,
          "from": fromList.isEmpty ? ["Text"] : fromList,
          "to": toList.isEmpty ? ["Image"] : toList,
        }),
      );
    } catch (e) {
      debugPrint("Mongo Error: $e");
    }

    // 🔹 Step 2 — Call LM Studio and update UI
    String? modelOutput = await _callLmStudio(promptText);

    setState(() {
      output = modelOutput; // show AI output
      isLoading = false;
    });
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
            // Search Bar
            TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Enter your prompt...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),

            const SizedBox(height: 25),
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

            // 🔥 OUTPUT SECTION
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
