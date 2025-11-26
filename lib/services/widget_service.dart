// lib/services/widget_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/widget_model.dart';

// Handles every HTTP interaction with the widget marketplace backend.
class WidgetService {
  // REPLACE THIS WITH YOUR ACTUAL LAPTOP IP
  static const String baseUrl = "http://10.11.161.23:4000";

  // --- 1. FETCH ALL WIDGETS (For the "Add Widget" Dialog) ---
  // Calls: GET /api/widgets/widgets
  Future<List<MarketWidget>> getWidgets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/widgets/widgets'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MarketWidget.fromJson(json)).toList();
      } else {
        print("Failed to fetch marketplace: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching marketplace widgets: $e");
      return [];
    }
  }

  // --- 2. FETCH USER'S SAVED WIDGETS (For the Main Screen List) ---
  // Calls: GET /api/widgets/userWidgets?userEmail=...
  Future<List<dynamic>> getUserWidgets(String userEmail) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/widgets/userWidgets?userEmail=$userEmail'),
      );

      if (response.statusCode == 200) {
        // This returns an array of simple objects: { widgetName: "...", widgetId: "..." }
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching user widgets: $e");
      return [];
    }
  }

  // --- 3. ADD WIDGET TO USER PROFILE ---
  // Calls: POST /api/widgets/userWidgets
  Future<bool> addWidgetToUser(
    String userEmail,
    String widgetName,
    String widgetId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/widgets/userWidgets'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userEmail": userEmail,
          "widgetName": widgetName,
          "widgetId": widgetId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error adding widget: $e");
      return false;
    }
  }

  // --- 4. REMOVE WIDGET FROM USER PROFILE ---
  // Calls: DELETE /api/widgets/userWidgets
  Future<bool> removeWidgetFromUser(String userEmail, String widgetName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/widgets/userWidgets'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userEmail": userEmail, "widgetName": widgetName}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting widget: $e");
      return false;
    }
  }
}
