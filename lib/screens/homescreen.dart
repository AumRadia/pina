import 'package:flutter/material.dart';
import 'package:pina/screens/loginscreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Function to handle navigation
  void _handleSearch(BuildContext context, String value) {
    if (value.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      // Optional: Show a snackbar if input is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter something to search")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local controller keeps widget stateless while capturing input.
    final TextEditingController _searchController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Welcome Home"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        // drawer: const HamburgerMenu(), // You can add your drawer here
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Find what\nyou need",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),

            // --- SEARCH BAR ---
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction:
                    TextInputAction.search, // Shows 'Search' button on keyboard
                onSubmitted: (value) => _handleSearch(context, value),
                decoration: InputDecoration(
                  hintText: "Search anything...",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DUMMY LOGIN SCREEN FOR TESTING ---
// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Login Screen")),
//       body: const Center(child: Text("Navigated here successfully!")),
//     );
//   }
// }
