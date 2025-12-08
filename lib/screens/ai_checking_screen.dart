import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// TODO: Ensure this IP is correct!
const String myServerUrl = "http://10.187.191.23:4000";

class AiCheckingScreen extends StatefulWidget {
  final int userId;
  const AiCheckingScreen({super.key, required this.userId});

  @override
  State<AiCheckingScreen> createState() => _AiCheckingScreenState();
}

class _AiCheckingScreenState extends State<AiCheckingScreen> {
  File? _selectedMedia;
  String? _mediaType;
  bool _isLoading = false;
  String? _resultMessage;
  double? _deepfakeScore;

  // SIGHTENGINE KEYS
  final String _apiUser = '1502436331';
  final String _apiSecret = '2qs2AefqLFdFanbxQXKEAWxfvp9pAbt6';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia(bool isVideo) async {
    final XFile? pickedFile;
    if (isVideo) {
      pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    }

    if (pickedFile != null) {
      setState(() {
        _selectedMedia = File(pickedFile!.path);
        _mediaType = isVideo ? 'video' : 'image';
        _resultMessage = null;
        _deepfakeScore = null;
      });
    }
  }

  // --- STEP 1: Upload File to Backend ---
  Future<int?> _saveInputToBackend() async {
    try {
      var uri = Uri.parse("$myServerUrl/api/deepfake/save-input");
      var request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = widget.userId.toString();
      request.fields['category'] = _mediaType!;

      request.files.add(
        await http.MultipartFile.fromPath('media', _selectedMedia!.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['deepId'];
      } else {
        print("Backend Save Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Backend Connection Error: $e");
      return null;
    }
  }

  // --- STEP 2: Check with Sightengine ---
  Future<Map<String, dynamic>?> _checkWithSightEngine() async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.sightengine.com/1.0/check.json'),
      );

      request.fields['models'] = 'deepfake';
      request.fields['api_user'] = _apiUser;
      request.fields['api_secret'] = _apiSecret;
      request.files.add(
        await http.MultipartFile.fromPath('media', _selectedMedia!.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Sightengine Error: $e");
    }
    return null;
  }

  // --- STEP 3: Save Result to Backend (UPDATED) ---
  // We now pass the apiMediaId to be stored as outputId
  Future<void> _saveOutputToBackend(
    int deepId,
    double score,
    String verdict,
    String apiMediaId,
  ) async {
    try {
      final url = Uri.parse("$myServerUrl/api/deepfake/save-output");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "deepId": deepId,
          "userId": widget.userId,
          "resultScore": score,
          "resultVerdict": verdict,
          "outputId": apiMediaId, // Sending the ID from the API
        }),
      );
      print("Backend Output Saved.");
    } catch (e) {
      print("Error saving output: $e");
    }
  }

  // --- MAIN FUNCTION ---
  Future<void> _startProcess() async {
    if (_selectedMedia == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "Saving to database...";
    });

    // 1. Save Input
    int? deepId = await _saveInputToBackend();

    if (deepId == null) {
      setState(() {
        _isLoading = false;
        _resultMessage = "Failed to upload to server.";
      });
      return;
    }

    setState(() => _resultMessage = "Checking with AI...");

    // 2. Check with AI
    var aiData = await _checkWithSightEngine();

    if (aiData != null && aiData['status'] == 'success') {
      double score = 0.0;
      if (aiData['type'] != null && aiData['type']['deepfake'] != null) {
        score = (aiData['type']['deepfake'] as num).toDouble();
      }

      // Extract the Media ID from the API response
      // Structure is usually: { "media": { "id": "med_123...", ... } }
      String apiMediaId = "unknown";
      if (aiData['media'] != null && aiData['media']['id'] != null) {
        apiMediaId = aiData['media']['id'];
      }

      String verdict = _getInterpretation(score);

      // 3. Save Output (Passing the media ID)
      await _saveOutputToBackend(deepId, score, verdict, apiMediaId);

      setState(() {
        _deepfakeScore = score;
        _resultMessage = verdict;
      });
    } else {
      setState(() => _resultMessage = "AI Check Failed.");
    }

    setState(() => _isLoading = false);
  }

  String _getInterpretation(double score) {
    if (score > 0.80) return "⚠️ High Probability of Deepfake";
    if (score > 0.50) return "⚠️ Possible Deepfake / Suspicious";
    return "✅ Likely Real Media";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Deepfake Check"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              alignment: Alignment.center,
              child: _selectedMedia == null
                  ? const Text("No media selected")
                  : _mediaType == 'image'
                  ? Image.file(_selectedMedia!, fit: BoxFit.contain)
                  : const Icon(Icons.videocam, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickMedia(false),
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Image"),
                  ),
                ),
                const SizedBox(width: 10),
                // Expanded(
                //   child: ElevatedButton.icon(
                //     onPressed: _isLoading ? null : () => _pickMedia(true),
                //     icon: const Icon(Icons.videocam),
                //     label: const Text("Pick Video"),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || _selectedMedia == null)
                    ? null
                    : _startProcess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Check with AI",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ),
            if (_deepfakeScore != null) ...[
              const SizedBox(height: 20),
              Text(
                "Score: ${(_deepfakeScore! * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _resultMessage ?? "",
                style: TextStyle(
                  fontSize: 18,
                  color: _deepfakeScore! > 0.5 ? Colors.red : Colors.green,
                ),
              ),
            ] else if (_resultMessage != null) ...[
              const SizedBox(height: 20),
              Text(_resultMessage!, style: const TextStyle(color: Colors.blue)),
            ],
          ],
        ),
      ),
    );
  }
}
