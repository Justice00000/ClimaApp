import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

import 'map_screen.dart';
import 'report_screen.dart';
import 'health_screen.dart';
import 'learn_screen.dart';

void main() {
  runApp(const ClimaTrackApp());
}

class ClimaTrackApp extends StatelessWidget {
  const ClimaTrackApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClimaTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3AAFBB),
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

// PREDICTION SERVICE
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
    if (changeRate > 5) {
      direction = 'improving';
    } else if (changeRate < -5) {
      direction = 'declining';
    } else {
      direction = 'stable';
    }

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

// LOCATION SERVICE
class LocationService {
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  static Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return place.locality ?? place.subAdministrativeArea ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Unknown';
    }
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================
class HomeScreen extends StatefulWidget {
  final String email;
  final String? userName;

  const HomeScreen({
    Key? key,
    required this.email,
    this.userName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Position? _currentPosition;
  String _currentAddress = 'Loading...';
  bool _isLoadingLocation = true;
  WaterQualityPrediction? _prediction;
  final WaterQualityPredictionService _predictionService = WaterQualityPredictionService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool hasPermission = await LocationService.requestLocationPermission();

    if (!hasPermission) {
      setState(() {
        _currentAddress = 'Location access denied';
        _isLoadingLocation = false;
      });
      _showLocationPermissionDialog();
      return;
    }

    Position? position = await LocationService.getCurrentLocation();

    if (position != null) {
      String address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      WaterQualityPrediction prediction = await _predictionService.predictWaterQuality(
        position: position,
      );

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
        _prediction = prediction;
        _isLoadingLocation = false;
      });
    } else {
      setState(() {
        _currentAddress = 'Unable to get location';
        _isLoadingLocation = false;
      });
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'ClimaTrack needs access to your location to provide accurate water quality information for your area. Please enable location services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    await _initializeLocation();
  }

  void _showPredictionDetails() {
    if (_prediction == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PredictionDetailScreen(prediction: _prediction!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _buildDashboard(),
      MapScreen(
        userName: widget.userName,
        email: widget.email,
        currentPosition: _currentPosition,
      ),
      ReportScreen(
        userName: widget.userName,
        email: widget.email,
        currentPosition: _currentPosition,
      ),
      HealthScreen(
        userName: widget.userName,
        email: widget.email,
        currentPosition: _currentPosition,
      ),
      LearnScreen(
        userName: widget.userName ?? '',
        email: widget.email,
      )
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF3AAFBB),
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Report'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'Health'),
            BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: 'Learn'),
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    String qualityStatus = _prediction?.qualityLevel.toUpperCase() ?? 'SAFE';
    Color statusColor = _prediction?.qualityColor ?? Colors.green;
    String statusMessage = _prediction?.qualityDescription ?? 
        'Water quality is good. Safe to use with normal precautions.';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF3AAFBB),
          elevation: 0,
          pinned: false,
          expandedHeight: 300,
          leading: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(Icons.water_drop, color: Colors.white),
          ),
          title: const Text(
            'ClimaTrack',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      email: widget.email,
                      userName: widget.userName,
                    ),
                  ),
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hello, ${widget.userName ?? "Test Account"}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('👋', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Your Current Location',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const Spacer(),
                            if (_isLoadingLocation)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                ),
                              )
                            else
                              IconButton(
                                icon: Icon(Icons.refresh, size: 18, color: Colors.grey[600]),
                                onPressed: _refreshLocation,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentAddress,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentPosition != null
                              ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                              : 'Location unavailable',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              qualityStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_prediction != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showPredictionDetails,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _prediction!.qualityColor,
                            _prediction!.qualityColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _prediction!.qualityColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'AI Water Quality Score',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_prediction!.confidence.toStringAsFixed(0)}% Confidence',
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
                                _prediction!.qualityScore.toStringAsFixed(1),
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
                                      _prediction!.qualityLevel.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _prediction!.qualityDescription,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap for detailed analysis',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Water Risk Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusColor == Colors.green 
                              ? Icons.check_circle_outline 
                              : Icons.warning_amber_outlined,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Neighborhood',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusMessage,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_prediction != null && _prediction!.trend.direction != 'stable') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _prediction!.trend.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trend Alert',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _prediction!.trend.description,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.analytics_outlined,
                        title: 'View Analysis',
                        subtitle: 'Detailed predictions',
                        color: const Color(0xFFE1BEE7),
                        onTap: _showPredictionDetails,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.report_outlined,
                        title: 'Report Issue',
                        subtitle: 'Help your community',
                        color: const Color(0xFFB3E5FC),
                        onTap: () {
                          setState(() {
                            _currentIndex = 2;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.medical_services_outlined,
                        title: 'Log Symptoms',
                        subtitle: 'Track your health',
                        color: const Color(0xFFFFCCBC),
                        onTap: () {
                          setState(() {
                            _currentIndex = 3;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.school_outlined,
                        title: 'Learn More',
                        subtitle: 'Water safety tips',
                        color: const Color(0xFFC5E1A5),
                        onTap: () {
                          setState(() {
                            _currentIndex = 4;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAlertItem(
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.orange,
                  title: 'Water Supply Update',
                  subtitle: 'Temporary disruption in nearby area - 2 hours ago',
                ),
                const SizedBox(height: 12),
                _buildAlertItem(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green,
                  title: 'Quality Test Passed',
                  subtitle: 'Your area water tested safe - 1 day ago',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2C3E50), size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREDICTION DETAIL SCREEN
// ============================================================================
class PredictionDetailScreen extends StatelessWidget {
  final WaterQualityPrediction prediction;

  const PredictionDetailScreen({
    Key? key,
    required this.prediction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF3AAFBB),
        elevation: 0,
        title: const Text(
          'Water Quality Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQualityScoreCard(),
            _buildTrendCard(),
            if (prediction.contaminants.isNotEmpty) _buildContaminantsCard(),
            _buildRecommendationsCard(),
            _buildForecastCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityScoreCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
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
        boxShadow: [
          BoxShadow(
            color: prediction.qualityColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quality Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${prediction.confidence.toStringAsFixed(0)}% Confidence',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            prediction.qualityScore.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prediction.qualityLevel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            prediction.qualityDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: prediction.qualityScore / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    final trend = prediction.trend;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trend.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Quality Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            trend.description,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTrendItem('7-Day Forecast', trend.forecast7Days)),
              const SizedBox(width: 16),
              Expanded(child: _buildTrendItem('30-Day Forecast', trend.forecast30Days)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, double score) {
    Color color;
    if (score >= 80) color = Colors.green;
    else if (score >= 60) color = Colors.orange;
    else color = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContaminantsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: Color(0xFF3AAFBB), size: 24),
              SizedBox(width: 12),
              Text(
                'Potential Contaminants',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...prediction.contaminants.map((c) => _buildContaminantItem(c)),
        ],
      ),
    );
  }

  Widget _buildContaminantItem(ContaminantPrediction contaminant) {
    Color severityColor;
    switch (contaminant.severity) {
      case 'high': severityColor = Colors.red; break;
      case 'medium': severityColor = Colors.orange; break;
      default: severityColor = Colors.yellow[700]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contaminant.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(contaminant.probability * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${contaminant.type}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Possible sources:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          ...contaminant.sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '• $source',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF3AAFBB), size: 24),
              SizedBox(width: 12),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...prediction.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.substring(0, 2), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec.substring(3),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3AAFBB).withOpacity(0.1),
            const Color(0xFF3AAFBB).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3AAFBB).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF3AAFBB), size: 24),
              SizedBox(width: 12),
              Text(
                'About This Prediction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This AI-powered prediction analyzes historical water quality data, current weather conditions, seasonal patterns, and proximity to known risk factors in your area.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Location: ${prediction.location.latitude.toStringAsFixed(4)}, ${prediction.location.longitude.toStringAsFixed(4)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            'Generated: ${_formatDateTime(prediction.predictedDate)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================
class SettingsScreen extends StatelessWidget {
  final String email;
  final String? userName;

  const SettingsScreen({
    Key? key,
    required this.email,
    this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF3AAFBB),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: userName ?? email,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context,
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: email,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Privacy & Legal'),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy and terms',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context,
            icon: Icons.security_outlined,
            title: 'Data & Security',
            subtitle: 'Manage your data and privacy settings',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Preferences'),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage alert preferences',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context,
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            subtitle: 'Control location access',
            onTap: () {
              Geolocator.openLocationSettings();
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help with ClimaTrack',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: 'About ClimaTrack',
            subtitle: 'Version 1.0.0',
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                _showLogoutDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3AAFBB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF3AAFBB), size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF3AAFBB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('ClimaTrack'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'ClimaTrack is an AI-powered waterborne disease risk prediction platform developed to protect communities through early warning and proactive prevention.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 African Leadership University',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRIVACY POLICY SCREEN
// ============================================================================
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF3AAFBB),
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.info_outline,
              title: '1. Introduction',
              content: 
                'Welcome to ClimaTrack, a waterborne disease risk prediction platform developed by Chukwuonye Justice Izuchukwu at African Leadership University. This Privacy Policy explains how we collect, use, protect, and share your personal information.',
            ),
            _buildSection(
              icon: Icons.cloud_outlined,
              title: '2. Data Collection',
              content: 
                'We collect:\n\n'
                '• Account Information: Email and password for authentication\n'
                '• Location Data: Approximate location (rounded to 500m grid cells) - we do NOT collect precise GPS coordinates\n'
                '• Community Reports: Optional photos and descriptions of water quality issues\n'
                '• Technical Information: Device type and app version for optimization',
            ),
            _buildSection(
              icon: Icons.block,
              title: 'What We Do NOT Collect',
              content: 
                '• Precise GPS coordinates or real-time tracking\n'
                '• Contacts, messages, or other phone data\n'
                '• Browsing history outside ClimaTrack\n'
                '• Health records or medical information\n'
                '• Financial or payment data\n'
                '• Biometric data',
            ),
            _buildSection(
              icon: Icons.settings_outlined,
              title: '3. How We Use Your Data',
              content: 
                'Your data is used exclusively for:\n\n'
                '• Generating neighborhood-level disease risk predictions\n'
                '• Sending push notifications when risk levels are elevated\n'
                '• Improving ML model accuracy through anonymized analysis\n\n'
                'We will NEVER:\n'
                '• Sell or rent your data to third parties\n'
                '• Use your data for advertising\n'
                '• Share with government agencies without consent (except as legally required)',
            ),
            _buildSection(
              icon: Icons.security_outlined,
              title: '4. Data Security',
              content: 
                'We implement industry-standard security:\n\n'
                '• AES-256 encryption for stored data\n'
                '• TLS 1.3 encryption for data transmission\n'
                '• Multi-factor authentication\n'
                '• Regular security audits\n'
                '• Secure cloud hosting with automatic backups',
            ),
            _buildSection(
              icon: Icons.verified_user_outlined,
              title: '5. Your Rights (NDPA 2023)',
              content: 
                'Under Nigeria Data Protection Act 2023, you have the right to:\n\n'
                '• Access your personal data\n'
                '• Correct inaccurate data\n'
                '• Delete your account and data\n'
                '• Export your data (data portability)\n'
                '• Withdraw consent at any time\n'
                '• Object to specific data processing',
            ),
            _buildSection(
              icon: Icons.warning_amber_outlined,
              title: '6. Prediction Limitations',
              content: 
                'ClimaTrack provides risk predictions based on environmental data and ML models. Predictions are NOT:\n\n'
                '• Guarantees about disease occurrence\n'
                '• Substitutes for medical advice\n'
                '• Perfect - false positives and negatives occur\n\n'
                'Always maintain basic water safety practices regardless of displayed risk levels.',
            ),
            _buildSection(
              icon: Icons.share_outlined,
              title: '7. Data Sharing',
              content: 
                'We share anonymized aggregate data with:\n\n'
                '• Public health researchers (no personal identification)\n'
                '• Health authorities for outbreak monitoring (statistics only)\n'
                '• Academic institutions for validation studies\n\n'
                'We use service providers:\n'
                '• Render/Firebase for hosting and authentication\n'
                '• Firebase Cloud Messaging for push notifications',
            ),
            _buildSection(
              icon: Icons.child_care_outlined,
              title: '8. Children\'s Privacy',
              content: 
                'ClimaTrack is intended for users 13+. We do not knowingly collect data from children under 13. If you are under 18, we recommend obtaining parental consent.',
            ),
            _buildSection(
              icon: Icons.contact_mail_outlined,
              title: '9. Contact Us',
              content: 
                'For privacy questions or data requests:\n\n'
                'Email: j.chukwuony@alustudent.com\n\n',
            ),
            _buildSection(
              icon: Icons.gavel_outlined,
              title: '10. Governing Law',
              content: 
                'This agreement is governed by:\n\n'
                '• Nigeria Data Protection Act (NDPA) 2023\n'
                '• Nigerian Copyright Act\n'
                '• Nigerian Cybercrimes Act 2015',
            ),
            const SizedBox(height: 24),
            _buildFooter(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3AAFBB), Color(0xFF2C9AA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3AAFBB).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Privacy Policy & End-User License Agreement',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Effective Date: November 10, 2025',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We are committed to protecting your privacy and handling your data responsibly.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3AAFBB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF3AAFBB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF3AAFBB), size: 24),
              SizedBox(width: 12),
              Text(
                'Last Updated',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This Privacy Policy was last updated on November 21, 2025.\n\n'
            'We may update this policy to reflect changes in legal requirements or new features. You will be notified of material changes through in-app notifications or email.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            '© 2025 ClimaTrack. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOGIN SCREEN
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3AAFBB),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.water_drop_outlined,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'ClimaTrack',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 40),
                    _buildInputField(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      hintText: '••••••••',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signing in...'),
                                backgroundColor: Color(0xFF3AAFBB),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            Future.delayed(const Duration(seconds: 1), () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(
                                    email: _emailController.text,
                                  ),
                                ),
                              );
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3AAFBB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[700], fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              color: Color(0xFF3AAFBB),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildInfoBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2C3E50)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3AAFBB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Color(0xFF3AAFBB), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Join thousands of community members protecting their health with ClimaTrack.',
              style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SIGN UP SCREEN
// ============================================================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3AAFBB),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.water_drop_outlined,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'ClimaTrack',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 40),
                    _buildInputField(
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      controller: _nameController,
                      hintText: 'John Doe',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      hintText: '••••••••',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Creating account...'),
                                backgroundColor: Color(0xFF3AAFBB),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            Future.delayed(const Duration(seconds: 1), () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomeScreen(
                                    email: _emailController.text,
                                    userName: _nameController.text,
                                  ),
                                ),
                              );
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3AAFBB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.grey[700], fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: Color(0xFF3AAFBB),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildInfoBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2C3E50)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textCapitalization: label == 'Full Name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3AAFBB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Color(0xFF3AAFBB), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Join thousands of community members protecting their health with ClimaTrack.',
              style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}