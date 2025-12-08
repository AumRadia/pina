// lib/services/submission_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pina/screens/constants.dart';

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
  // New endpoint assumption for pre-check

  final String checkStatusUrl =
      "${ApiConstants.authUrl}/api/auth/check-user-status";

  /// New: Checks if user is Active, Paid, and has Tokens BEFORE entering screens
  Future<SubmissionResult> checkUserEligibility({
    required String userEmail,
  }) async {
    try {
      // Assuming your backend has a lightweight status check endpoint
      // If not, you might need to adapt this to your existing backend logic
      final res = await http.post(
        Uri.parse(checkStatusUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userEmail": userEmail}),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return SubmissionResult(success: true, statusCode: 200);
      } else {
        return SubmissionResult(
          success: false,
          errorMessage: body['error'] ?? "Account not eligible",
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      // Fail open or closed depending on preference. Here we fail closed.
      return SubmissionResult(
        success: false,
        errorMessage: "Connection failed: $e",
        statusCode: 500,
      );
    }
  }

  // ... (Keep existing validateAndSaveInput and saveOutput methods exactly as they were) ...
  Future<SubmissionResult> validateAndSaveInput({
    required String userName,
    required String userEmail,
    required String prompt,
    required List<String> fromList,
    required List<String> toList,
  }) async {
    // ... existing code ...
    // (Included for context, no changes needed here provided it's the same file)
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
        return SubmissionResult(
          success: false,
          errorMessage: body['error'] ?? "Permission denied",
          statusCode: 403,
        );
      } else if (res.statusCode == 401) {
        return SubmissionResult(
          success: false,
          errorMessage: "Session invalid. Please login again.",
          statusCode: 401,
        );
      } else {
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

  Future<void> saveOutput({
    required int promptId,
    required String content,
    required String modelName,
  }) async {
    // ... existing code ...
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
