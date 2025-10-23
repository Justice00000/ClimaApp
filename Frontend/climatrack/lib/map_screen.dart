import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  final String? userName;
  final String email;
  final Position? currentPosition;

  const MapScreen({
    Key? key,
    this.userName,
    required this.email,
    this.currentPosition,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String selectedZone = 'Ikeja North';
  String selectedStatus = 'Safe';
  Color selectedColor = Colors.green;

  final List<Map<String, dynamic>> _zones = [
    {
      'name': 'Ikeja North',
      'lat': 6.6149,
      'lng': 3.3406,
      'status': 'Safe',
      'color': 'green'
    },
    {
      'name': 'Oshodi',
      'lat': 6.5586,
      'lng': 3.3469,
      'status': 'Safe',
      'color': 'green'
    },
    {
      'name': 'Victoria Island',
      'lat': 6.4281,
      'lng': 3.4219,
      'status': 'Moderate',
      'color': 'orange'
    },
    {
      'name': 'Surulere',
      'lat': 6.4969,
      'lng': 3.3614,
      'status': 'High Risk',
      'color': 'red'
    },
  ];

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _selectZone(Map<String, dynamic> zone) {
    setState(() {
      selectedZone = zone['name'];
      selectedStatus = zone['status'];
      selectedColor = _getColorFromString(zone['color']);
    });
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final color = _getColorFromString(zone['color']);
    return GestureDetector(
      onTap: () => _selectZone(zone),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedZone == zone['name']
                ? const Color(0xFF3AAFBB)
                : Colors.grey.shade300,
            width: selectedZone == zone['name'] ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    zone['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    zone['status'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${zone['lat'].toStringAsFixed(4)}, ${zone['lng'].toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last tested: 2 hours ago • 3 community reports',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF3AAFBB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Water Quality Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map placeholder with note
            Container(
              height: 250,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 70,
                    color: const Color(0xFF3AAFBB).withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kIsWeb ? 'Interactive Map' : 'Map View',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      kIsWeb
                          ? 'Interactive map coming soon'
                          : 'View zone details below',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  if (widget.currentPosition != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F4F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.my_location,
                            size: 16,
                            color: Color(0xFF3AAFBB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.currentPosition!.latitude.toStringAsFixed(4)}, ${widget.currentPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3AAFBB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Zone cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Quality Zones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a zone to view details',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._zones.map((zone) => _buildZoneCard(zone)).toList(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Selected zone details
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3AAFBB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF3AAFBB),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected: $selectedZone',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Last tested:',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('2 hours ago',
                          style: TextStyle(
                              color: Color(0xFF2C3E50),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Reports:',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('3 community reports',
                          style: TextStyle(
                              color: Color(0xFF2C3E50),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legend
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Risk Zones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildLegendItem(
                    color: Colors.green,
                    label: 'Safe',
                    description: 'Water quality excellent, safe to use',
                  ),
                  const SizedBox(height: 10),
                  _buildLegendItem(
                    color: Colors.orange,
                    label: 'Moderate',
                    description: 'Some issues detected, boil before use',
                  ),
                  const SizedBox(height: 10),
                  _buildLegendItem(
                    color: Colors.red,
                    label: 'High Risk',
                    description: 'Contamination found, avoid use',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}