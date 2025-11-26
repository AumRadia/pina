import 'package:flutter/material.dart';
import 'package:pina/data/translation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = "http://10.11.161.23:4000";

// Drawer widget shared between Trial and MyAi screens.
class HamburgerMenu extends StatelessWidget {
  final String? userName;
  final VoidCallback? onLogout;
  final String selectedLanguage;
  final Function(String)? onLanguageChanged;

  const HamburgerMenu({
    super.key,
    this.userName,
    this.onLogout,
    this.selectedLanguage = 'English',
    this.onLanguageChanged,
  });

  String getLabel(String id) {
    return AppLocale.translations[id]?[selectedLanguage] ?? id;
  }

  // --- NEW FUNCTION: Shows the Contact Dialog and sends message ---
  void _showContactDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isLoading = false; // Local flag scoped to the dialog.

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
                            // Constructing the message to include who sent it
                            final fullMessage =
                                "User: ${userName ?? 'Guest'}\n\nMessage:\n$message";

                            final response = await http.post(
                              Uri.parse('$baseUrl/api/telegram/send'),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "message": fullMessage,
                                // Backend uses default ID from .env if chatId is not passed
                              }),
                            );

                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close dialog

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- HEADER SECTION ---
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
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        "My AI Menu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedLanguage,
                        style: TextStyle(
                          color: Colors.blue.shade100,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),

          // --- OPTIONAL: LANGUAGE & CONTACT ---
          if (onLanguageChanged != null) ...[
            // 1. LANGUAGE
            ExpansionTile(
              leading: const Icon(Icons.language, color: Colors.black54),
              title: const Text("Language"),
              subtitle: Text(
                selectedLanguage,
                style: TextStyle(color: Colors.blue.shade700),
              ),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 20),
                  title: const Text("English"),
                  trailing: selectedLanguage == 'English'
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => onLanguageChanged!('English'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 20),
                  title: const Text("Hindi"),
                  trailing: selectedLanguage == 'Hindi'
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => onLanguageChanged!('Hindi'),
                ),
              ],
            ),

            const Divider(),

            // 2. CONTACT US (UPDATED)
            ListTile(
              leading: const Icon(
                Icons.contact_support_outlined,
                color: Colors.black54,
              ),
              title: Text(
                getLabel('contact_us'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // --- UPDATE: Call the dialog function here ---
              onTap: () {
                // Close the drawer first (optional, personal preference)
                Navigator.pop(context);
                // Show the dialog
                _showContactDialog(context);
              },
            ),
          ],

          // --- OPTIONAL: LOGOUT BUTTON ---
          if (onLogout != null) ...[
            if (onLanguageChanged != null) const Divider(),

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
