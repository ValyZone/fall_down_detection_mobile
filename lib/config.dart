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

  // Fall Detection Parameters
  static const int impactWindowSeconds = 10; // Time allowed for stop after impact
  static const double impactThreshold = 34.335; // 3.5g in m/s²
  static const double varianceThreshold = 0.5; // For motionless detection
  static const double gyroscopeThreshold = 0.1; // rad/s for rotation detection
  static const int bufferCapacity = 1000; // ~20 seconds at 50Hz

  // Debug mode - set to false in production
  static const bool debugMode = true; // Enable for development
}
