import 'package:flutter_test/flutter_test.dart';
import 'package:fall_down_detection_mobile/utils/sensor_math.dart';
import 'package:fall_down_detection_mobile/models/sensor_data.dart';

void main() {
  group('SensorMath', () {
    group('calculateSVM', () {
      test('should calculate SVM correctly', () {
        expect(SensorMath.calculateSVM(3.0, 4.0, 0.0), 5.0);
        expect(SensorMath.calculateSVM(0.0, 0.0, 9.8), closeTo(9.8, 0.001));
        expect(SensorMath.calculateSVM(1.0, 1.0, 1.0), closeTo(1.732, 0.001));
      });

      test('should handle negative values', () {
        expect(SensorMath.calculateSVM(-3.0, -4.0, 0.0), 5.0);
        expect(SensorMath.calculateSVM(-1.0, 2.0, -2.0), 3.0);
      });

      test('should handle zero', () {
        expect(SensorMath.calculateSVM(0.0, 0.0, 0.0), 0.0);
      });
    });

    group('calculateVariance', () {
      test('should calculate variance correctly', () {
        final values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
        // Mean = 5, variance = 4
        expect(SensorMath.calculateVariance(values), closeTo(4.0, 0.001));
      });

      test('should return 0 for empty list', () {
        expect(SensorMath.calculateVariance([]), 0.0);
      });

      test('should return 0 for single element', () {
        expect(SensorMath.calculateVariance([5.0]), 0.0);
      });

      test('should handle identical values', () {
        expect(SensorMath.calculateVariance([5.0, 5.0, 5.0]), 0.0);
      });
    });

    group('calculateStandardDeviation', () {
      test('should calculate standard deviation correctly', () {
        final values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
        // Variance = 4, SD = 2
        expect(
          SensorMath.calculateStandardDeviation(values),
          closeTo(2.0, 0.001),
        );
      });
    });

    group('calculateSVMVariance', () {
      test('should calculate SVM variance over window', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.6,
          ),
        ];

        final variance = SensorMath.calculateSVMVariance(window);
        expect(variance, greaterThan(0.0));
        expect(variance, lessThan(0.1)); // Low variance (motionless)
      });

      test('should return 0 for empty window', () {
        expect(SensorMath.calculateSVMVariance([]), 0.0);
      });
    });

    group('calculateJerk', () {
      test('should calculate jerk from accelerometer changes', () {
        final baseTime = DateTime.now();
        final window = [
          SensorData.fromValues(
            timestamp: baseTime,
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: baseTime.add(const Duration(milliseconds: 100)),
            x: 0.0,
            y: 0.0,
            z: 15.0, // Sudden increase
          ),
          SensorData.fromValues(
            timestamp: baseTime.add(const Duration(milliseconds: 200)),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        final jerk = SensorMath.calculateJerk(window);
        expect(jerk, greaterThan(0.0));
        expect(jerk, greaterThan(50.0)); // High jerk from sudden change
      });

      test('should return 0 for insufficient data', () {
        expect(SensorMath.calculateJerk([]), 0.0);
        final singleData = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
        ];
        expect(SensorMath.calculateJerk(singleData), 0.0);
      });
    });

    group('calculateAverageJerk', () {
      test('should calculate average jerk', () {
        final baseTime = DateTime.now();
        final window = [
          SensorData.fromValues(
            timestamp: baseTime,
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: baseTime.add(const Duration(milliseconds: 100)),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
          SensorData.fromValues(
            timestamp: baseTime.add(const Duration(milliseconds: 200)),
            x: 0.0,
            y: 0.0,
            z: 10.2,
          ),
        ];

        final avgJerk = SensorMath.calculateAverageJerk(window);
        expect(avgJerk, greaterThan(0.0));
      });
    });

    group('calculateMeanSVM', () {
      test('should calculate mean SVM', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.6,
          ),
        ];

        final mean = SensorMath.calculateMeanSVM(window);
        expect(mean, closeTo(9.8, 0.2));
      });

      test('should return 0 for empty window', () {
        expect(SensorMath.calculateMeanSVM([]), 0.0);
      });
    });

    group('calculatePeakSVM', () {
      test('should find peak SVM value', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 35.0, // Peak
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.calculatePeakSVM(window), closeTo(35.0, 0.1));
      });
    });

    group('calculateMinSVM', () {
      test('should find minimum SVM value', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 0.5, // Minimum (freefall-like)
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.calculateMinSVM(window), closeTo(0.5, 0.1));
      });
    });

    group('findPeakIndex', () {
      test('should find index of peak SVM', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 35.0, // Peak at index 1
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.findPeakIndex(window), 1);
      });

      test('should return -1 for empty window', () {
        expect(SensorMath.findPeakIndex([]), -1);
      });
    });

    group('isMotionless', () {
      test('should detect motionless state', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.81,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.79,
          ),
        ];

        expect(SensorMath.isMotionless(window), true);
      });

      test('should detect motion state', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 5.0,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 15.0,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.isMotionless(window), false);
      });
    });

    group('detectImpact', () {
      test('should detect high-G impact', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 40.0, // High-G impact (>3.5g)
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.detectImpact(window), true);
      });

      test('should not detect normal movement as impact', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 12.0,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 10.0,
          ),
        ];

        expect(SensorMath.detectImpact(window), false);
      });
    });

    group('calculateGravityVector', () {
      test('should calculate gravity vector', () {
        final window = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.1,
            y: 0.2,
            z: 9.8,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.1,
            z: 9.9,
          ),
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.1,
            y: 0.0,
            z: 9.7,
          ),
        ];

        final gravityVector = SensorMath.calculateGravityVector(window);
        expect(gravityVector['x'], closeTo(0.067, 0.1));
        expect(gravityVector['y'], closeTo(0.1, 0.1));
        expect(gravityVector['z'], closeTo(9.8, 0.1));
      });

      test('should return zero vector for empty window', () {
        final gravityVector = SensorMath.calculateGravityVector([]);
        expect(gravityVector['x'], 0.0);
        expect(gravityVector['y'], 0.0);
        expect(gravityVector['z'], 0.0);
      });
    });

    group('calculateOrientationChange', () {
      test('should calculate angle between parallel vectors', () {
        final vector1 = {'x': 0.0, 'y': 0.0, 'z': 9.8};
        final vector2 = {'x': 0.0, 'y': 0.0, 'z': 9.8};

        final angle = SensorMath.calculateOrientationChange(vector1, vector2);
        expect(angle, closeTo(0.0, 0.1));
      });

      test('should calculate angle between perpendicular vectors', () {
        final vector1 = {'x': 9.8, 'y': 0.0, 'z': 0.0};
        final vector2 = {'x': 0.0, 'y': 9.8, 'z': 0.0};

        final angle = SensorMath.calculateOrientationChange(vector1, vector2);
        expect(angle, closeTo(90.0, 0.1));
      });

      test('should calculate angle between opposite vectors', () {
        final vector1 = {'x': 0.0, 'y': 0.0, 'z': 9.8};
        final vector2 = {'x': 0.0, 'y': 0.0, 'z': -9.8};

        final angle = SensorMath.calculateOrientationChange(vector1, vector2);
        expect(angle, closeTo(180.0, 0.1));
      });

      test('should handle zero magnitude vectors', () {
        final vector1 = {'x': 0.0, 'y': 0.0, 'z': 0.0};
        final vector2 = {'x': 9.8, 'y': 0.0, 'z': 0.0};

        final angle = SensorMath.calculateOrientationChange(vector1, vector2);
        expect(angle, 0.0);
      });
    });

    group('extractTimeWindow', () {
      test('should extract time window around center index', () {
        final baseTime = DateTime(2025, 12, 11, 10, 0, 0);
        final data = List.generate(10, (i) {
          return SensorData.fromValues(
            timestamp: baseTime.add(Duration(seconds: i)),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          );
        });

        final window = SensorMath.extractTimeWindow(data, 5, 4.0);

        // Should get roughly 4 seconds of data centered at index 5
        expect(window.length, greaterThan(2));
        expect(window.length, lessThan(6));
      });

      test('should return empty for invalid index', () {
        final data = [
          SensorData.fromValues(
            timestamp: DateTime.now(),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          ),
        ];

        expect(SensorMath.extractTimeWindow(data, -1, 1.0), isEmpty);
        expect(SensorMath.extractTimeWindow(data, 10, 1.0), isEmpty);
      });
    });

    group('filterByTimeRange', () {
      test('should filter data by time range', () {
        final baseTime = DateTime(2025, 12, 11, 10, 0, 0);
        final data = List.generate(10, (i) {
          return SensorData.fromValues(
            timestamp: baseTime.add(Duration(seconds: i)),
            x: 0.0,
            y: 0.0,
            z: 9.8,
          );
        });

        final startTime = baseTime.add(const Duration(seconds: 3));
        final endTime = baseTime.add(const Duration(seconds: 7));

        final filtered = SensorMath.filterByTimeRange(data, startTime, endTime);

        expect(filtered.length, 5); // Indices 3, 4, 5, 6, 7
        expect(
          filtered.first.timestamp.isAtSameMomentAs(startTime) ||
              filtered.first.timestamp.isAfter(startTime),
          true,
        );
        expect(
          filtered.last.timestamp.isAtSameMomentAs(endTime) ||
              filtered.last.timestamp.isBefore(endTime),
          true,
        );
      });
    });

    group('unit conversions', () {
      test('should convert g-force to m/s²', () {
        expect(SensorMath.gToMps2(1.0), closeTo(9.80665, 0.00001));
        expect(SensorMath.gToMps2(3.5), closeTo(34.323, 0.01));
        expect(SensorMath.gToMps2(0.0), 0.0);
      });

      test('should convert m/s² to g-force', () {
        expect(SensorMath.mps2ToG(9.80665), closeTo(1.0, 0.00001));
        expect(SensorMath.mps2ToG(34.323), closeTo(3.5, 0.01));
        expect(SensorMath.mps2ToG(0.0), 0.0);
      });

      test('should round-trip conversion', () {
        final original = 5.5; // g
        final converted = SensorMath.gToMps2(original);
        final back = SensorMath.mps2ToG(converted);
        expect(back, closeTo(original, 0.0001));
      });
    });
  });
}
