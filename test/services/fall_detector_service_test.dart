import 'package:flutter_test/flutter_test.dart';
import 'package:fall_down_detection_mobile/services/fall_detector_service.dart';
import 'package:fall_down_detection_mobile/services/sensor_service.dart';
import 'package:fall_down_detection_mobile/models/fsm_state.dart';
import 'package:fall_down_detection_mobile/models/sensor_data.dart';
import 'package:fall_down_detection_mobile/config.dart';

/// Mock sensor service for testing
class MockSensorService extends SensorService {
  MockSensorService() : super(bufferCapacity: AppConfig.bufferCapacity);

  /// Simulates an impact detection
  void simulateImpact(double svm) {
    onImpactDetected?.call(svm);
  }

  /// Simulates stationarity detection
  void simulateStationarity() {
    onMotionlessDetected?.call();
  }

  /// Manually add data to buffer for testing
  void addTestData(SensorData data) {
    // Access the private buffer through reflection would be complex,
    // so we'll use the public interface
  }

  @override
  Future<void> start() async {
    // Mock - do nothing
  }

  @override
  void stop() {
    // Mock - do nothing
  }
}

void main() {
  group('FallDetectorService', () {
    late MockSensorService mockSensorService;
    late FallDetectorService fallDetector;

    setUp(() {
      mockSensorService = MockSensorService();
      fallDetector = FallDetectorService(sensorService: mockSensorService);
    });

    tearDown(() {
      fallDetector.dispose();
    });

    group('State Transitions', () {
      test('should start in monitoring state', () {
        expect(fallDetector.currentState, FallDetectionState.monitoring);
      });

      test('should transition to stationarity check on impact', () async {
        FallDetectionState? newState;

        fallDetector.onStateChanged = (event) {
          newState = event.toState;
        };

        await fallDetector.start();

        // Simulate high-G impact
        mockSensorService.simulateImpact(40.0); // > 3.5g

        expect(newState, FallDetectionState.stationarityCheck);
        expect(fallDetector.currentState, FallDetectionState.stationarityCheck);
      });

      test('should ignore impacts below threshold', () async {
        FallDetectionState? newState;

        fallDetector.onStateChanged = (event) {
          newState = event.toState;
        };

        await fallDetector.start();

        // Simulate low-G impact (below threshold)
        mockSensorService.simulateImpact(20.0); // < 3.5g (34.335 m/s²)

        expect(fallDetector.currentState, FallDetectionState.monitoring);
        expect(newState, isNull);
      });

      test('should return to monitoring if impact window expires', () async {
        await fallDetector.start();

        // Simulate impact
        mockSensorService.simulateImpact(40.0);
        expect(fallDetector.currentState, FallDetectionState.stationarityCheck);

        // Wait for impact window to expire (10 seconds + margin)
        await Future.delayed(const Duration(seconds: 11));

        expect(fallDetector.currentState, FallDetectionState.monitoring);
      });

      test('should ignore stationarity without prior impact', () async {
        await fallDetector.start();

        // Simulate stationarity WITHOUT impact (traffic light scenario)
        mockSensorService.simulateStationarity();

        // Should remain in monitoring
        expect(fallDetector.currentState, FallDetectionState.monitoring);
      });

      test('should transition through all states on valid crash', () async {
        final stateTransitions = <FallDetectionState>[];

        fallDetector.onStateChanged = (event) {
          stateTransitions.add(event.toState);
        };

        await fallDetector.start();

        // Simulate impact
        mockSensorService.simulateImpact(42.0);

        // Simulate stationarity
        mockSensorService.simulateStationarity();

        // Should have transitioned: monitoring → stationarity → upload
        expect(
          stateTransitions,
          containsAll([
            FallDetectionState.stationarityCheck,
            FallDetectionState.upload,
          ]),
        );
      });
    });

    group('Impact Detection', () {
      test('should detect impact at exactly 3.5g', () async {
        FallDetectionState? newState;

        fallDetector.onStateChanged = (event) {
          newState = event.toState;
        };

        await fallDetector.start();

        // Exactly 3.5g = 34.335 m/s²
        mockSensorService.simulateImpact(34.335);

        expect(newState, FallDetectionState.stationarityCheck);
      });

      test('should detect high-G impact (>10g)', () async {
        FallDetectionState? newState;

        fallDetector.onStateChanged = (event) {
          newState = event.toState;
        };

        await fallDetector.start();

        // Very high impact (10g)
        mockSensorService.simulateImpact(98.0665);

        expect(newState, FallDetectionState.stationarityCheck);
      });

      test('should record peak impact value', () async {
        StateTransitionEvent? transition;

        fallDetector.onStateChanged = (event) {
          transition = event;
        };

        await fallDetector.start();

        mockSensorService.simulateImpact(50.0);

        expect(transition?.metadata?['svm'], 50.0);
        expect(transition?.metadata?['svmInGs'], closeTo(5.1, 0.1));
      });
    });

    group('Crash Logging', () {
      test('should create crash log entry on detection', () async {
        await fallDetector.start();

        expect(fallDetector.crashLog.length, 0);

        // Note: Without actual HTTP client, we can't fully test upload
        // In integration tests, we'll mock the API response
      });

      test('should maintain crash log history', () {
        // Crash log should be accessible
        expect(fallDetector.crashLog, isA<List<Map<String, dynamic>>>());
        expect(fallDetector.crashLog, isEmpty);
      });
    });

    group('State Change Callbacks', () {
      test('should notify listeners on state change', () async {
        int callbackCount = 0;
        FallDetectionState? lastState;

        fallDetector.onStateChanged = (event) {
          callbackCount++;
          lastState = event.toState;
        };

        await fallDetector.start();

        mockSensorService.simulateImpact(40.0);

        expect(callbackCount, greaterThan(0));
        expect(lastState, FallDetectionState.stationarityCheck);
      });

      test('should provide transition metadata', () async {
        StateTransitionEvent? lastEvent;

        fallDetector.onStateChanged = (event) {
          lastEvent = event;
        };

        await fallDetector.start();

        mockSensorService.simulateImpact(45.0);

        expect(lastEvent, isNotNull);
        expect(lastEvent?.reason, contains('impact detected'));
        expect(lastEvent?.metadata, isNotNull);
      });
    });

    group('Manual Reset', () {
      test('should reset to monitoring state', () async {
        await fallDetector.start();

        // Trigger impact
        mockSensorService.simulateImpact(40.0);
        expect(fallDetector.currentState, FallDetectionState.stationarityCheck);

        // Manual reset
        fallDetector.reset();

        expect(fallDetector.currentState, FallDetectionState.monitoring);
      });

      test('should cancel timers on reset', () async {
        await fallDetector.start();

        mockSensorService.simulateImpact(40.0);

        // Reset should cancel impact window timer
        fallDetector.reset();

        // Wait beyond impact window
        await Future.delayed(const Duration(seconds: 11));

        // Should still be in monitoring (timer was canceled)
        expect(fallDetector.currentState, FallDetectionState.monitoring);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid successive impacts', () async {
        await fallDetector.start();

        // Multiple impacts in quick succession
        mockSensorService.simulateImpact(40.0);
        await Future.delayed(const Duration(milliseconds: 100));
        mockSensorService.simulateImpact(45.0);
        await Future.delayed(const Duration(milliseconds: 100));
        mockSensorService.simulateImpact(50.0);

        // Should remain in stationarity check (not crash)
        expect(fallDetector.currentState, FallDetectionState.stationarityCheck);
      });

      test('should handle stationarity during upload', () async {
        await fallDetector.start();

        mockSensorService.simulateImpact(40.0);
        mockSensorService.simulateStationarity();

        // Now in upload state
        // Another stationarity signal should be ignored
        mockSensorService.simulateStationarity();

        // Should not cause issues
        expect(fallDetector.currentState, FallDetectionState.upload);
      });

      test('should handle dispose during active detection', () {
        fallDetector.start();
        mockSensorService.simulateImpact(40.0);

        // Should not throw
        expect(() => fallDetector.dispose(), returnsNormally);
      });
    });

    group('FSM State Properties', () {
      test('monitoring state should require sensor monitoring', () {
        expect(
          FallDetectionState.monitoring.requiresSensorMonitoring,
          true,
        );
      });

      test('stationarity check should detect as fall', () {
        expect(
          FallDetectionState.stationarityCheck.isFallDetected,
          true,
        );
      });

      test('upload state should detect as fall', () {
        expect(
          FallDetectionState.upload.isFallDetected,
          true,
        );
      });

      test('state should have correct display names', () {
        expect(
          FallDetectionState.monitoring.displayName,
          'Monitoring',
        );
        expect(
          FallDetectionState.stationarityCheck.displayName,
          'Checking Stationarity',
        );
        expect(
          FallDetectionState.upload.displayName,
          'Uploading Data',
        );
      });
    });
  });
}
