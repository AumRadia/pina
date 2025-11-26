import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/screens/interest.dart'; // Import Interest Screen
import 'dart:async';
// --- CONFIGURATION ---
// UPDATED IP ADDRESS
const String baseUrl = "http://10.11.161.23:4000";

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  String userCategory = "private"; // Dropdown selection.

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        "684725372087-9018mjvp79oq4u1u74u249lm7lt2t8cd.apps.googleusercontent.com",
  );

  // Basic form controllers.
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  File? selectedImage;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () async {
                  final picked = await picker.pickImage(
                    imageQuality: 50,
                    maxWidth: 150,
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    setState(() => selectedImage = File(picked.path));
                  }
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Gallery"),
                onTap: () async {
                  final picked = await picker.pickImage(
                    imageQuality: 50,
                    maxWidth: 150,
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    setState(() => selectedImage = File(picked.path));
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- GOOGLE SIGN IN ---
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return; // Cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        showMessage("Failed to retrieve Google ID Token.");
        await _googleSignIn.signOut();
        return;
      }

      // 1. UPDATED URL
      final url = Uri.parse("$baseUrl/api/auth/google-auth");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idToken": idToken}),
      ).timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException("Google sign-in timed out. Please retry.");
      });

      final data = jsonDecode(response.body);

      if (mounted) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data["success"] == true) {
          showMessage("Signed in with Google successfully!");

          // Extract Data
          String userName = "User";
          String userEmail = "";

          if (data['user'] != null) {
            userName = data['user']['name'] ?? userName;
            userEmail = data['user']['email'] ?? "";
          }
          if (userEmail.isEmpty) {
            userEmail = googleUser.email;
          }

          // 2. NAVIGATE TO INTEREST SCREEN
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  Interest(userName: userName, userEmail: userEmail),
            ),
          );
        } else {
          showMessage(data["message"] ?? "Google Sign-In failed on server.");
        }
      }

      await _googleSignIn.signOut();
    } catch (error) {
      print("GOOGLE_ERROR--->$error");
      if (mounted) {
        showMessage("An error occurred during Google Sign-In.");
      }
    }
  }

  // --- MANUAL REGISTRATION ---
  Future<void> registerUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final mobile = mobileController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || mobile.isEmpty || password.isEmpty) {
      showMessage("All fields required");
      return;
    }

    try {
      // 1. UPDATED URL
      final url = Uri.parse("$baseUrl/api/auth/register");

      String? base64Image;
      if (selectedImage != null) {
        List<int> imageBytes = await selectedImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "mobile": mobile,
          "password": password,
          "status": "active",
          "usertype": "free",
          "profilePicture": base64Image,
        }),
      ).timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException("Registration timed out. Please retry.");
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data["success"] == true) {
        showMessage("Registration Success!");

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // 2. NAVIGATE TO INTEREST SCREEN (Passing Name & Email)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Interest(userName: name, userEmail: email),
            ),
          );
        }
      } else {
        showMessage(data["toastMessage"] ?? "Failed");
      }
    } catch (e) {
      print("REG ERROR: $e");
      showMessage("Server error. Check connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Image
            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.blue.shade200,
                backgroundImage: selectedImage != null
                    ? FileImage(selectedImage!)
                    : null,
                child: selectedImage == null
                    ? Icon(Icons.camera_alt, size: 40, color: Colors.white70)
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            // Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Email
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Mobile
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Mobile",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Password
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            DropdownButtonFormField<String>(
              value: userCategory,
              decoration: const InputDecoration(
                labelText: "Account Type",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "private", child: Text("Private")),
                DropdownMenuItem(value: "company", child: Text("Company")),
              ],
              onChanged: (value) {
                setState(() {
                  userCategory = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: registerUser,
                child: const Text("Register"),
              ),
            ),
            const SizedBox(height: 20),
            // Login Link
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: const Text("Already a user"),
              ),
            ),

            const SizedBox(height: 25),

            // Social Icons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: signInWithGoogle,
                  child: socialIcon("assets/icons/google.png"),
                ),
                const SizedBox(width: 20),
                socialIcon("assets/icons/instagram.png"),
                const SizedBox(width: 20),
                socialIcon("assets/icons/facebook.png"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget socialIcon(String assetPath) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset(assetPath),
      ),
    );
  }
}
