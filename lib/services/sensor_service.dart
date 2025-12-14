import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/ring_buffer.dart';
import '../models/sensor_data.dart';
import '../config.dart';

/// Service for managing sensor streams and circular buffer
class SensorService {
  // Circular buffer for storing sensor data
  final RingBuffer<SensorData> _buffer = RingBuffer<SensorData>(
    AppConfig.bufferCapacity,
  );

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Latest gyroscope reading (synced with accelerometer)
  GyroscopeEvent? _latestGyroscope;

  // Callbacks
  void Function(double svm)? onImpactDetected;
  void Function()? onMotionlessDetected;
  void Function(SensorData data)? onDataReceived;

  // State
  bool _isRunning = false;

  // Rolling window for stationarity detection (1 second = 50 samples)
  final List<double> _recentSvmValues = [];
  static const int _stationarityWindowSize = 50;

  /// Start sensor streams and monitoring
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _buffer.clear();
    _recentSvmValues.clear();

    // Subscribe to gyroscope (runs at higher frequency)
    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      _latestGyroscope = event;
    });

    // Subscribe to accelerometer (main data stream)
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final sensorData = SensorData.fromAccelerometer(event);

      // Add to circular buffer
      _buffer.push(sensorData);

      // Notify listeners
      onDataReceived?.call(sensorData);

      // Check for high-G impact
      _checkImpactCondition(sensorData);

      // Check for stationarity
      _checkMotionlessState(sensorData);
    });
  }

  /// Stop all sensors and clear buffer
  void stop() {
    _isRunning = false;
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _latestGyroscope = null;
  }

  /// Get frozen snapshot of current buffer
  List<SensorData> getBufferSnapshot() {
    return _buffer.snapshot();
  }

  /// Get current buffer size
  int get bufferSize => _buffer.length;

  /// Check if buffer is full
  bool get isBufferFull => _buffer.isFull;

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Clear the buffer
  void clearBuffer() {
    _buffer.clear();
    _recentSvmValues.clear();
  }

  /// Monitor for high-G impact events
  void _checkImpactCondition(SensorData data) {
    // Check if SVM exceeds impact threshold (3.5g = 34.335 m/s²)
    if (data.svm > AppConfig.impactThreshold) {
      onImpactDetected?.call(data.svm);
    }
  }

  /// Check if device is motionless
  ///
  /// Criteria:
  /// 1. Accelerometer StdDev < 0.05 m/s² (calculated over 1-second window)
  /// 2. Gyroscope magnitude < 0.1 rad/s (current rotation speed)
  void _checkMotionlessState(SensorData data) {
    // Maintain rolling window of SVM values (1 second = 50 samples)
    _recentSvmValues.add(data.svm);
    if (_recentSvmValues.length > _stationarityWindowSize) {
      _recentSvmValues.removeAt(0);
    }

    // Need at least 1 second of data
    if (_recentSvmValues.length < _stationarityWindowSize) {
      return;
    }

    // Calculate standard deviation of SVM values
    final stdDev = _calculateStandardDeviation(_recentSvmValues);

    // Get current gyroscope magnitude
    final gyroMag = _latestGyroscope != null
        ? sqrt(
            _latestGyroscope!.x * _latestGyroscope!.x +
                _latestGyroscope!.y * _latestGyroscope!.y +
                _latestGyroscope!.z * _latestGyroscope!.z,
          )
        : 0.0;

    // Check both conditions
    final isMotionless = stdDev < AppConfig.varianceThreshold &&
        gyroMag < AppConfig.gyroscopeThreshold;

    if (isMotionless) {
      onMotionlessDetected?.call();
    }
  }

  /// Calculate standard deviation of values
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;

    return sqrt(variance);
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}
