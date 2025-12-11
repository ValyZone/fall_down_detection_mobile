import 'dart:math';
import '../models/sensor_data.dart';

/// Utility class for sensor data mathematical operations.
///
/// Provides functions for calculating Signal Vector Magnitude, variance,
/// jerk, and other metrics used in fall detection analysis.
class SensorMath {
  /// Calculates the Signal Vector Magnitude from x, y, z components.
  ///
  /// SVM = √(x² + y² + z²)
  ///
  /// This represents the total acceleration magnitude regardless of
  /// device orientation.
  static double calculateSVM(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Calculates the variance of a list of values.
  ///
  /// Variance = Σ(x - mean)² / n
  ///
  /// Returns 0.0 if the list is empty or has only one element.
  static double calculateVariance(List<double> values) {
    if (values.isEmpty || values.length == 1) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDifferences =
        values.map((value) => pow(value - mean, 2)).toList();
    final variance =
        squaredDifferences.reduce((a, b) => a + b) / values.length;

    return variance;
  }

  /// Calculates the standard deviation of a list of values.
  ///
  /// Standard Deviation = √variance
  static double calculateStandardDeviation(List<double> values) {
    return sqrt(calculateVariance(values));
  }

  /// Calculates the SVM variance over a time window.
  ///
  /// This is useful for detecting motionless states (low variance)
  /// vs. chaotic motion (high variance).
  static double calculateSVMVariance(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    final svmValues = window.map((data) => data.svm).toList();
    return calculateVariance(svmValues);
  }

  /// Calculates jerk (rate of acceleration change) over a time window.
  ///
  /// Jerk = Δa / Δt (change in acceleration over time)
  ///
  /// High jerk values indicate sudden changes in motion, which occur
  /// during impacts and chaotic tumbling.
  ///
  /// Returns the maximum absolute jerk value in the window.
  static double calculateJerk(List<SensorData> window) {
    if (window.length < 2) return 0.0;

    double maxJerk = 0.0;

    for (int i = 1; i < window.length; i++) {
      final dt = window[i]
              .timestamp
              .difference(window[i - 1].timestamp)
              .inMicroseconds /
          1000000.0;

      if (dt > 0) {
        final dSvm = window[i].svm - window[i - 1].svm;
        final jerk = dSvm.abs() / dt;

        if (jerk > maxJerk) {
          maxJerk = jerk;
        }
      }
    }

    return maxJerk;
  }

  /// Calculates the average jerk over a time window.
  static double calculateAverageJerk(List<SensorData> window) {
    if (window.length < 2) return 0.0;

    double totalJerk = 0.0;
    int count = 0;

    for (int i = 1; i < window.length; i++) {
      final dt = window[i]
              .timestamp
              .difference(window[i - 1].timestamp)
              .inMicroseconds /
          1000000.0;

      if (dt > 0) {
        final dSvm = window[i].svm - window[i - 1].svm;
        final jerk = dSvm.abs() / dt;
        totalJerk += jerk;
        count++;
      }
    }

    return count > 0 ? totalJerk / count : 0.0;
  }

  /// Calculates the mean (average) SVM value over a time window.
  static double calculateMeanSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    final sum = window.fold<double>(0.0, (sum, data) => sum + data.svm);
    return sum / window.length;
  }

  /// Calculates the peak (maximum) SVM value in a window.
  static double calculatePeakSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    return window.map((data) => data.svm).reduce((a, b) => a > b ? a : b);
  }

  /// Calculates the minimum SVM value in a window.
  static double calculateMinSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    return window.map((data) => data.svm).reduce((a, b) => a < b ? a : b);
  }

  /// Finds the index of the peak (maximum) SVM value in a window.
  ///
  /// Returns -1 if the window is empty.
  static int findPeakIndex(List<SensorData> window) {
    if (window.isEmpty) return -1;

    int maxIndex = 0;
    double maxValue = window[0].svm;

    for (int i = 1; i < window.length; i++) {
      if (window[i].svm > maxValue) {
        maxValue = window[i].svm;
        maxIndex = i;
      }
    }

    return maxIndex;
  }

  /// Checks if the motion is relatively motionless based on SVM variance.
  ///
  /// [window]: Time window of sensor data to analyze
  /// [varianceThreshold]: Maximum allowed variance (default: 0.5 m/s²)
  ///
  /// Returns true if variance is below threshold (motionless).
  static bool isMotionless(
    List<SensorData> window, {
    double varianceThreshold = 0.5,
  }) {
    final variance = calculateSVMVariance(window);
    return variance < varianceThreshold;
  }

  /// Detects if there's a high-G impact in the window.
  ///
  /// [window]: Time window of sensor data to analyze
  /// [impactThreshold]: Minimum SVM value to consider as impact (default: 34.335 m/s² = 3.5g)
  ///
  /// Returns true if any reading exceeds the threshold.
  static bool detectImpact(
    List<SensorData> window, {
    double impactThreshold = 34.335, // 3.5g in m/s²
  }) {
    return window.any((data) => data.svm > impactThreshold);
  }

  /// Calculates the gravity vector (long-term average) from a window.
  ///
  /// The gravity vector represents the device's orientation relative to Earth.
  /// Returns a map with 'x', 'y', 'z' components.
  static Map<String, double> calculateGravityVector(List<SensorData> window) {
    if (window.isEmpty) {
      return {'x': 0.0, 'y': 0.0, 'z': 0.0};
    }

    double sumX = 0.0;
    double sumY = 0.0;
    double sumZ = 0.0;

    for (final data in window) {
      sumX += data.x;
      sumY += data.y;
      sumZ += data.z;
    }

    final count = window.length;
    return {
      'x': sumX / count,
      'y': sumY / count,
      'z': sumZ / count,
    };
  }

  /// Calculates the angle (in degrees) between two gravity vectors.
  ///
  /// This is used to detect orientation changes (e.g., phone falling over).
  /// Returns angle in range [0, 180] degrees.
  static double calculateOrientationChange(
    Map<String, double> vector1,
    Map<String, double> vector2,
  ) {
    final x1 = vector1['x']!;
    final y1 = vector1['y']!;
    final z1 = vector1['z']!;

    final x2 = vector2['x']!;
    final y2 = vector2['y']!;
    final z2 = vector2['z']!;

    // Calculate magnitudes
    final mag1 = sqrt(x1 * x1 + y1 * y1 + z1 * z1);
    final mag2 = sqrt(x2 * x2 + y2 * y2 + z2 * z2);

    if (mag1 == 0.0 || mag2 == 0.0) return 0.0;

    // Calculate dot product
    final dotProduct = x1 * x2 + y1 * y2 + z1 * z2;

    // Calculate angle using arccos(dot product / (mag1 * mag2))
    final cosAngle = dotProduct / (mag1 * mag2);

    // Clamp to [-1, 1] to handle floating-point errors
    final clampedCos = cosAngle.clamp(-1.0, 1.0);

    // Convert from radians to degrees
    final angleRadians = acos(clampedCos);
    final angleDegrees = angleRadians * 180.0 / pi;

    return angleDegrees;
  }

  /// Extracts a time window from sensor data around a specific index.
  ///
  /// [data]: Full list of sensor data
  /// [centerIndex]: Index to center the window around
  /// [durationSeconds]: Window duration in seconds (total, not radius)
  ///
  /// Returns a sublist of sensor data within the time window.
  static List<SensorData> extractTimeWindow(
    List<SensorData> data,
    int centerIndex,
    double durationSeconds,
  ) {
    if (data.isEmpty || centerIndex < 0 || centerIndex >= data.length) {
      return [];
    }

    final centerTimestamp = data[centerIndex].timestamp;
    final halfDuration = Duration(
      microseconds: (durationSeconds * 1000000 / 2).round(),
    );

    final startTime = centerTimestamp.subtract(halfDuration);
    final endTime = centerTimestamp.add(halfDuration);

    return data.where((d) {
      return d.timestamp.isAfter(startTime) && d.timestamp.isBefore(endTime);
    }).toList();
  }

  /// Filters data to a specific time range.
  ///
  /// Returns all sensor data between [startTime] and [endTime] (inclusive).
  static List<SensorData> filterByTimeRange(
    List<SensorData> data,
    DateTime startTime,
    DateTime endTime,
  ) {
    return data.where((d) {
      return (d.timestamp.isAtSameMomentAs(startTime) ||
              d.timestamp.isAfter(startTime)) &&
          (d.timestamp.isAtSameMomentAs(endTime) ||
              d.timestamp.isBefore(endTime));
    }).toList();
  }

  /// Converts g-force value to m/s²
  static double gToMps2(double gForce) {
    return gForce * 9.80665;
  }

  /// Converts m/s² value to g-force
  static double mps2ToG(double mps2) {
    return mps2 / 9.80665;
  }
}
