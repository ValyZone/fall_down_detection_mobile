import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  static const String _csvHeader = '"Time (s)","Acceleration x (m/s^2)",'
      '"Acceleration y (m/s^2)","Acceleration z (m/s^2)",'
      '"Absolute acceleration (m/s^2)",'
      '"Gyroscope x (rad/s)","Gyroscope y (rad/s)","Gyroscope z (rad/s)",'
      '"Gyroscope magnitude (rad/s)"\n';

  static Future<Map<String, dynamic>> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Server is running',
          'service': data['service'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed',
      };
    }
  }

  static Future<http.Response> sendAccelerometerData(
      List<String> data) async {
    final csvData = _csvHeader + data.join('\n');

    return await http.post(
      Uri.parse(AppConfig.apiUrl),
      headers: {'Content-Type': 'text/csv'},
      body: csvData,
    );
  }

  static Future<http.Response> sendUserFineConfirmation() async {
    return await http.post(
      Uri.parse(AppConfig.userFineUrl),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<List<String>> fetchMockData(String dataType) async {
    final url = '${AppConfig.serverUrl}/mock-data/$dataType';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      return lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
    }
    throw Exception('Failed to fetch mock data');
  }
}
