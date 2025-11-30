import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Service for handling API communication with the fall detection server
class ApiService {
  static const String _csvHeader = '"Time (s)","Acceleration x (m/s^2)",'
      '"Acceleration y (m/s^2)","Acceleration z (m/s^2)",'
      '"Absolute acceleration (m/s^2)"\n';

  /// Checks if the server is running and reachable
  static Future<Map<String, dynamic>> checkServerHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.serverUrl}/health'),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Connection timeout - server not reachable');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Server is running',
          'service': data['service'] ?? 'Fall Detection Server',
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'message': 'Server responded with status ${response.statusCode}',
        };
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Health check error: $e');
      }
      return {
        'success': false,
        'message': 'Connection failed: ${e.toString()}',
      };
    }
  }

  /// Sends accelerometer data to the server for fall detection analysis
  static Future<http.Response> sendAccelerometerData(
      List<String> data) async {
    final csvData = _csvHeader + data.join('\n');

    if (AppConfig.debugMode) {
      print('📡 Sending data to: ${AppConfig.apiUrl}');
      print('📊 Data points: ${data.length}');
    }

    try {
      final response = await http.post(
        Uri.parse(AppConfig.apiUrl),
        headers: {'Content-Type': 'text/csv'},
        body: csvData,
      );

      if (AppConfig.debugMode) {
        print('✅ Response: ${response.statusCode}');
        print('📝 Body: ${response.body}');
      }

      return response;
    } catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Error sending data: $e');
      }
      rethrow;
    }
  }
}
