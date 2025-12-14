import 'dart:math';
import '../models/sensor_data.dart';

class SensorMath {
  static double calculateSVM(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  static double calculateVariance(List<double> values) {
    if (values.isEmpty || values.length == 1) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDifferences =
        values.map((value) => pow(value - mean, 2)).toList();
    final variance =
        squaredDifferences.reduce((a, b) => a + b) / values.length;

    return variance;
  }

  static double calculateStandardDeviation(List<double> values) {
    return sqrt(calculateVariance(values));
  }

  static double calculateSVMVariance(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    final svmValues = window.map((data) => data.svm).toList();
    return calculateVariance(svmValues);
  }

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

  static double calculateMeanSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    final sum = window.fold<double>(0.0, (sum, data) => sum + data.svm);
    return sum / window.length;
  }

  static double calculatePeakSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    return window.map((data) => data.svm).reduce((a, b) => a > b ? a : b);
  }

  static double calculateMinSVM(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    return window.map((data) => data.svm).reduce((a, b) => a < b ? a : b);
  }

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

  static bool isMotionless(
    List<SensorData> window, {
    double varianceThreshold = 0.5,
  }) {
    final variance = calculateSVMVariance(window);
    return variance < varianceThreshold;
  }

  static bool detectImpact(
    List<SensorData> window, {
    double impactThreshold = 34.335,
  }) {
    return window.any((data) => data.svm > impactThreshold);
  }

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

    final dotProduct = x1 * x2 + y1 * y2 + z1 * z2;

    final cosAngle = dotProduct / (mag1 * mag2);

    final clampedCos = cosAngle.clamp(-1.0, 1.0);

    final angleRadians = acos(clampedCos);
    final angleDegrees = angleRadians * 180.0 / pi;

    return angleDegrees;
  }

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

  static double gToMps2(double gForce) {
    return gForce * 9.80665;
  }

  static double mps2ToG(double mps2) {
    return mps2 / 9.80665;
  }
}
