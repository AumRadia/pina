import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pina/screens/constants.dart';
import 'package:pina/screens/loginscreen.dart';

class RegistrationStep2 extends StatefulWidget {
  final String name;
  final String email;
  final String mobile;
  final String password;
  final File? imageFile;

  const RegistrationStep2({
    super.key,
    required this.name,
    required this.email,
    required this.mobile,
    required this.password,
    this.imageFile,
  });

  @override
  State<RegistrationStep2> createState() => _RegistrationStep2State();
}

class _RegistrationStep2State extends State<RegistrationStep2> {
  String userType = "free"; // Default
  String accountType = "private"; // Default

  bool isLoading = false;

  void showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> registerUser() async {
    setState(() => isLoading = true);

    try {
      final url = Uri.parse("${ApiConstants.authUrl}/api/auth/register");

      String? base64Image;
      if (widget.imageFile != null) {
        List<int> imageBytes = await widget.imageFile!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      // Payload matching backend expectations
      final Map<String, dynamic> payload = {
        "name": widget.name,
        "email": widget.email,
        "mobile": widget.mobile,
        "password": widget.password,
        "profilePicture": base64Image,
        "userType": userType,
        "accountType": accountType,
        "status": "active", // Force active
        "balance": 0, // Force 0
      };

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data["success"] == true) {
        showMessage("Registration Successful!");

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // Go to login screen and remove history
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
          );
        }
      } else {
        showMessage(data["toastMessage"] ?? "Registration Failed");
      }
    } catch (e) {
      print("REG ERROR: $e");
      showMessage("Server error or timeout. Check connection.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Final Step"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Account Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // User Type Dropdown
            const Text("Subscription Type:"),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: userType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "free", child: Text("Free")),
                DropdownMenuItem(value: "paid", child: Text("Paid")),
              ],
              onChanged: (value) => setState(() => userType = value!),
            ),

            const SizedBox(height: 20),

            // Account Type Dropdown
            const Text("Account Category:"),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: accountType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "private", child: Text("Private")),
                DropdownMenuItem(value: "NGO", child: Text("NGO")),
              ],
              onChanged: (value) => setState(() => accountType = value!),
            ),

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Complete Registration",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
