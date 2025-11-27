import 'package:flutter/material.dart';
import 'package:pina/screens/landing.dart';

class MainMenuScreen extends StatelessWidget {
  final Map<String, List<String>> menu = {
    "Text": [
      "Text to Text",
      "Text to Image",
      "Text to Audio",
      "Text to Video",
      "Text to Multiple",
    ],
    "Image": [
      "Image to Text",
      "Image to Image",
      "Image to Audio",
      "Image to Video",
      "Image to Multiple",
    ],
    "Audio": [
      "Audio to Text",
      "Audio to Image",
      "Audio to Audio",
      "Audio to Video",
      "Audio to Multiple",
    ],
    "Video": [
      "Video to Text",
      "Video to Image",
      "Video to Audio",
      "Video to Video",
      "Video to Multiple",
    ],
    "Multiple": [
      "Multiple to Text",
      "Multiple to Image",
      "Multiple to Audio",
      "Multiple to Video",
      "Multiple to Multiple",
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Main Menu"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: menu.entries.map((entry) {
          return ExpansionTile(
            title: Text(entry.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            children: entry.value.map((sub) {
              return ListTile(
                title: Text(sub),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LandingScreen(title: sub),
                    ),
                  );
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
