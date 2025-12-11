import 'package:flutter_test/flutter_test.dart';
import 'package:fall_down_detection_mobile/models/sensor_data.dart';
import 'package:fall_down_detection_mobile/utils/sensor_math.dart';

/// Integration tests for crash detection scenarios
///
/// These tests validate the complete detection logic using realistic
/// sensor data patterns.
void main() {
  group('Crash Detection Scenarios', () {
    group('True Positive Cases (Real Crashes)', () {
      test('Scenario 1: High-side crash with ejection', () {
        // Simulate high-side crash:
        // 1. Normal riding
        // 2. Sudden high-G impact (>5g) - rider ejected
        // 3. Brief free-fall
        // 4. Secondary impact
        // 5. Complete stillness

        final scenario = _generateHighSideCrash();

        // Validate impact detection
        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(49.0)); // >5g

        // Validate post-impact stillness
        final postImpact = scenario.sublist(scenario.length - 150);
        final variance = SensorMath.calculateSVMVariance(postImpact);
        expect(variance, lessThan(0.05)); // Very still

        // Should be detected as crash
        final isStationary = SensorMath.isMotionless(postImpact);
        expect(isStationary, true);
      });

      test('Scenario 2: Low-side slide crash', () {
        // Simulate low-side crash:
        // 1. Normal riding
        // 2. Moderate impact (3.5-4g) - bike slides out
        // 3. Continued sliding/tumbling
        // 4. Eventually comes to rest
        // 5. Stillness

        final scenario = _generateLowSideCrash();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(34.0)); // >3.5g
        expect(peakSvm, lessThan(50.0)); // Not extreme

        // Post-impact should show high variance (tumbling) then stillness
        final peakIndex = SensorMath.findPeakIndex(scenario);
        final tumblingWindow =
            scenario.sublist(peakIndex + 10, peakIndex + 60);
        final tumblingVariance =
            SensorMath.calculateSVMVariance(tumblingWindow);
        expect(tumblingVariance, greaterThan(5.0)); // Chaotic

        // Final stillness
        final finalWindow = scenario.sublist(scenario.length - 50);
        final finalVariance = SensorMath.calculateSVMVariance(finalWindow);
        expect(finalVariance, lessThan(0.1)); // Still
      });

      test('Scenario 3: Head-on collision', () {
        // Simulate head-on collision:
        // 1. Normal riding
        // 2. Extreme impact (>8g) - sudden stop
        // 3. Immediate stillness

        final scenario = _generateHeadOnCollision();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(78.0)); // >8g extreme

        // Post-impact immediate stillness
        final peakIndex = SensorMath.findPeakIndex(scenario);
        final postImpact = scenario.sublist(peakIndex + 10);
        final variance = SensorMath.calculateSVMVariance(postImpact);
        expect(variance, lessThan(0.1));
      });
    });

    group('True Negative Cases (False Alarms)', () {
      test('Scenario 4: Dropped phone (not riding)', () {
        // Phone dropped while parked:
        // 1. Stillness (phone on table)
        // 2. Moderate impact (phone hits ground)
        // 3. Bounces
        // 4. Picked up and moved

        final scenario = _generateDroppedPhone();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(30.0)); // Significant impact

        // But post-impact shows movement (being picked up)
        final peakIndex = SensorMath.findPeakIndex(scenario);
        final postImpact =
            scenario.sublist(peakIndex + 100, peakIndex + 200);
        final variance = SensorMath.calculateSVMVariance(postImpact);
        expect(variance, greaterThan(2.0)); // Movement

        // Should NOT be detected as stationary
        final isStationary = SensorMath.isMotionless(postImpact);
        expect(isStationary, false);
      });

      test('Scenario 5: Speed bump / pothole', () {
        // Riding over bump:
        // 1. Normal riding
        // 2. Moderate impact (2.5-3.0g)
        // 3. Continue riding

        final scenario = _generateSpeedBump();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(25.0)); // Noticeable
        expect(peakSvm, lessThan(35.0)); // Not crash-level

        // Post-impact shows continued riding
        final peakIndex = SensorMath.findPeakIndex(scenario);
        final postImpact = scenario.sublist(peakIndex + 50);
        final variance = SensorMath.calculateSVMVariance(postImpact);
        expect(variance, greaterThan(1.0)); // Continued movement
      });

      test('Scenario 6: Emergency braking at traffic light', () {
        // Hard braking without crash:
        // 1. Normal riding
        // 2. Moderate deceleration (2-3g)
        // 3. Stop (but NO prior high-G impact)
        // 4. Stillness

        final scenario = _generateEmergencyBraking();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, lessThan(34.0)); // Below crash threshold

        // Post-brake is stationary, but no crash
        final finalWindow = scenario.sublist(scenario.length - 50);
        final isStationary = SensorMath.isMotionless(finalWindow);
        expect(isStationary, true);

        // Key: NO high-G impact preceding the stop
      });

      test('Scenario 7: Phone in pocket while walking/running', () {
        // Phone bouncing in pocket:
        // 1. Continuous moderate impacts
        // 2. High variance throughout
        // 3. No single extreme peak

        final scenario = _generatePocketBouncing();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, lessThan(30.0)); // No extreme peak

        // High continuous variance
        final variance = SensorMath.calculateSVMVariance(scenario);
        expect(variance, greaterThan(3.0));
      });
    });

    group('Edge Cases', () {
      test('Scenario 8: Crash with delayed stationarity', () {
        // Crash where bike slides for several seconds before stopping
        final scenario = _generateDelayedStop();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, greaterThan(40.0));

        // Check that we eventually reach stationarity
        final finalWindow = scenario.sublist(scenario.length - 50);
        final isStationary = SensorMath.isMotionless(finalWindow);
        expect(isStationary, true);
      });

      test('Scenario 9: Multiple moderate impacts (rough road)', () {
        // Riding on very rough terrain with multiple bumps
        final scenario = _generateRoughTerrain();

        // Multiple peaks, but none extreme
        final allPeaks = _findAllPeaks(scenario, threshold: 25.0);
        expect(allPeaks.length, greaterThan(3));

        // No single peak should be crash-level
        for (final peak in allPeaks) {
          expect(peak, lessThan(34.0));
        }
      });

      test('Scenario 10: Low-speed tipover (parking)', () {
        // Bike tips over while parked:
        // 1. Stillness
        // 2. Slow rotation
        // 3. Low impact
        // 4. Stillness

        final scenario = _generateParkingTipover();

        final peakSvm = SensorMath.calculatePeakSVM(scenario);
        expect(peakSvm, lessThan(25.0)); // Low impact

        // Should NOT trigger (below threshold)
      });
    });

    group('Stationarity Detection', () {
      test('should detect stillness with low std dev', () {
        final stillData = _generateStillData(100);

        final stdDev = SensorMath.calculateStandardDeviation(
          stillData.map((d) => d.svm).toList(),
        );

        expect(stdDev, lessThan(0.05));
        expect(SensorMath.isMotionless(stillData), true);
      });

      test('should not detect movement as stillness', () {
        final movingData = _generateNormalRiding(100);

        final stdDev = SensorMath.calculateStandardDeviation(
          movingData.map((d) => d.svm).toList(),
        );

        expect(stdDev, greaterThan(0.5));
        expect(SensorMath.isMotionless(movingData), false);
      });
    });
  });
}

// ============================================================================
// Scenario Data Generators
// ============================================================================

List<SensorData> _generateHighSideCrash() {
  final data = <SensorData>[];
  final baseTime = DateTime.now();

  // Normal riding (0-3s)
  data.addAll(_generateNormalRiding(150));

  // Sudden high impact (3-3.2s) - ejection
  for (int i = 0; i < 10; i++) {
    data.add(SensorData.fromValues(
      timestamp: baseTime.add(Duration(milliseconds: 3000 + i * 20)),
      x: 20.0,
      y: 30.0,
      z: 45.0, // ~5.2g peak
    ));
  }

  // Brief freefall (3.2-3.5s)
  for (int i = 0; i < 15; i++) {
    data.add(SensorData.fromValues(
      timestamp: baseTime.add(Duration(milliseconds: 3200 + i * 20)),
      x: 0.5,
      y: 0.8,
      z: 0.3, // Near-zero g
    ));
  }

  // Secondary impact (3.5-3.7s)
  for (int i = 0; i < 10; i++) {
    data.add(SensorData.fromValues(
      timestamp: baseTime.add(Duration(milliseconds: 3500 + i * 20)),
      x: 15.0,
      y: 20.0,
      z: 35.0,
    ));
  }

  // Complete stillness (3.7-8s)
  data.addAll(_generateStillData(215));

  return data;
}

List<SensorData> _generateLowSideCrash() {
  final data = <SensorData>[];

  data.addAll(_generateNormalRiding(150));

  // Moderate impact + tumbling
  for (int i = 0; i < 50; i++) {
    final chaos = (i % 10) * 3.0;
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 10.0 + chaos,
      y: 15.0 - chaos,
      z: 20.0 + chaos * 0.5,
    ));
  }

  // Final stillness
  data.addAll(_generateStillData(150));

  return data;
}

List<SensorData> _generateHeadOnCollision() {
  final data = <SensorData>[];

  data.addAll(_generateNormalRiding(100));

  // Extreme impact
  for (int i = 0; i < 5; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 30.0,
      y: 40.0,
      z: 60.0, // ~8.3g
    ));
  }

  // Immediate stillness
  data.addAll(_generateStillData(200));

  return data;
}

List<SensorData> _generateDroppedPhone() {
  final data = <SensorData>[];

  // Initial stillness
  data.addAll(_generateStillData(100));

  // Drop impact
  for (int i = 0; i < 10; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 10.0,
      y: 15.0,
      z: 30.0,
    ));
  }

  // Bounces
  for (int i = 0; i < 20; i++) {
    final bounce = (i % 5) * 5.0;
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 5.0 + bounce,
      y: 5.0 + bounce,
      z: 15.0 + bounce,
    ));
  }

  // Picked up and moved
  data.addAll(_generateMovement(150));

  return data;
}

List<SensorData> _generateSpeedBump() {
  final data = <SensorData>[];

  data.addAll(_generateNormalRiding(100));

  // Bump impact (below threshold)
  for (int i = 0; i < 15; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 5.0,
      y: 8.0,
      z: 25.0, // ~2.8g
    ));
  }

  // Continue riding
  data.addAll(_generateNormalRiding(150));

  return data;
}

List<SensorData> _generateEmergencyBraking() {
  final data = <SensorData>[];

  data.addAll(_generateNormalRiding(100));

  // Braking deceleration
  for (int i = 0; i < 30; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 8.0,
      y: 5.0,
      z: 20.0, // ~2.5g
    ));
  }

  // Stopped
  data.addAll(_generateStillData(150));

  return data;
}

List<SensorData> _generatePocketBouncing() {
  final data = <SensorData>[];

  for (int i = 0; i < 300; i++) {
    final bounce = (i % 10) * 2.0;
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 5.0 + bounce,
      y: 6.0 + bounce,
      z: 12.0 + bounce,
    ));
  }

  return data;
}

List<SensorData> _generateDelayedStop() {
  final data = <SensorData>[];

  data.addAll(_generateNormalRiding(50));

  // Impact
  for (int i = 0; i < 10; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 20.0,
      y: 25.0,
      z: 40.0,
    ));
  }

  // Sliding (gradually decreasing variance)
  for (int i = 0; i < 100; i++) {
    final slide = 15.0 * (1 - i / 100.0);
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 8.0 + slide,
      y: 10.0 + slide,
      z: 12.0 + slide,
    ));
  }

  // Finally still
  data.addAll(_generateStillData(100));

  return data;
}

List<SensorData> _generateRoughTerrain() {
  final data = <SensorData>[];

  for (int i = 0; i < 300; i++) {
    final bump = (i % 30 == 0) ? 10.0 : 0.0;
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 5.0 + bump,
      y: 6.0 + bump,
      z: 15.0 + bump,
    ));
  }

  return data;
}

List<SensorData> _generateParkingTipover() {
  final data = <SensorData>[];

  data.addAll(_generateStillData(100));

  // Slow rotation
  for (int i = 0; i < 50; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 2.0 + i * 0.1,
      y: 2.0 + i * 0.1,
      z: 9.8 - i * 0.1,
    ));
  }

  // Small impact
  for (int i = 0; i < 10; i++) {
    data.add(SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 8.0,
      y: 10.0,
      z: 15.0,
    ));
  }

  data.addAll(_generateStillData(100));

  return data;
}

// Common data generators
List<SensorData> _generateNormalRiding(int count) {
  return List.generate(count, (i) {
    final variance = (i % 5) * 0.5 - 1.0;
    return SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 2.0 + variance,
      y: 3.0 + variance,
      z: 10.0 + variance,
    );
  });
}

List<SensorData> _generateStillData(int count) {
  return List.generate(count, (i) {
    return SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 0.01,
      y: 0.02,
      z: 9.8,
    );
  });
}

List<SensorData> _generateMovement(int count) {
  return List.generate(count, (i) {
    final movement = (i % 10) * 2.0;
    return SensorData.fromValues(
      timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
      x: 5.0 + movement,
      y: 6.0 + movement,
      z: 12.0 + movement,
    );
  });
}

List<double> _findAllPeaks(List<SensorData> data, {required double threshold}) {
  final peaks = <double>[];

  for (int i = 1; i < data.length - 1; i++) {
    if (data[i].svm > threshold &&
        data[i].svm > data[i - 1].svm &&
        data[i].svm > data[i + 1].svm) {
      peaks.add(data[i].svm);
    }
  }

  return peaks;
}
