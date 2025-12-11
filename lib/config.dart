/// Configuration for the Fall Detection app
class AppConfig {
  // Server Configuration
  // Change this to your server's IP address
  static const String serverUrl = 'http://192.168.0.100:3030';
  static const String fallDetectionEndpoint = '/fall-detection/receive-data';
  static const String userFineEndpoint = '/user-fine';

  // Get the full API URLs
  static String get apiUrl => '$serverUrl$fallDetectionEndpoint';
  static String get userFineUrl => '$serverUrl$userFineEndpoint';

  // App Configuration
  static const int fallDetectionCountdown = 3; // seconds
  static const int bufferDurationSeconds = 20; // Keep 20 seconds of data
  static const int realTimeUpdateInterval = 5; // Send data every 5 seconds
  static const int sensorFrequencyHz = 10; // Sensor samples per second
  
  // Calculated buffer size
  static int get maxDataPoints => bufferDurationSeconds * sensorFrequencyHz; // 200 points for 20 seconds at 10Hz

  // Fall Detection Parameters
  static const int impactWindowSeconds = 10; // Time allowed for stop after impact
  static const double impactThreshold = 34.335; // 3.5g in m/s²
  static const double varianceThreshold = 0.5; // For motionless detection
  static const double gyroscopeThreshold = 0.1; // rad/s for rotation detection
  static const int bufferCapacity = 1000; // ~20 seconds at 50Hz

  // Debug mode - set to false in production
  static const bool debugMode = true; // Enable for development
}
