import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ApiService {
  // Change this to your actual backend URL
  static const String baseUrl = 'http://localhost:8000';
  
  static String? _accessToken;
  
  // Helper method to get headers
  static Map<String, String> _getHeaders({bool includeAuth = false}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Register new user
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    Position? location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'phone': phone,
          'location': location != null
              ? {
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                }
              : null,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get current user info
  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get user info',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // RISK PREDICTION
  // ============================================================================

  /// Generate risk prediction
  static Future<Map<String, dynamic>> generateRiskPrediction({
    required Position position,
    double? ndwi,
    double? awei,
    double? rainfall,
    double? temperature,
    double? humidity,
    double? floodRisk,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/predictions/generate'),
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({
          'location': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
          },
          'ndwi': ndwi,
          'awei': awei,
          'rainfall': rainfall,
          'temperature': temperature,
          'humidity': humidity,
          'flood_risk': floodRisk,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to generate prediction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get prediction by location
  static Future<Map<String, dynamic>> getPredictionByLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/predictions/location?latitude=$latitude&longitude=$longitude'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get prediction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get nearby predictions
  static Future<Map<String, dynamic>> getNearbyPredictions({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/predictions/nearby?latitude=$latitude&longitude=$longitude&radius=$radius'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get nearby predictions',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // ZONES
  // ============================================================================

  /// Get all zones
  static Future<Map<String, dynamic>> getAllZones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/zones/all'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get zones',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get zone details
  static Future<Map<String, dynamic>> getZoneDetails(String zoneId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/zones/$zoneId'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get zone details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // COMMUNITY REPORTS
  // ============================================================================

  /// Submit community report
  static Future<Map<String, dynamic>> submitReport({
    required String reportType,
    required Position location,
    required String description,
    int? severity,
    List<String>? images,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reports/submit'),
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({
          'report_type': reportType,
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
          },
          'description': description,
          'severity': severity,
          'images': images,
        }),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to submit report',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get recent reports
  static Future<Map<String, dynamic>> getRecentReports({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/recent?limit=$limit'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get reports',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // HEALTH LOGGING
  // ============================================================================

  /// Log health symptom
  static Future<Map<String, dynamic>> logHealthSymptom({
    required String symptomType,
    required int severity,
    required DateTime onsetDate,
    required Position location,
    int affectedCount = 1,
    String? additionalInfo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/health/log-symptom'),
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({
          'symptom_type': symptomType,
          'severity': severity,
          'onset_date': onsetDate.toIso8601String(),
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
          },
          'affected_count': affectedCount,
          'additional_info': additionalInfo,
        }),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to log symptom',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get user's health logs
  static Future<Map<String, dynamic>> getMyHealthLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health/my-logs'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get health logs',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // ALERTS
  // ============================================================================

  /// Get active alerts
  static Future<Map<String, dynamic>> getActiveAlerts({
    double? latitude,
    double? longitude,
  }) async {
    try {
      String url = '$baseUrl/api/alerts/active';
      if (latitude != null && longitude != null) {
        url += '?latitude=$latitude&longitude=$longitude';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get alerts',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Get dashboard analytics
  static Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/dashboard'),
        headers: _getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get analytics',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // HEALTH CHECK
  // ============================================================================

  /// Check API health
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'API unhealthy',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot connect to API: $e',
      };
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert issue type to backend report type
  static String convertIssueTypeToReportType(String issueType) {
    switch (issueType) {
      case 'Contaminated Water':
      case 'Bad Odor':
      case 'Discoloration':
      case 'Poor Taste':
        return 'water_quality';
      case 'No Water Supply':
      case 'Leaking Pipes':
        return 'infrastructure';
      default:
        return 'water_quality';
    }
  }

  /// Clear stored token (logout)
  static void clearToken() {
    _accessToken = null;
  }

  /// Check if user is authenticated
  static bool isAuthenticated() {
    return _accessToken != null;
  }
}