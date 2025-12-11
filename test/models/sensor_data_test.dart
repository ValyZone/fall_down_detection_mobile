import 'package:flutter_test/flutter_test.dart';
import 'package:fall_down_detection_mobile/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  group('SensorData', () {
    test('should create instance with correct SVM calculation', () {
      final timestamp = DateTime(2025, 12, 11, 10, 30);
      final data = SensorData.fromValues(
        timestamp: timestamp,
        x: 3.0,
        y: 4.0,
        z: 0.0,
      );

      expect(data.timestamp, timestamp);
      expect(data.x, 3.0);
      expect(data.y, 4.0);
      expect(data.z, 0.0);
      expect(data.svm, 5.0); // sqrt(3² + 4² + 0²) = 5
    });

    test('should calculate SVM correctly for various values', () {
      final data1 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 0.0,
        y: 0.0,
        z: 9.80665,
      );
      expect(data1.svm, closeTo(9.80665, 0.00001));
      expect(data1.svmInGs, closeTo(1.0, 0.00001));

      final data2 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 1.0,
        y: 1.0,
        z: 1.0,
      );
      expect(data2.svm, closeTo(1.732, 0.001)); // sqrt(3)

      final data3 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 10.0,
        y: 20.0,
        z: 30.0,
      );
      expect(data3.svm, closeTo(37.417, 0.001)); // sqrt(1400)
    });

    test('should create from AccelerometerEvent', () {
      final event = AccelerometerEvent(2.0, 3.0, 9.8);
      final data = SensorData.fromAccelerometer(event);

      expect(data.x, 2.0);
      expect(data.y, 3.0);
      expect(data.z, 9.8);
      expect(data.svm, closeTo(10.442, 0.001)); // sqrt(4 + 9 + 96.04)
      expect(data.timestamp, isNotNull);
    });

    test('should convert to JSON correctly', () {
      final timestamp = DateTime(2025, 12, 11, 10, 30, 45);
      final data = SensorData.fromValues(
        timestamp: timestamp,
        x: 1.5,
        y: 2.5,
        z: 9.5,
      );

      final json = data.toJson();

      expect(json['timestamp'], '2025-12-11T10:30:45.000');
      expect(json['x'], 1.5);
      expect(json['y'], 2.5);
      expect(json['z'], 9.5);
      expect(json['svm'], closeTo(9.937, 0.001)); // sqrt(2.25 + 6.25 + 90.25)
    });

    test('should create from JSON correctly', () {
      final json = {
        'timestamp': '2025-12-11T10:30:45.000',
        'x': 1.5,
        'y': 2.5,
        'z': 9.5,
        'svm': 9.937,
      };

      final data = SensorData.fromJson(json);

      expect(data.timestamp, DateTime(2025, 12, 11, 10, 30, 45));
      expect(data.x, 1.5);
      expect(data.y, 2.5);
      expect(data.z, 9.5);
      expect(data.svm, 9.937);
    });

    test('should convert to CSV row format', () {
      final data = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 1.234,
        y: 2.345,
        z: 9.876,
      );

      final csvRow = data.toCsvRow(1.5);

      expect(csvRow, contains('1.5\t'));
      expect(csvRow, contains('1.23\t'));
      expect(csvRow, contains('2.35\t'));
      expect(csvRow, contains('9.88\t'));
      expect(csvRow.split('\t').length, 5);
    });

    test('should calculate time in seconds correctly', () {
      final reference = DateTime(2025, 12, 11, 10, 30, 0);
      final data = SensorData.fromValues(
        timestamp: DateTime(2025, 12, 11, 10, 30, 5, 500), // +5.5 seconds
        x: 0.0,
        y: 0.0,
        z: 9.8,
      );

      final timeInSec = data.timeInSeconds(reference);
      expect(timeInSec, closeTo(5.5, 0.001));
    });

    test('should convert SVM to g-force correctly', () {
      final data1 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 0.0,
        y: 0.0,
        z: 9.80665,
      );
      expect(data1.svmInGs, closeTo(1.0, 0.001));

      final data2 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 0.0,
        y: 0.0,
        z: 34.32, // ~3.5g
      );
      expect(data2.svmInGs, closeTo(3.5, 0.01));

      final data3 = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 0.0,
        y: 0.0,
        z: 0.0, // 0g (free fall)
      );
      expect(data3.svmInGs, 0.0);
    });

    test('should copy with modified fields', () {
      final original = SensorData.fromValues(
        timestamp: DateTime(2025, 12, 11),
        x: 1.0,
        y: 2.0,
        z: 3.0,
      );

      final modified = original.copyWith(x: 5.0, z: 7.0);

      expect(modified.x, 5.0);
      expect(modified.y, 2.0); // unchanged
      expect(modified.z, 7.0);
      expect(modified.timestamp, original.timestamp); // unchanged
    });

    test('should have correct toString representation', () {
      final data = SensorData.fromValues(
        timestamp: DateTime(2025, 12, 11, 10, 30),
        x: 1.0,
        y: 2.0,
        z: 9.8,
      );

      final str = data.toString();
      expect(str, contains('SensorData'));
      expect(str, contains('2025-12-11'));
      expect(str, contains('1.00'));
      expect(str, contains('2.00'));
      expect(str, contains('9.80'));
    });

    test('should implement equality correctly', () {
      final timestamp = DateTime(2025, 12, 11, 10, 30);
      final data1 = SensorData.fromValues(
        timestamp: timestamp,
        x: 1.0,
        y: 2.0,
        z: 3.0,
      );

      final data2 = SensorData.fromValues(
        timestamp: timestamp,
        x: 1.0,
        y: 2.0,
        z: 3.0,
      );

      final data3 = SensorData.fromValues(
        timestamp: timestamp,
        x: 1.0,
        y: 2.0,
        z: 4.0, // different z
      );

      expect(data1, equals(data2));
      expect(data1, isNot(equals(data3)));
      expect(data1.hashCode, equals(data2.hashCode));
    });

    test('should handle negative acceleration values', () {
      final data = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: -3.0,
        y: -4.0,
        z: 0.0,
      );

      expect(data.x, -3.0);
      expect(data.y, -4.0);
      expect(data.svm, 5.0); // sqrt(9 + 16) = 5
    });

    test('should handle zero acceleration', () {
      final data = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 0.0,
        y: 0.0,
        z: 0.0,
      );

      expect(data.svm, 0.0);
      expect(data.svmInGs, 0.0);
    });

    test('should handle high-g impact values', () {
      final data = SensorData.fromValues(
        timestamp: DateTime.now(),
        x: 100.0,
        y: 50.0,
        z: 30.0,
      );

      expect(data.svm, closeTo(115.758, 0.01)); // sqrt(10000 + 2500 + 900)
      expect(data.svmInGs, closeTo(11.81, 0.01)); // 115.758 / 9.80665
    });

    test('JSON round-trip should preserve data', () {
      final original = SensorData.fromValues(
        timestamp: DateTime(2025, 12, 11, 10, 30, 45, 123),
        x: 1.234567,
        y: 2.345678,
        z: 9.876543,
      );

      final json = original.toJson();
      final restored = SensorData.fromJson(json);

      expect(restored.x, original.x);
      expect(restored.y, original.y);
      expect(restored.z, original.z);
      expect(restored.svm, original.svm);
      // Timestamp might lose microsecond precision in ISO string
      expect(
        restored.timestamp.difference(original.timestamp).inMilliseconds.abs(),
        lessThan(10),
      );
    });
  });
}
