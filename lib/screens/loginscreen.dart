import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pina/screens/constants.dart';
import 'package:pina/screens/registration.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pina/screens/main_menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId:
        "684725372087-u0b483gfcj92mhfckg4oo3f04cbf7q1r.apps.googleusercontent.com",
    serverClientId:
        "684725372087-9018mjvp79oq4u1u74u249lm7lt2t8cd.apps.googleusercontent.com",
  );

  Future<void> _saveUserSession(int userId, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
  }

  // Standard Email/Password Login
  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Enter email & password");
      return;
    }

    setState(() => loading = true);

    try {
      final url = Uri.parse("${ApiConstants.authUrl}/api/auth/login");

      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        showMessage("Login successful");

        String userName = "User";
        String userEmail = email;
        int? userId;

        if (data['user'] != null) {
          userName = data['user']['name'] ?? userName;
          userEmail = data['user']['email'] ?? userEmail;
          userId = data['user']['userId'];
        }

        if (userId != null) {
          await _saveUserSession(userId, userName, userEmail);
        }

        if (mounted) {
          // --- FIXED: Pass userId to MainMenuScreen ---
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainMenuScreen(
                userName: userName,
                userEmail: userEmail,
                userId: userId?.toString(), // <--- ADDED THIS
              ),
            ),
          );
        }
      } else {
        showMessage(data["toastMessage"] ?? "Invalid credentials");
      }
    } catch (e) {
      print(e);
      showMessage("Server error: $e");
    }

    setState(() => loading = false);
  }

  // Google Sign-In Logic
  Future<void> signInWithGoogle() async {
    setState(() => loading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        showMessage("Failed to retrieve Google ID Token.");
        await _googleSignIn.signOut();
        setState(() => loading = false);
        return;
      }

      final url = Uri.parse("${ApiConstants.authUrl}/api/auth/google-auth");

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"idToken": idToken}),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);

      if (mounted) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data["success"] == true) {
          showMessage("Google Login successful!");

          String userName = "User";
          String userEmail = "";
          int? userId;

          if (data['user'] != null) {
            userName = data['user']['name'] ?? userName;
            userEmail = data['user']['email'] ?? "";
            userId = data['user']['userId'];
          }

          if (userEmail.isEmpty) {
            userEmail = googleUser.email;
          }

          if (userId != null) {
            await _saveUserSession(userId, userName, userEmail);
          }

          // --- FIXED: Pass userId to MainMenuScreen ---
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainMenuScreen(
                userName: userName,
                userEmail: userEmail,
                userId: userId?.toString(), // <--- ADDED THIS
              ),
            ),
          );
        } else if (response.statusCode == 409) {
          showMessage("Account exists with password. Please login manually.");
        } else {
          showMessage(data["message"] ?? "Google Login failed on server.");
        }
      }

      await _googleSignIn.signOut();
    } catch (error) {
      showMessage("An error occurred during Google Sign-In.");
    }

    setState(() => loading = false);
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    // UI remains exactly the same as before
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Login",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : loginUser,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login"),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Registration()),
                      );
                    },
                    child: const Text("Sign Up"),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR LOGIN WITH"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: loading ? null : signInWithGoogle,
                  child: socialIcon("assets/icons/google.png"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
