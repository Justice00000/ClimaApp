import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class HealthScreen extends StatefulWidget {
  final String? userName;
  final String email;
  final Position? currentPosition;

  const HealthScreen({
    Key? key,
    this.userName,
    required this.email,
    this.currentPosition,
  }) : super(key: key);

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final List<Map<String, dynamic>> _symptoms = [
    {'emoji': '🥵', 'label': 'Fever'},
    {'emoji': '🤢', 'label': 'Nausea'},
    {'emoji': '🤕', 'label': 'Headache'},
    {'emoji': '💩', 'label': 'Diarrhea'},
    {'emoji': '🤮', 'label': 'Vomiting'},
    {'emoji': '🤒', 'label': 'Stomach Pain'},
  ];

  String? _selectedSymptom;

  final List<Map<String, String>> _healthLogs = [
    {'date': 'January 15, 2025', 'status': '🤒 Fever, 🤕 Headache'},
    {'date': 'January 14, 2025', 'status': 'Feeling healthy'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section (brown background)
            Container(
              height: 60,
              color: const Color(0xFFD19A6C),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.monitor_heart, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Health Log",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // How are you feeling section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How are you feeling today?",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Symptoms Grid
                  GridView.builder(
                    itemCount: _symptoms.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 4.5,
                    ),
                    itemBuilder: (context, index) {
                      final symptom = _symptoms[index];
                      final isSelected =
                          _selectedSymptom == symptom['label'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSymptom = symptom['label'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF8FD6D8)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                symptom['emoji'],
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                symptom['label'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Log Symptoms Button
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8FD6D8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text(
                        "Log Symptoms",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (_selectedSymptom == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Select a symptom first"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _healthLogs.insert(0, {
                            'date': 'Today',
                            'status': _selectedSymptom!,
                          });
                          _selectedSymptom = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Health Trend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text(
                "Your Health Trend",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFF2FAF9),
                      child: Icon(Icons.star, color: Color(0xFF3AAFBB)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Feeling Great!",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "No symptoms logged in the past 7 days",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Recent Entries
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text(
                "Recent Entries",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            const SizedBox(height: 8),

            ListView.builder(
              itemCount: _healthLogs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final log = _healthLogs[index];
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          log['status']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Text(
                        log['date']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // Note
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF3AAFBB), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "If symptoms persist for more than 2 days, please visit a healthcare provider.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}