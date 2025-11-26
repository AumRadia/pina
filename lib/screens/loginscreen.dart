import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pina/screens/registration.dart';
import 'package:pina/screens/trial.dart';
import 'dart:async';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers keep the latest auth input in memory.
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false; // Toggles button state and spinner visibility.

  // 1. Setup Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId:
        "684725372087-u0b483gfcj92mhfckg4oo3f04cbf7q1r.apps.googleusercontent.com",
    serverClientId:
        "684725372087-9018mjvp79oq4u1u74u249lm7lt2t8cd.apps.googleusercontent.com",
  );

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
      final url = Uri.parse("http://10.11.161.23:4000/api/auth/login");

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException("Login timed out. Please retry.");
      });

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        showMessage("Login successful");
        print("TOKEN: ${data['token']}");

        // --- FETCH USER DETAILS FROM DB RESPONSE ---
        String userName = "User";
        String userEmail = email; // Default to the typed email

        if (data['user'] != null) {
          userName = data['user']['name'] ?? userName;
          userEmail = data['user']['email'] ?? userEmail;
        }

        // Navigate to Trial with the NAME and EMAIL
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Trial(
                userName: userName,
                userEmail: userEmail, // Passing the real email
              ),
            ),
          );
        }
      } else {
        showMessage(data["toastMessage"] ?? "Invalid credentials");
      }
    } catch (e) {
      print(e);
      showMessage("Server error");
    }

    setState(() => loading = false);
  }

  // 2. Google Sign-In Logic
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

      const baseUrl = "http://10.11.161.23:4000";
      final url = Uri.parse("$baseUrl/api/auth/google-auth");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idToken": idToken}),
      ).timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException("Google sign-in timed out. Please retry.");
      });

      final data = jsonDecode(response.body);

      // Handle Success
      if (mounted) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data["success"] == true) {
          showMessage("Google Login successful!");

          // --- FETCH USER DETAILS FROM DB RESPONSE ---
          String userName = "User";
          String userEmail = "";

          if (data['user'] != null) {
            userName = data['user']['name'] ?? userName;
            userEmail = data['user']['email'] ?? "";
          }

          // Fallback: If DB didn't send email, get it from Google object
          if (userEmail.isEmpty) {
            userEmail = googleUser.email;
          }

          // Navigate to Trial with the NAME and EMAIL
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Trial(
                userName: userName,
                userEmail: userEmail, // Passing the real email
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
      print("GOOGLE_ERROR--->$error");
      showMessage("An error occurred during Google Sign-In.");
    }
    setState(() => loading = false);
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Reusable branded circle avatar for OAuth buttons.
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

                // Email Field
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                // Password Field
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 30),

                // Login Button
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

                // Sign Up Button
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
