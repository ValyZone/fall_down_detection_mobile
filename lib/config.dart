class AppConfig {
  static const String serverUrl = 'http://192.168.0.100:3030';
  static const String fallDetectionEndpoint = '/fall-detection/receive-data';
  static const String userFineEndpoint = '/user-fine';

  static String get apiUrl => '$serverUrl$fallDetectionEndpoint';
  static String get userFineUrl => '$serverUrl$userFineEndpoint';

  static const int fallDetectionCountdown = 60; //sconds before auto-calling for help
  static const int bufferDurationSeconds = 20; //keep 20 seconds of data
  static const int impactWindowSeconds = 10; // Time allowed for stop after impact
  static const int postImpactCollectionSeconds = 5;
  static const double impactThreshold = 34.335; // 3.5g in m/s²
  static const double varianceThreshold = 0.5;
  static const double gyroscopeThreshold = 0.1;
  static const int bufferCapacity = 1000;
  static const bool debugMode = true;
}
