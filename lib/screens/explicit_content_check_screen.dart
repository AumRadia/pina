import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this
import 'package:pina/screens/constants.dart'; // Assuming ApiConstants is here

class ExplicitContentCheckScreen extends StatefulWidget {
  const ExplicitContentCheckScreen({super.key});

  @override
  State<ExplicitContentCheckScreen> createState() =>
      _ExplicitContentCheckScreenState();
}

class _ExplicitContentCheckScreenState
    extends State<ExplicitContentCheckScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _results = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _checkContent() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = null;
    });

    try {
      // 1. Get current User ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(
        'userId',
      ); // Ensure this matches how you saved it

      if (userId == null) {
        throw Exception("User not logged in");
      }

      // 2. Point to YOUR Node.js server
      // Make sure ApiConstants.authUrl is your server URL (e.g., http://192.168.x.x:4000)
      final uri = Uri.parse('${ApiConstants.authUrl}/api/safety/analyze');

      var request = http.MultipartRequest('POST', uri);

      // Add UserId to fields
      request.fields['userId'] = userId.toString();

      // Add Image file
      request.files.add(
        await http.MultipartFile.fromPath('media', _selectedImage!.path),
      );

      print("Sending request to Backend...");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        setState(() {
          // The backend returns the nudity object inside the response
          _results = jsonResponse['nudity'];
        });
      } else {
        String errorMsg = jsonResponse['error'] ?? "Unknown Server Error";
        throw Exception(errorMsg);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getScoreColor(double score, bool isSafeCategory) {
    if (isSafeCategory) {
      return score > 0.8
          ? Colors.green
          : (score > 0.5 ? Colors.orange : Colors.red);
    } else {
      return score < 0.2
          ? Colors.green
          : (score < 0.5 ? Colors.orange : Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explicit Content Check"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 10),
                          Text("Select an image to analyze"),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: (_selectedImage != null && !_isLoading)
                  ? _checkContent
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Analyze Image"),
            ),
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (_results != null) ...[
              const Text(
                "Analysis Results:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildResultTile(
                "Safe Content",
                _results!['safe'] ?? 0.0,
                Icons.check_circle_outline,
                true,
              ),
              const SizedBox(height: 10),
              _buildResultTile(
                "Partial Nudity",
                _results!['partial'] ?? 0.0,
                Icons.warning_amber_rounded,
                false,
              ),
              const SizedBox(height: 10),
              _buildResultTile(
                "Explicit / Raw",
                _results!['raw'] ?? 0.0,
                Icons.block,
                false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(
    String title,
    double score,
    IconData icon,
    bool isSafeCategory,
  ) {
    String percentage = "${(score * 100).toStringAsFixed(1)}%";
    Color color = _getScoreColor(score, isSafeCategory);

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          percentage,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
