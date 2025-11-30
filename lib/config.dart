/// Configuration for the Fall Detection app
class AppConfig {
  // Server Configuration
  // Change this to your server's IP address
  static const String serverUrl = 'http://192.168.0.100:3030';
  static const String fallDetectionEndpoint = '/fall-detection/receive-data';

  // Get the full API URL
  static String get apiUrl => '$serverUrl$fallDetectionEndpoint';

  // App Configuration
  static const int fallDetectionCountdown = 3; // seconds
  static const int maxDataPoints = 600; // ~60 seconds at 10Hz
  static const int realTimeUpdateInterval = 5; // seconds

  // Debug mode - set to false in production
  static const bool debugMode = false;
}
