//text to image

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pina/models/image_generation_config.dart';
import 'package:pina/screens/constants.dart'; // Import the model

class ImageGenerationService {
  final String _apiKey = ApiConstants.stabilityApiKey;
  final String _baseUrl =
      "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image";

  // UPDATE: Accept config parameter
  Future<List<Uint8List>> generateImage(
    String prompt,
    ImageGenerationConfig config,
  ) async {
    try {
      Map<String, dynamic> requestBody = config.toJson();
      requestBody["text_prompts"] = [
        {"text": prompt},
      ];
      // requestBody["height"] = 1024;
      // requestBody["width"] = 1024;

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // --- NEW LOGIC: Loop through all artifacts ---
        List<dynamic> artifacts = data["artifacts"];
        List<Uint8List> images = [];

        for (var item in artifacts) {
          images.add(base64Decode(item["base64"]));
        }

        return images; // Return the full list
      } else {
        throw Exception(
          "Failed to generate image: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("Error connecting to Image Service: $e");
    }
  }
}
