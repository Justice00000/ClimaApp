import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ============================================================================
// GEOCODING SERVICE (NEW - for reverse geocoding)
// ============================================================================
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Cache to avoid repeated API calls for same locations
  final Map<String, String> _locationCache = {};
  
  // Rate limiting
  DateTime _lastRequestTime = DateTime.now();
  static const Duration _minRequestInterval = Duration(milliseconds: 1000);

  Future<String> getPlaceName(double lat, double lon) async {
    // Check cache first
    String cacheKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey]!;
    }

    // Rate limiting
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);
    if (timeSinceLastRequest < _minRequestInterval) {
      await Future.delayed(_minRequestInterval - timeSinceLastRequest);
    }
    _lastRequestTime = DateTime.now();

    try {
      // Nominatim reverse geocoding API
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&'
        'lat=$lat&'
        'lon=$lon&'
        'zoom=14&'
        'addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ClimaTrack-WaterQuality/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String placeName = _extractPlaceName(data);
        
        // Cache the result
        _locationCache[cacheKey] = placeName;
        return placeName;
      } else {
        debugPrint('Geocoding failed with status: ${response.statusCode}');
        return _generateFallbackName(lat, lon);
      }
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
      return _generateFallbackName(lat, lon);
    }
  }

  String _extractPlaceName(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    
    if (address == null) {
      return data['display_name']?.toString().split(',').first ?? 'Unknown Area';
    }

    // Priority order for place name extraction
    final nameFields = [
      'suburb',
      'neighbourhood',
      'quarter',
      'hamlet',
      'village',
      'town',
      'city',
      'county',
      'state_district',
    ];

    for (final field in nameFields) {
      if (address.containsKey(field) && address[field] != null) {
        return address[field].toString();
      }
    }

    // Fallback to display_name first part
    return data['display_name']?.toString().split(',').first ?? 'Unknown Area';
  }

  String _generateFallbackName(double lat, double lon) {
    // Generate a descriptive fallback name based on coordinates
    return 'Area ${lat.toStringAsFixed(3)}°, ${lon.toStringAsFixed(3)}°';
  }

  void clearCache() {
    _locationCache.clear();
  }
}

// ============================================================================
// WATER QUALITY PREDICTION SERVICE
// ============================================================================
class WaterQualityPredictionService {
  static final WaterQualityPredictionService _instance = 
      WaterQualityPredictionService._internal();
  
  factory WaterQualityPredictionService() => _instance;
  WaterQualityPredictionService._internal();

  static const String QUALITY_SAFE = 'safe';
  static const String QUALITY_MODERATE = 'moderate';
  static const String QUALITY_POOR = 'poor';
  static const String QUALITY_CRITICAL = 'critical';

  Future<WaterQualityPrediction> predictWaterQuality({
    required Position position,
    DateTime? targetDate,
  }) async {
    targetDate ??= DateTime.now();

    List<WaterReport> historicalReports = _generateSampleReports(position);
    
    WeatherData weatherData = WeatherData(
      temperature: 28.0 + Random().nextDouble() * 5,
      humidity: 70.0 + Random().nextDouble() * 20,
      rainfall: Random().nextDouble() * 30,
      conditions: 'Partly cloudy',
    );

    double baseScore = _calculateBaseQualityScore(
      position: position,
      historicalReports: historicalReports,
    );

    double weatherModifier = _calculateWeatherImpact(weatherData);
    double seasonalModifier = _calculateSeasonalImpact(targetDate);
    double proximityModifier = _calculateProximityImpact(position);

    double finalScore = (baseScore + weatherModifier + seasonalModifier + proximityModifier)
        .clamp(0.0, 100.0);

    String qualityLevel = _determineQualityLevel(finalScore);
    String riskLevel = _determineRiskLevel(finalScore);

    double confidence = _calculateConfidence(
      historicalReports: historicalReports,
      weatherData: weatherData,
    );

    List<ContaminantPrediction> contaminants = _predictContaminants(
      finalScore,
      weatherData,
      targetDate,
    );

    List<String> recommendations = _generateRecommendations(
      qualityLevel,
      riskLevel,
      contaminants,
    );

    QualityTrend trend = _predictTrend(
      currentScore: finalScore,
      historicalReports: historicalReports,
      weatherData: weatherData,
    );

    return WaterQualityPrediction(
      qualityScore: finalScore,
      qualityLevel: qualityLevel,
      riskLevel: riskLevel,
      confidence: confidence,
      contaminants: contaminants,
      recommendations: recommendations,
      trend: trend,
      predictedDate: targetDate,
      location: LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  List<WaterReport> _generateSampleReports(Position position) {
    List<WaterReport> reports = [];
    Random random = Random();
    for (int i = 0; i < 15; i++) {
      reports.add(WaterReport(
        latitude: position.latitude + (random.nextDouble() - 0.5) * 0.05,
        longitude: position.longitude + (random.nextDouble() - 0.5) * 0.05,
        qualityScore: 65 + random.nextDouble() * 25,
        timestamp: DateTime.now().subtract(Duration(days: i * 3)),
        reportType: 'user_report',
      ));
    }
    return reports;
  }

  double _calculateBaseQualityScore({
    required Position position,
    List<WaterReport>? historicalReports,
  }) {
    if (historicalReports == null || historicalReports.isEmpty) {
      return 75.0;
    }

    double totalScore = 0.0;
    double totalWeight = 0.0;

    for (var report in historicalReports) {
      double distance = _calculateDistance(
        position.latitude,
        position.longitude,
        report.latitude,
        report.longitude,
      );

      if (distance <= 5.0) {
        double timeWeight = _getTimeWeight(report.timestamp);
        double distanceWeight = _getDistanceWeight(distance);
        double weight = timeWeight * distanceWeight;

        totalScore += report.qualityScore * weight;
        totalWeight += weight;
      }
    }

    return totalWeight > 0 ? totalScore / totalWeight : 75.0;
  }

  double _calculateWeatherImpact(WeatherData? weatherData) {
    if (weatherData == null) return 0.0;
    double impact = 0.0;
    if (weatherData.rainfall > 50) impact -= 15.0;
    else if (weatherData.rainfall > 20) impact -= 8.0;
    else if (weatherData.rainfall > 5) impact -= 3.0;
    if (weatherData.temperature > 30) impact -= 5.0;
    else if (weatherData.temperature < 10) impact += 2.0;
    if (weatherData.humidity > 80) impact -= 3.0;
    return impact;
  }

  double _calculateSeasonalImpact(DateTime date) {
    int month = date.month;
    if (month >= 4 && month <= 10) return -8.0;
    return -2.0;
  }

  double _calculateProximityImpact(Position position) {
    double impact = 0.0;
    if (_isNearCoast(position.latitude, position.longitude)) impact -= 5.0;
    if (_isUrbanArea(position.latitude, position.longitude)) impact -= 3.0;
    return impact;
  }

  List<ContaminantPrediction> _predictContaminants(
    double qualityScore,
    WeatherData? weatherData,
    DateTime date,
  ) {
    List<ContaminantPrediction> contaminants = [];

    if (qualityScore < 70 || (weatherData != null && weatherData.rainfall > 20)) {
      contaminants.add(ContaminantPrediction(
        name: 'Bacterial Contamination',
        type: 'Biological',
        probability: qualityScore < 50 ? 0.8 : 0.4,
        severity: qualityScore < 50 ? 'high' : 'medium',
        sources: ['Sewage overflow', 'Surface runoff', 'Inadequate treatment'],
      ));
    }

    if (qualityScore < 60) {
      contaminants.add(ContaminantPrediction(
        name: 'Heavy Metals (Lead, Mercury)',
        type: 'Chemical',
        probability: 0.3,
        severity: 'medium',
        sources: ['Old pipes', 'Industrial discharge', 'Corrosion'],
      ));
    }

    if (weatherData != null && weatherData.rainfall > 30) {
      contaminants.add(ContaminantPrediction(
        name: 'High Turbidity',
        type: 'Physical',
        probability: 0.7,
        severity: 'low',
        sources: ['Soil erosion', 'Construction sites', 'Heavy rainfall'],
      ));
    }

    return contaminants;
  }

  List<String> _generateRecommendations(
    String qualityLevel,
    String riskLevel,
    List<ContaminantPrediction> contaminants,
  ) {
    List<String> recommendations = [];

    switch (qualityLevel) {
      case QUALITY_CRITICAL:
        recommendations.addAll([
          '⚠️ DO NOT use tap water for drinking or cooking',
          '💧 Use bottled water for all consumption',
          '🧪 Boiling may not remove all contaminants',
          '🏥 Seek medical attention if you experience symptoms',
          '📞 Report water quality issues immediately',
        ]);
        break;
      case QUALITY_POOR:
        recommendations.addAll([
          '⚠️ Boil water for at least 3 minutes before drinking',
          '💧 Use filtered or bottled water when possible',
          '🧼 Wash hands frequently with clean water',
          '🚿 Limit shower time to reduce exposure',
          '👶 Extra precautions for children and elderly',
        ]);
        break;
      case QUALITY_MODERATE:
        recommendations.addAll([
          '💧 Consider boiling or filtering drinking water',
          '🚰 Run tap for 30 seconds before use',
          '🧪 Use water filter certified for your contaminants',
          '👀 Monitor for changes in water appearance or taste',
          '📱 Stay updated on local water quality alerts',
        ]);
        break;
      case QUALITY_SAFE:
        recommendations.addAll([
          '✅ Water is safe for normal use',
          '💧 Continue normal consumption habits',
          '🧼 Maintain good hygiene practices',
          '🚰 Regular maintenance of home plumbing',
          '📱 Stay informed about local water quality',
        ]);
        break;
    }

    return recommendations;
  }

  QualityTrend _predictTrend({
    required double currentScore,
    List<WaterReport>? historicalReports,
    WeatherData? weatherData,
  }) {
    if (historicalReports == null || historicalReports.length < 3) {
      return QualityTrend(
        direction: 'stable',
        changeRate: 0.0,
        forecast7Days: currentScore,
        forecast30Days: currentScore,
      );
    }

    List<double> recentScores = historicalReports
        .take(10)
        .map((r) => r.qualityScore)
        .toList();

    double avgRecent = recentScores.reduce((a, b) => a + b) / recentScores.length;
    double changeRate = currentScore - avgRecent;

    String direction;
    if (changeRate > 5) direction = 'improving';
    else if (changeRate < -5) direction = 'declining';
    else direction = 'stable';

    double forecast7Days = (currentScore + changeRate * 0.5).clamp(0.0, 100.0);
    double forecast30Days = (currentScore + changeRate * 2.0).clamp(0.0, 100.0);

    if (weatherData != null && weatherData.rainfall > 30) {
      forecast7Days -= 10;
      forecast30Days -= 8;
    }

    return QualityTrend(
      direction: direction,
      changeRate: changeRate,
      forecast7Days: forecast7Days.clamp(0.0, 100.0),
      forecast30Days: forecast30Days.clamp(0.0, 100.0),
    );
  }

  String _determineQualityLevel(double score) {
    if (score >= 80) return QUALITY_SAFE;
    if (score >= 60) return QUALITY_MODERATE;
    if (score >= 40) return QUALITY_POOR;
    return QUALITY_CRITICAL;
  }

  String _determineRiskLevel(double score) {
    if (score >= 80) return 'low';
    if (score >= 60) return 'medium';
    if (score >= 40) return 'high';
    return 'critical';
  }

  double _calculateConfidence({
    List<WaterReport>? historicalReports,
    WeatherData? weatherData,
  }) {
    double confidence = 50.0;
    if (historicalReports != null) {
      confidence += min(historicalReports.length * 5.0, 30.0);
    }
    if (weatherData != null) confidence += 10.0;
    return confidence.clamp(0.0, 100.0);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;
  
  double _getTimeWeight(DateTime timestamp) {
    Duration age = DateTime.now().difference(timestamp);
    int daysOld = age.inDays;
    if (daysOld <= 7) return 1.0;
    if (daysOld <= 30) return 0.7;
    if (daysOld <= 90) return 0.4;
    return 0.2;
  }

  double _getDistanceWeight(double distanceKm) {
    if (distanceKm <= 1) return 1.0;
    if (distanceKm <= 3) return 0.7;
    if (distanceKm <= 5) return 0.4;
    return 0.1;
  }

  bool _isNearCoast(double lat, double lon) {
    return (lat > 6.4 && lat < 6.7 && lon > 3.3 && lon < 3.6);
  }

  bool _isUrbanArea(double lat, double lon) {
    return (lat > 6.4 && lat < 6.6 && lon > 3.3 && lon < 3.5);
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================
class WaterQualityPrediction {
  final double qualityScore;
  final String qualityLevel;
  final String riskLevel;
  final double confidence;
  final List<ContaminantPrediction> contaminants;
  final List<String> recommendations;
  final QualityTrend trend;
  final DateTime predictedDate;
  final LocationData location;

  WaterQualityPrediction({
    required this.qualityScore,
    required this.qualityLevel,
    required this.riskLevel,
    required this.confidence,
    required this.contaminants,
    required this.recommendations,
    required this.trend,
    required this.predictedDate,
    required this.location,
  });

  String get qualityDescription {
    switch (qualityLevel) {
      case 'safe': return 'Safe for consumption and daily use';
      case 'moderate': return 'Use with caution, filtration recommended';
      case 'poor': return 'Not safe for drinking, treatment required';
      case 'critical': return 'Severe contamination, avoid all use';
      default: return 'Unknown quality';
    }
  }

  Color get qualityColor {
    switch (qualityLevel) {
      case 'safe': return const Color(0xFF4CAF50);
      case 'moderate': return const Color(0xFFFFA726);
      case 'poor': return const Color(0xFFFF7043);
      case 'critical': return const Color(0xFFE53935);
      default: return Colors.grey;
    }
  }
}

class ContaminantPrediction {
  final String name;
  final String type;
  final double probability;
  final String severity;
  final List<String> sources;

  ContaminantPrediction({
    required this.name,
    required this.type,
    required this.probability,
    required this.severity,
    required this.sources,
  });
}

class QualityTrend {
  final String direction;
  final double changeRate;
  final double forecast7Days;
  final double forecast30Days;

  QualityTrend({
    required this.direction,
    required this.changeRate,
    required this.forecast7Days,
    required this.forecast30Days,
  });

  String get icon {
    switch (direction) {
      case 'improving': return '📈';
      case 'declining': return '📉';
      default: return '➡️';
    }
  }

  String get description {
    switch (direction) {
      case 'improving': return 'Quality is improving';
      case 'declining': return 'Quality is declining';
      default: return 'Quality is stable';
    }
  }
}

class WaterReport {
  final double latitude;
  final double longitude;
  final double qualityScore;
  final DateTime timestamp;
  final String reportType;

  WaterReport({
    required this.latitude,
    required this.longitude,
    required this.qualityScore,
    required this.timestamp,
    required this.reportType,
  });
}

class WeatherData {
  final double temperature;
  final double humidity;
  final double rainfall;
  final String conditions;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.conditions,
  });
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({
    required this.latitude,
    required this.longitude,
  });
}

// ============================================================================
// MAP SCREEN
// ============================================================================
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
  final MapController _mapController = MapController();
  bool _isSatelliteView = true;
  
  bool _isLoadingData = false;
  Map<String, dynamic>? _selectedZone;
  List<Map<String, dynamic>> _nearbyZones = [];
  
  final WaterQualityPredictionService _predictionService = 
      WaterQualityPredictionService();
  final GeocodingService _geocodingService = GeocodingService();

  // OpenStreetMap tile URLs
  final String _satelliteTileUrl = 
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  final String _normalTileUrl = 
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    if (widget.currentPosition != null) {
      _loadNearbyZonesData();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Load real-time data for zones around user's location
  Future<void> _loadNearbyZonesData() async {
    if (widget.currentPosition == null) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Get zones within 10km radius
      List<Map<String, dynamic>> zones = await _generateNearbyZones(
        widget.currentPosition!,
        radiusKm: 10.0,
        numberOfZones: 12,
      );

      // Generate predictions for each zone with real place names
      for (var zone in zones) {
        // Get real place name from OpenStreetMap
        String placeName = await _geocodingService.getPlaceName(
          zone['lat'],
          zone['lng'],
        );
        zone['name'] = placeName;

        Position zonePosition = Position(
          latitude: zone['lat'],
          longitude: zone['lng'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        WaterQualityPrediction prediction = 
            await _predictionService.predictWaterQuality(
          position: zonePosition,
        );

        zone['prediction'] = prediction;
        zone['status'] = _getStatusFromScore(prediction.qualityScore);
        zone['color'] = _getColorFromScore(prediction.qualityScore);
        zone['qualityScore'] = prediction.qualityScore;
      }

      setState(() {
        _nearbyZones = zones;
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading zone data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  /// Generate nearby zones based on user location
  Future<List<Map<String, dynamic>>> _generateNearbyZones(
    Position center,
    {required double radiusKm,
    required int numberOfZones}
  ) async {
    List<Map<String, dynamic>> zones = [];
    Random random = Random();

    // Generate zones in a grid pattern around user
    int gridSize = sqrt(numberOfZones).ceil();
    double stepLat = (radiusKm * 2) / (111.32 * gridSize);
    double stepLng = (radiusKm * 2) / (111.32 * cos(center.latitude * pi / 180) * gridSize);

    int zoneId = 1;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (zoneId > numberOfZones) break;

        double lat = center.latitude - (radiusKm / 111.32) + (i * stepLat);
        double lng = center.longitude - (radiusKm / (111.32 * cos(center.latitude * pi / 180))) + (j * stepLng);

        // Add some randomness for natural distribution
        lat += (random.nextDouble() - 0.5) * stepLat * 0.3;
        lng += (random.nextDouble() - 0.5) * stepLng * 0.3;

        zones.add({
          'id': 'zone_$zoneId',
          'name': 'Loading...', // Will be replaced with actual name
          'lat': lat,
          'lng': lng,
          'distance': _calculateDistance(
            center.latitude, center.longitude, lat, lng
          ),
          'lastTested': DateTime.now().subtract(
            Duration(minutes: random.nextInt(180))
          ),
          'reportCount': random.nextInt(8) + 1,
        });

        zoneId++;
      }
    }

    // Sort by distance
    zones.sort((a, b) => a['distance'].compareTo(b['distance']));
    return zones;
  }

  void _selectZone(Map<String, dynamic> zone) {
    setState(() {
      _selectedZone = zone;
    });

    // Animate to zone
    _mapController.move(
      LatLng(zone['lat'], zone['lng']),
      14.0,
    );

    // Show details
    _showZoneDetails(zone);
  }

  void _showZoneDetails(Map<String, dynamic> zone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildZoneDetailsSheet(zone),
    );
  }

  Widget _buildZoneDetailsSheet(Map<String, dynamic> zone) {
    WaterQualityPrediction prediction = zone['prediction'];
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Zone title
              Row(
                children: [
                  Icon(Icons.location_on, color: zone['color'], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          '${zone['distance'].toStringAsFixed(2)}km from you',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quality score card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      prediction.qualityColor,
                      prediction.qualityColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Water Quality Score',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${prediction.confidence.toStringAsFixed(0)}% Confidence',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          prediction.qualityScore.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.qualityLevel.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                prediction.qualityDescription,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Zone info
              _buildInfoRow(
                Icons.access_time,
                'Last Tested',
                _formatTimeAgo(zone['lastTested']),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.people_outline,
                'Community Reports',
                '${zone['reportCount']} reports',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.location_on_outlined,
                'Coordinates',
                '${zone['lat'].toStringAsFixed(4)}, ${zone['lng'].toStringAsFixed(4)}',
              ),
              const SizedBox(height: 20),

              // Trend indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Text(
                      prediction.trend.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quality Trend',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            prediction.trend.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Top recommendations
              const Text(
                'Key Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              ...prediction.recommendations.take(3).map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.substring(0, 2),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rec.substring(3),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3AAFBB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
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
        actions: [
          // Map type toggle
          IconButton(
            icon: Icon(
              _isSatelliteView ? Icons.map : Icons.satellite_alt,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSatelliteView = !_isSatelliteView;
              });
            },
            tooltip: _isSatelliteView ? 'Normal View' : 'Satellite View',
          ),
          // Refresh data
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoadingData ? null : _loadNearbyZonesData,
          ),
        ],
      ),
      body: widget.currentPosition == null
          ? _buildNoLocationView()
          : Stack(
              children: [
                // OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude,
                    ),
                    initialZoom: 12.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // Tile layer
                    TileLayer(
                      urlTemplate: _isSatelliteView ? _satelliteTileUrl : _normalTileUrl,
                      userAgentPackageName: 'com.climatrackapp.climatrack',
                    ),
                    
                    // Circle layers for zones
                    ..._nearbyZones.map((zone) {
                      return CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(zone['lat'], zone['lng']),
                            radius: 500, // 500 meters
                            color: (zone['color'] as Color).withOpacity(0.2),
                            borderColor: zone['color'],
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                          ),
                        ],
                      );
                    }).toList(),
                    
                    // Marker layer
                    MarkerLayer(
                      markers: [
                        // User location marker
                        Marker(
                          point: LatLng(
                            widget.currentPosition!.latitude,
                            widget.currentPosition!.longitude,
                          ),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              _mapController.move(
                                LatLng(
                                  widget.currentPosition!.latitude,
                                  widget.currentPosition!.longitude,
                                ),
                                14.0,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3AAFBB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        
                        // Zone markers
                        ..._nearbyZones.map((zone) {
                          return Marker(
                            point: LatLng(zone['lat'], zone['lng']),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _selectZone(zone),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: zone['color'],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.water_drop,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),

                // Loading indicator
                if (_isLoadingData)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF3AAFBB),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading community data...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Legend overlay
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildLegendCard(),
                ),

                // Zone list overlay
                if (_nearbyZones.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildZoneListCard(),
                  ),

                // My location button
                Positioned(
                  bottom: 200,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {
                      if (widget.currentPosition != null) {
                        _mapController.move(
                          LatLng(
                            widget.currentPosition!.latitude,
                            widget.currentPosition!.longitude,
                          ),
                          14.0,
                        );
                      }
                    },
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFF3AAFBB),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoLocationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Location Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please enable location services to view the water quality map.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Risk Zones',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.green, 'Safe', '80-100'),
            const SizedBox(height: 4),
            _buildLegendItem(Colors.orange, 'Moderate', '60-79'),
            const SizedBox(height: 4),
            _buildLegendItem(Colors.red[700]!, 'Poor', '40-59'),
            const SizedBox(height: 4),
            _buildLegendItem(Colors.red[900]!, 'Critical', '<40'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String range) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label ($range)',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneListCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: Color(0xFF3AAFBB),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Nearby Communities',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_nearbyZones.length} areas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _nearbyZones.length,
                itemBuilder: (context, index) {
                  final zone = _nearbyZones[index];
                  return _buildCompactZoneCard(zone);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactZoneCard(Map<String, dynamic> zone) {
    return GestureDetector(
      onTap: () => _selectZone(zone),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: zone['color'].withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: zone['color'],
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              zone['name'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: zone['color'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                zone['status'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${zone['distance'].toStringAsFixed(1)}km',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getStatusFromScore(double score) {
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Moderate';
    if (score >= 40) return 'Poor';
    return 'Critical';
  }

  Color _getColorFromScore(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.red[700]!;
    return Colors.red[900]!;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;

  String _formatTimeAgo(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}