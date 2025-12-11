import 'package:flutter/material.dart';
import 'package:pina/data/translation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pina/screens/ai_checking_screen.dart';
import 'package:pina/screens/explicit_content_check_screen.dart';
import 'package:pina/screens/gdpr_scanner_screen.dart';
import 'package:pina/screens/plagarism_check.dart';
import 'package:pina/screens/reverse_search_screen.dart';
// Import Main Menu for the "Conversion" navigation
import 'package:pina/screens/main_menu_screen.dart';

const String baseUrl = "http://10.11.161.23:4000";

class HamburgerMenu extends StatelessWidget {
  // Added userId and userEmail to pass to MainMenuScreen during navigation
  final String? userId;
  final String? userName;
  final String? userEmail;
  final VoidCallback? onLogout;
  final String selectedLanguage;
  final Function(String)? onLanguageChanged;

  const HamburgerMenu({
    super.key,
    this.userId,
    this.userName,
    this.userEmail,
    this.onLogout,
    this.selectedLanguage = 'English',
    this.onLanguageChanged,
  });

  String getLabel(String id) {
    return AppLocale.translations[id]?[selectedLanguage] ?? id;
  }

  // --- FUNCTION: Shows the Contact Dialog ---
  void _showContactDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Contact Us"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Send a message directly to the developer."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Type your message here...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final message = messageController.text.trim();
                          if (message.isEmpty) return;

                          setState(() {
                            isLoading = true;
                          });

                          try {
                            final fullMessage =
                                "User: ${userName ?? 'Guest'}\n\nMessage:\n$message";

                            final response = await http.post(
                              Uri.parse('$baseUrl/api/telegram/send'),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({"message": fullMessage}),
                            );

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (response.statusCode == 200) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Message sent successfully!"),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Failed to send: ${response.body}",
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Send"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper to show a "Coming Soon" message
  void _showComingSoon(BuildContext context, String featureName) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$featureName is coming soon!")));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- HEADER ---
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            child: userName != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Hi, $userName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      "Menu",
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
          ),

          // 1. HOME
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Home"),
            onTap: () {
              // Assuming Home is the initial route, or simply close drawer
              Navigator.pop(context);
            },
          ),

          // 2. EDUCATION -> GOVT SCHOOL -> MICROSOFT NCS
          ExpansionTile(
            leading: const Icon(Icons.school),
            title: const Text("Education"),
            childrenPadding: const EdgeInsets.only(left: 20),
            children: [
              ExpansionTile(
                leading: const Icon(Icons.account_balance),
                title: const Text("Govt School"),
                childrenPadding: const EdgeInsets.only(left: 20),
                children: [
                  ListTile(
                    leading: const Icon(Icons.computer),
                    title: const Text("Microsoft NCS"),
                    onTap: () => _showComingSoon(context, "Microsoft NCS"),
                  ),
                ],
              ),
            ],
          ),

          // 3. CONVERSION (Opens Main Menu Screen)
          ListTile(
            leading: const Icon(Icons.transform),
            title: const Text("Conversion"),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainMenuScreen(
                    userId: userId,
                    userName: userName,
                    userEmail: userEmail,
                  ),
                ),
              );
            },
          ),

          // 4. ENTERPRISE AI -> SOVEREIGN DATA
          ExpansionTile(
            leading: const Icon(Icons.business),
            title: const Text("Enterprise AI"),
            childrenPadding: const EdgeInsets.only(left: 20),
            children: [
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text("Sovereign Data"),
                onTap: () => _showComingSoon(context, "Sovereign Data"),
              ),
            ],
          ),

          // 5. TOOLS (Existing items moved here)
          ExpansionTile(
            leading: const Icon(Icons.handyman_outlined),
            title: const Text("Tools"),
            childrenPadding: const EdgeInsets.only(left: 20),
            children: [
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.deepPurple,
                ),
                title: const Text("AI Checking (Deepfake)"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiCheckingScreen(userId: 1),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copyright, color: Colors.orange),
                title: const Text("IP Infringement Check"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReverseSearchScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.explicit, color: Colors.redAccent),
                title: const Text("Explicit Content Check"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExplicitContentCheckScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_all, color: Colors.blueGrey),
                title: const Text("Plagiarism Check"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CopyleaksScanScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: const Text("GDPR Compliance Check"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GDPRScannerScreen()),
                ),
              ),
            ],
          ),

          // 6. PRICING
          ListTile(
            leading: const Icon(Icons.price_change),
            title: const Text("Pricing"),
            onTap: () => _showComingSoon(context, "Pricing"),
          ),

          const Divider(),

          // 7. ABOUT US -> LEGAL & CONTACT US
          ExpansionTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About Us"),
            childrenPadding: const EdgeInsets.only(left: 20),
            children: [
              ListTile(
                leading: const Icon(Icons.gavel),
                title: const Text("Legal"),
                onTap: () => _showComingSoon(context, "Legal Information"),
              ),
              ListTile(
                leading: const Icon(Icons.contact_support_outlined),
                title: Text(getLabel('contact_us')),
                onTap: () {
                  Navigator.pop(context);
                  _showContactDialog(context);
                },
              ),
            ],
          ),

          // 8. LOGOUT
          if (onLogout != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: onLogout,
            ),
          ],
        ],
      ),
    );
  }
}
