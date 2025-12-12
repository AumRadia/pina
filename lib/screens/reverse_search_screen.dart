import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// 1. IMPORT YOUR CONSTANTS FILE
import 'package:pina/screens/constants.dart';
// Adjust path if needed (e.g., '../utils/constants.dart')

class ReverseSearchScreen extends StatefulWidget {
  const ReverseSearchScreen({super.key});

  @override
  State<ReverseSearchScreen> createState() => _ReverseSearchScreenState();
}

class _ReverseSearchScreenState extends State<ReverseSearchScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _hasSearched = false;
  List<dynamic> _searchResults = [];

  // ---------------------------------------------------------------------------
  // CONFIGURATION
  // ---------------------------------------------------------------------------
  // 2. REMOVED HARDCODED IP. We will use ApiConstants.authUrl below.

  final String _rapidApiKey =
      'd263ef909fmshb759fc69333fc69p193a4cjsn3930b099209b';
  final String _rapidApiHost = 'reverse-image-search1.p.rapidapi.com';

  final String _cloudinaryCloudName = 'djf1fggtn';
  final String _cloudinaryUploadPreset = 'hpnktmpr';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _searchResults = [];
        _hasSearched = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN WORKFLOW
  // ---------------------------------------------------------------------------
  Future<void> _performReverseSearch() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // 1. Get User ID
      final prefs = await SharedPreferences.getInstance();
      final int? userIdInt = prefs.getInt('userId');
      final String userId = userIdInt?.toString() ?? "unknown_user";

      // 2. Save Input to MongoDB (Get ipId)
      debugPrint("Step 1: Saving input to DB for user $userId...");
      final int ipId = await _saveInputToBackend(userId, _selectedImage!);
      debugPrint("DB Input Saved. Generated ipId: $ipId");

      // 3. Upload to Cloudinary (Required for RapidAPI)
      debugPrint("Step 2: Uploading to Cloudinary...");
      String publicImageUrl = await _uploadToCloudinary(_selectedImage!);

      // 4. Search API
      debugPrint("Step 3: Searching RapidAPI...");
      final apiResults = await _callRapidApi(publicImageUrl);

      // 5. Save Output to MongoDB
      debugPrint("Step 4: Saving output to DB...");
      await _saveOutputToBackend(ipId, apiResults);

      setState(() {
        _searchResults = apiResults;
      });
    } catch (e) {
      debugPrint("Error in process: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BACKEND HELPER METHODS
  // ---------------------------------------------------------------------------

  Future<int> _saveInputToBackend(String userId, File imageFile) async {
    // 3. FIX: Use ApiConstants.authUrl (which includes :4000)
    final uri = Uri.parse(
      '${ApiConstants.authUrl}/api/image-search/save-input',
    );

    print("Connecting to: $uri"); // Debug log

    // Convert image to Base64
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'image': base64Image}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['ipId']; // Returns the counter ID from DB
    } else {
      throw Exception('Failed to save input: ${response.body}');
    }
  }

  Future<void> _saveOutputToBackend(int ipId, dynamic apiResults) async {
    // 4. FIX: Use ApiConstants.authUrl here too
    final uri = Uri.parse(
      '${ApiConstants.authUrl}/api/image-search/save-output',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ipId': ipId, 'apiOutput': apiResults}),
    );

    if (response.statusCode != 200) {
      debugPrint('Failed to save output: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // EXTERNAL API HELPERS
  // ---------------------------------------------------------------------------

  Future<String> _uploadToCloudinary(File image) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);
      return jsonMap['secure_url'];
    } else {
      throw Exception('Cloudinary Upload Failed: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> _callRapidApi(String imageUrl) async {
    final uri = Uri.https(_rapidApiHost, '/reverse-image-search', {
      'url': imageUrl,
      'limit': '10',
      'safe_search': 'off',
    });

    final response = await http.get(
      uri,
      headers: {
        'X-RapidAPI-Key': _rapidApiKey,
        'X-RapidAPI-Host': _rapidApiHost,
      },
    );

    if (response.statusCode == 200) {
      final dynamic decodedData = json.decode(response.body);
      List<dynamic> foundImages = [];

      if (decodedData is List) {
        foundImages = decodedData;
      } else if (decodedData is Map<String, dynamic>) {
        if (decodedData.containsKey('data') && decodedData['data'] is List) {
          foundImages = decodedData['data'];
        } else if (decodedData.containsKey('results') &&
            decodedData['results'] is List) {
          foundImages = decodedData['results'];
        } else if (decodedData.containsKey('content') &&
            decodedData['content'] is List) {
          foundImages = decodedData['content'];
        }
      }
      return foundImages;
    } else {
      throw Exception('RapidAPI Failed: ${response.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reverse Image Search'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text("Tap to upload image"),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performReverseSearch,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isLoading ? "Processing..." : "Find Similar Images",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return Center(
                      child: Text(
                        "Saving & Searching...",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }
                  if (_hasSearched && _searchResults.isEmpty) {
                    return const Center(
                      child: Text(
                        "No similar results found.",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  if (!_hasSearched && _searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        "Upload an image to start.",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      final title = result['title'] ?? 'Similar Image';
                      final url = result['url'] ?? '';
                      final thumb = result['thumbnail'] ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: thumb.isNotEmpty
                              ? Image.network(
                                  thumb,
                                  width: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) =>
                                      const Icon(Icons.image),
                                )
                              : const Icon(Icons.link),
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
