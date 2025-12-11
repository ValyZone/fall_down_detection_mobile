import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Represents a single accelerometer reading with calculated metrics.
///
/// This model stores raw x, y, z acceleration values along with the
/// Signal Vector Magnitude (SVM) for easier fall detection analysis.
class SensorData {
  /// Timestamp when the reading was captured
  final DateTime timestamp;

  /// Acceleration in x-axis (m/s²)
  final double x;

  /// Acceleration in y-axis (m/s²)
  final double y;

  /// Acceleration in z-axis (m/s²)
  final double z;

  /// Signal Vector Magnitude: sqrt(x² + y² + z²)
  /// Represents the total acceleration magnitude regardless of device orientation
  final double svm;

  const SensorData({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
    required this.svm,
  });

  /// Creates a SensorData instance from an AccelerometerEvent
  factory SensorData.fromAccelerometer(AccelerometerEvent event) {
    final now = DateTime.now();
    final svm = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    return SensorData(
      timestamp: now,
      x: event.x,
      y: event.y,
      z: event.z,
      svm: svm,
    );
  }

  /// Creates a SensorData instance from raw values
  factory SensorData.fromValues({
    required DateTime timestamp,
    required double x,
    required double y,
    required double z,
  }) {
    final svm = sqrt(x * x + y * y + z * z);

    return SensorData(
      timestamp: timestamp,
      x: x,
      y: y,
      z: z,
      svm: svm,
    );
  }

  /// Converts sensor data to JSON format for server transmission
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'x': x,
      'y': y,
      'z': z,
      'svm': svm,
    };
  }

  /// Creates a SensorData instance from JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      svm: (json['svm'] as num).toDouble(),
    );
  }

  /// Converts to CSV format compatible with existing API
  /// Format: "Time (s)\tAcceleration x\tAcceleration y\tAcceleration z\tAbsolute acceleration"
  String toCsvRow(double timeInSeconds) {
    return '$timeInSeconds\t'
        '${x.toStringAsFixed(2)}\t'
        '${y.toStringAsFixed(2)}\t'
        '${z.toStringAsFixed(2)}\t'
        '${svm.toStringAsFixed(2)}';
  }

  /// Creates a copy with modified fields
  SensorData copyWith({
    DateTime? timestamp,
    double? x,
    double? y,
    double? z,
    double? svm,
  }) {
    return SensorData(
      timestamp: timestamp ?? this.timestamp,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      svm: svm ?? this.svm,
    );
  }

  /// Returns the acceleration in g-force units (1g = 9.80665 m/s²)
  double get svmInGs => svm / 9.80665;

  /// Returns the elapsed time in seconds from a reference timestamp
  double timeInSeconds(DateTime reference) {
    return timestamp.difference(reference).inMicroseconds / 1000000.0;
  }

  @override
  String toString() {
    return 'SensorData('
        'time: ${timestamp.toIso8601String()}, '
        'x: ${x.toStringAsFixed(2)}, '
        'y: ${y.toStringAsFixed(2)}, '
        'z: ${z.toStringAsFixed(2)}, '
        'svm: ${svm.toStringAsFixed(2)} m/s² [${svmInGs.toStringAsFixed(2)}g]'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SensorData &&
        other.timestamp == timestamp &&
        other.x == x &&
        other.y == y &&
        other.z == z &&
        other.svm == svm;
  }

  @override
  int get hashCode {
    return Object.hash(timestamp, x, y, z, svm);
  }
}
