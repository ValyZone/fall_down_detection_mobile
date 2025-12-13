import 'dart:async';
import 'dart:convert';
import '../models/fsm_state.dart';
import '../models/state_transition_event.dart';
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Simple 3-State Finite State Machine for Fall Detection
///
/// States:
/// 1. Monitoring: Circular buffer recording, watching for SVM > 3.5g
/// 2. StationarityCheck: Impact detected, checking if device stopped
/// 3. Upload: Stationary confirmed, send data to server
///
/// NO user feedback, NO rescue features - only detection and logging
class FallDetectorService {
  /// Current state of the FSM
  FallDetectionState _currentState = FallDetectionState.monitoring;

  /// Sensor service for data collection
  final SensorService sensorService;

  /// Timer for impact window (10 seconds to detect stationarity)
  Timer? _impactWindowTimer;

  /// Flag indicating if a potential crash has been detected
  bool _possibleCrash = false;

  /// Timestamp of when impact was detected
  DateTime? _impactTimestamp;

  /// Maximum SVM value during impact
  double _peakImpactValue = 0.0;

  /// Callback for state changes (for UI/logging)
  void Function(StateTransitionEvent)? onStateChanged;

  /// Callback for crash detection with server response
  void Function(bool isFall, Map<String, dynamic> analysis)? onCrashAnalyzed;

  /// Callback for upload errors
  void Function(String error)? onUploadError;

  /// Crash log history
  final List<Map<String, dynamic>> _crashLog = [];

  FallDetectorService({
    required this.sensorService,
  }) {
    _initializeSensorCallbacks();
  }

  /// Initializes callbacks for sensor service events
  void _initializeSensorCallbacks() {
    sensorService.onImpactDetected = _onImpactDetected;
    sensorService.onMotionlessDetected = _onStationarityDetected;
  }

  /// Gets the current state
  FallDetectionState get currentState => _currentState;

  /// Gets the crash log
  List<Map<String, dynamic>> get crashLog => List.unmodifiable(_crashLog);

  /// Starts the fall detector
  Future<void> start() async {
    await sensorService.start();
    _transitionTo(
      FallDetectionState.monitoring,
      reason: 'Service started',
    );
  }

  /// Stops the fall detector
  void stop() {
    sensorService.stop();
    _impactWindowTimer?.cancel();
  }

  /// Transitions to a new state
  void _transitionTo(
    FallDetectionState newState, {
    required String reason,
    Map<String, dynamic>? metadata,
  }) {
    if (_currentState == newState) return;

    final event = StateTransitionEvent(
      fromState: _currentState,
      toState: newState,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: metadata,
    );

    _currentState = newState;

    // Notify callback
    onStateChanged?.call(event);

    // Handle state entry
    _onStateEntered(newState);

    // Log transition
    if (AppConfig.debugMode) {
      print('FSM: ${event.fromState.name} → ${event.toState.name} ($reason)');
    }
  }

  /// Handles actions when entering a new state
  void _onStateEntered(FallDetectionState newState) {
    switch (newState) {
      case FallDetectionState.monitoring:
        _onEnterMonitoring();
        break;
      case FallDetectionState.stationarityCheck:
        _onEnterStationarityCheck();
        break;
      case FallDetectionState.upload:
        _onEnterUpload();
        break;
    }
  }

  // ==========================================================================
  // State 1: Monitoring
  // ==========================================================================

  void _onEnterMonitoring() {
    // Reset flags
    _possibleCrash = false;
    _impactTimestamp = null;
    _peakImpactValue = 0.0;

    // Cancel any timers
    _impactWindowTimer?.cancel();
    _impactWindowTimer = null;
  }

  void _onImpactDetected(double svm) {
    if (_currentState != FallDetectionState.monitoring) return;

    // Record impact details
    _possibleCrash = true;
    _impactTimestamp = DateTime.now();
    _peakImpactValue = svm;

    // Start 10-second impact window
    _impactWindowTimer?.cancel();
    _impactWindowTimer = Timer(
      Duration(seconds: AppConfig.impactWindowSeconds),
      _onImpactWindowExpired,
    );

    // Transition to stationarity check
    _transitionTo(
      FallDetectionState.stationarityCheck,
      reason: 'High-G impact detected (SVM: ${svm.toStringAsFixed(2)} m/s²)',
      metadata: {
        'svm': svm,
        'svmInGs': svm / 9.80665,
        'threshold': AppConfig.impactThreshold,
      },
    );
  }

  void _onImpactWindowExpired() {
    // Window expired without stationarity = false alarm
    if (_currentState == FallDetectionState.stationarityCheck) {
      _transitionTo(
        FallDetectionState.monitoring,
        reason: '10s impact window expired without stationarity',
      );
    }
  }

  // ==========================================================================
  // State 2: Stationarity Check
  // ==========================================================================

  void _onEnterStationarityCheck() {
    // Continue monitoring for stationarity
    // SensorService will call _onStationarityDetected when conditions met
  }

  void _onStationarityDetected() {
    if (_currentState != FallDetectionState.stationarityCheck) {
      // Ignore stationarity in other states (e.g., traffic light without impact)
      return;
    }

    if (!_possibleCrash) {
      // Stationary without prior impact = normal stop, ignore
      _transitionTo(
        FallDetectionState.monitoring,
        reason: 'Stationarity without impact (traffic light)',
      );
      return;
    }

    // Stationarity after impact = CRASH CANDIDATE!
    final timeSinceImpact = _impactTimestamp != null
        ? DateTime.now().difference(_impactTimestamp!).inSeconds
        : 0;

    _transitionTo(
      FallDetectionState.upload,
      reason: 'Stationarity confirmed after impact',
      metadata: {
        'timeSinceImpact': timeSinceImpact,
        'peakSvm': _peakImpactValue,
      },
    );
  }

  // ==========================================================================
  // State 3: Upload
  // ==========================================================================

  void _onEnterUpload() {
    // Freeze buffer and upload
    _uploadDataToServer();
  }

  Future<void> _uploadDataToServer() async {
    try {
      // Freeze the circular buffer
      final bufferData = sensorService.getBufferSnapshot();

      if (bufferData.isEmpty) {
        throw Exception('No sensor data in buffer');
      }

      // Convert to CSV format for server
      final csvData = _convertBufferToCsv(bufferData);

      // Send POST request to /fall-detection/receive-data (CSV endpoint)
      final response = await ApiService.sendAccelerometerData(csvData);

      if (response.statusCode == 200) {
        // Parse server response
        final analysis = _parseServerResponse(response.body);
        final isFall = analysis['isFall'] as bool? ?? false;

        // Log the crash event
        _logCrashEvent(
          isFall: isFall,
          analysis: analysis,
          bufferSize: bufferData.length,
        );

        // Notify callback
        onCrashAnalyzed?.call(isFall, analysis);

        // Return to monitoring
        _transitionTo(
          FallDetectionState.monitoring,
          reason: isFall ? 'Server confirmed fall' : 'Server rejected (false positive)',
          metadata: analysis,
        );
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        print('Upload error: $e');
      }

      onUploadError?.call(e.toString());

      // Log the failed upload
      _logCrashEvent(
        isFall: null, // Unknown due to upload failure
        analysis: {'error': e.toString()},
        bufferSize: sensorService.bufferSize,
      );

      // Return to monitoring
      _transitionTo(
        FallDetectionState.monitoring,
        reason: 'Upload failed, resuming monitoring',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Converts sensor buffer to CSV format for server
  List<String> _convertBufferToCsv(List<SensorData> buffer) {
    if (buffer.isEmpty) return [];

    final List<String> csvRows = [];
    final reference = buffer.first.timestamp;

    for (final data in buffer) {
      final timeInSeconds = data.timeInSeconds(reference);
      csvRows.add(data.toCsvRow(timeInSeconds));
    }

    return csvRows;
  }

  /// Parses server response
  Map<String, dynamic> _parseServerResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json;
    } catch (e) {
      // Fallback if server doesn't return JSON
      return {'isFall': false, 'error': 'Invalid server response'};
    }
  }

  /// Logs a crash event to the crash log
  void _logCrashEvent({
    required bool? isFall,
    required Map<String, dynamic> analysis,
    required int bufferSize,
  }) {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'peakSvm': _peakImpactValue,
      'peakGs': _peakImpactValue / 9.80665,
      'isFall': isFall,
      'timeSinceImpact': _impactTimestamp != null
          ? DateTime.now().difference(_impactTimestamp!).inSeconds
          : null,
      'bufferSize': bufferSize,
      'analysis': analysis,
    };

    _crashLog.add(event);

    if (AppConfig.debugMode) {
      print('Crash log entry: $event');
    }
  }

  /// Manually resets the FSM to monitoring state
  void reset() {
    _impactWindowTimer?.cancel();
    _transitionTo(
      FallDetectionState.monitoring,
      reason: 'Manual reset',
    );
  }

  /// Disposes of resources
  void dispose() {
    _impactWindowTimer?.cancel();
    sensorService.dispose();
  }
}
