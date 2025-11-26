import 'package:flutter/material.dart';
import 'trial.dart';

class Interest extends StatefulWidget {
  // Added required fields to receive data from Registration
  final String userName;
  final String userEmail;

  const Interest({super.key, required this.userName, required this.userEmail});

  @override
  State<Interest> createState() => _InterestState();
}

class _InterestState extends State<Interest> {
  // Simple in-memory checklist that reflects UI state.
  Map<String, bool> interests = {
    'Crypto': false,
    'Business': false,
    'Entertainment': false,
    'World': false,
    'Stock-Market': false,
    'Politics': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Interests'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Your Interests',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose topics you want to follow',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: interests.keys.map((interest) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        interest,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: interests[interest],
                      onChanged: (bool? value) {
                        setState(() {
                          interests[interest] = value ?? false;
                        });
                      },
                      activeColor: Colors.blue.shade700,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // PASS DATA FORWARD TO TRIAL SCREEN
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Trial(
                        userName: widget.userName,
                        userEmail: widget.userEmail,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
