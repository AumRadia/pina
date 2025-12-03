import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pina/screens/constants.dart';

// A simple result class to handle the different states cleanly
class SubmissionResult {
  final bool success;
  final String? errorMessage;
  final int? promptId;
  final int statusCode;

  SubmissionResult({
    required this.success,
    this.errorMessage,
    this.promptId,
    required this.statusCode,
  });
}

class SubmissionService {
  final String saveInputUrl = "${ApiConstants.authUrl}/api/save-input";
  final String saveOutputUrl = "${ApiConstants.authUrl}/api/save-output";

  /// Standard function to Validate User & Save Input
  /// Checks: Active Status, Paid Status, Token Count (>10)
  Future<SubmissionResult> validateAndSaveInput({
    required String userName,
    required String userEmail,
    required String prompt,
    required List<String> fromList,
    required List<String> toList,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(saveInputUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": userName,
          "userEmail": userEmail,
          "prompt": prompt,
          "from": fromList,
          "to": toList,
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return SubmissionResult(
          success: true,
          promptId: body['promptId'],
          statusCode: 200,
        );
      } else if (res.statusCode == 403) {
        // Specific Business Logic Errors (Not Paid, Not Active, Low Tokens)
        return SubmissionResult(
          success: false,
          errorMessage: body['error'] ?? "Permission denied",
          statusCode: 403,
        );
      } else if (res.statusCode == 401) {
        // Auth Error
        return SubmissionResult(
          success: false,
          errorMessage: "Session invalid. Please login again.",
          statusCode: 401,
        );
      } else {
        // Server Error
        return SubmissionResult(
          success: false,
          errorMessage: body['error'] ?? "Unknown Server Error",
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return SubmissionResult(
        success: false,
        errorMessage: "Connection failed: $e",
        statusCode: 500,
      );
    }
  }

  /// Standard function to save the AI output
  Future<void> saveOutput({
    required int promptId,
    required String content,
    required String modelName,
  }) async {
    try {
      await http.post(
        Uri.parse(saveOutputUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "promptId": promptId,
          "content": content,
          "modelName": modelName,
        }),
      );
    } catch (e) {
      print("Error saving output: $e");
    }
  }
}
