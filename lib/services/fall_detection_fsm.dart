import 'dart:async';
import '../models/fsm_state.dart';
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Finite State Machine for fall detection logic.
///
/// Manages transitions between states based on sensor data analysis:
/// 1. Recording: Monitor for high-G impact
/// 2. Evaluating Stop: Check if device is motionless after impact
/// 3. Trigger Upload: Send data to server for analysis
/// 4. User Feedback: Display countdown for user to cancel
class FallDetectionFSM {
  /// Current state of the FSM
  FallDetectionState _currentState = FallDetectionState.recording;

  /// Sensor service for data collection
  final SensorService sensorService;

  /// Timer for impact window (time allowed for stop after impact)
  Timer? _impactWindowTimer;

  /// Timer for user feedback countdown
  Timer? _userFeedbackTimer;

  /// Flag indicating if a potential crash has been detected
  bool _possibleCrash = false;

  /// Timestamp of when impact was detected
  DateTime? _impactTimestamp;

  /// Maximum SVM value during impact
  double _peakImpactValue = 0.0;

  /// Callback for state changes
  final List<void Function(StateTransitionEvent)> _stateChangeListeners = [];

  /// Callback for when user needs to confirm wellbeing
  void Function(int secondsLeft)? onUserFeedbackRequired;

  /// Callback for when emergency protocol should activate
  void Function()? onEmergencyActivated;

  /// Callback for when fall detection is canceled (user confirmed OK)
  void Function()? onFallDetectionCanceled;

  /// Callback for when data upload fails
  void Function(String error)? onUploadError;

  /// History of state transitions (for debugging)
  final List<StateTransitionEvent> _transitionHistory = [];

  /// Maximum history size to prevent memory issues
  static const int _maxHistorySize = 50;

  FallDetectionFSM({
    required this.sensorService,
  }) {
    _initializeSensorCallbacks();
  }

  /// Initializes callbacks for sensor service events
  void _initializeSensorCallbacks() {
    // Listen for impact detection
    sensorService.onImpactDetected = _onImpactDetected;

    // Listen for motionless state
    sensorService.onMotionlessDetected = _onMotionlessDetected;
  }

  /// Gets the current state
  FallDetectionState get currentState => _currentState;

  /// Checks if FSM is in a fall-detected state
  bool get isFallDetected => _currentState.isFallDetected;

  /// Gets the transition history
  List<StateTransitionEvent> get transitionHistory =>
      List.unmodifiable(_transitionHistory);

  /// Adds a state change listener
  void addStateChangeListener(void Function(StateTransitionEvent) listener) {
    _stateChangeListeners.add(listener);
  }

  /// Removes a state change listener
  void removeStateChangeListener(void Function(StateTransitionEvent) listener) {
    _stateChangeListeners.remove(listener);
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

    // Update state
    final oldState = _currentState;
    _currentState = newState;

    // Record transition
    _transitionHistory.add(event);
    if (_transitionHistory.length > _maxHistorySize) {
      _transitionHistory.removeAt(0);
    }

    // Notify listeners
    for (final listener in _stateChangeListeners) {
      listener(event);
    }

    // Handle state entry actions
    _onStateEntered(newState, oldState);

    // Log transition
    if (AppConfig.debugMode) {
      print('FSM: $event');
    }
  }

  /// Handles actions when entering a new state
  void _onStateEntered(FallDetectionState newState, FallDetectionState oldState) {
    switch (newState) {
      case FallDetectionState.recording:
        _onEnterRecording();
        break;
      case FallDetectionState.evaluatingStop:
        _onEnterEvaluatingStop();
        break;
      case FallDetectionState.triggerUpload:
        _onEnterTriggerUpload();
        break;
      case FallDetectionState.userFeedback:
        _onEnterUserFeedback();
        break;
    }
  }

  // ==========================================================================
  // State: Recording
  // ==========================================================================

  void _onEnterRecording() {
    // Reset flags
    _possibleCrash = false;
    _impactTimestamp = null;
    _peakImpactValue = 0.0;

    // Cancel any timers
    _impactWindowTimer?.cancel();
    _impactWindowTimer = null;
  }

  void _onImpactDetected(double svm) {
    if (_currentState != FallDetectionState.recording) return;

    // Record impact details
    _possibleCrash = true;
    _impactTimestamp = DateTime.now();
    _peakImpactValue = svm > _peakImpactValue ? svm : _peakImpactValue;

    // Start impact window timer
    _impactWindowTimer?.cancel();
    _impactWindowTimer = Timer(
      Duration(seconds: AppConfig.impactWindowSeconds),
      _onImpactWindowExpired,
    );

    // Transition to evaluating stop
    _transitionTo(
      FallDetectionState.evaluatingStop,
      reason: 'High-G impact detected',
      metadata: {
        'svm': svm,
        'threshold': sensorService.impactThreshold,
      },
    );
  }

  void _onImpactWindowExpired() {
    // If we're still evaluating and the window expired without detecting a stop,
    // this was likely not a crash (e.g., just a bump in the road)
    if (_currentState == FallDetectionState.evaluatingStop) {
      _transitionTo(
        FallDetectionState.recording,
        reason: 'Impact window expired without stop detected',
      );
    }
  }

  // ==========================================================================
  // State: Evaluating Stop
  // ==========================================================================

  void _onEnterEvaluatingStop() {
    // Already handled by impact detection
    // Continue monitoring for motionless state
  }

  void _onMotionlessDetected() {
    if (_currentState != FallDetectionState.evaluatingStop) {
      // Ignore motionless detection in other states
      // (e.g., stopped at traffic light without prior impact)
      return;
    }

    if (!_possibleCrash) {
      // Motionless without prior impact = traffic light, ignore
      _transitionTo(
        FallDetectionState.recording,
        reason: 'Motionless detected but no prior impact (traffic light)',
      );
      return;
    }

    // Motionless after impact = potential crash!
    _transitionTo(
      FallDetectionState.triggerUpload,
      reason: 'Motionless state detected after impact',
      metadata: {
        'timeSinceImpact': _impactTimestamp != null
            ? DateTime.now().difference(_impactTimestamp!).inSeconds
            : 0,
        'peakSvm': _peakImpactValue,
      },
    );
  }

  // ==========================================================================
  // State: Trigger Upload
  // ==========================================================================

  void _onEnterTriggerUpload() {
    // Freeze buffer and upload to server
    _uploadDataToServer();
  }

  Future<void> _uploadDataToServer() async {
    try {
      // Get buffered data
      final bufferData = sensorService.getBufferSnapshot();

      if (bufferData.isEmpty) {
        throw Exception('No sensor data in buffer');
      }

      // Convert to CSV format for API compatibility
      final csvData = _convertBufferToCsv(bufferData);

      // Upload to server
      final response = await ApiService.sendAccelerometerData(csvData);

      if (response.statusCode == 200) {
        // Parse response
        final isFall = _parseServerResponse(response.body);

        if (isFall) {
          // Server confirmed fall - show user feedback
          _transitionTo(
            FallDetectionState.userFeedback,
            reason: 'Server confirmed fall detection',
          );
        } else {
          // False positive - resume recording
          _transitionTo(
            FallDetectionState.recording,
            reason: 'Server classified as false positive',
          );
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        print('Error uploading data: $e');
      }

      // Notify error callback
      onUploadError?.call(e.toString());

      // For safety, assume it's a fall if upload fails
      _transitionTo(
        FallDetectionState.userFeedback,
        reason: 'Upload failed, assuming fall for safety',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Converts sensor buffer to CSV format
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

  /// Parses server response to determine if fall was detected
  bool _parseServerResponse(String responseBody) {
    // TODO: Implement proper JSON parsing when backend is ready
    // For now, assume any response means fall detected
    return true;
  }

  // ==========================================================================
  // State: User Feedback
  // ==========================================================================

  void _onEnterUserFeedback() {
    // Start countdown timer
    int secondsLeft = AppConfig.fallDetectionCountdown;

    _userFeedbackTimer?.cancel();
    _userFeedbackTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        secondsLeft--;

        // Notify UI to update countdown
        onUserFeedbackRequired?.call(secondsLeft);

        if (secondsLeft <= 0) {
          timer.cancel();
          _onUserFeedbackTimeout();
        }
      },
    );

    // Initial notification
    onUserFeedbackRequired?.call(secondsLeft);
  }

  void _onUserFeedbackTimeout() {
    // User did not respond - activate emergency protocol
    onEmergencyActivated?.call();

    // Remain in userFeedback state until manually reset
    // (Emergency services may be contacted, etc.)
  }

  /// Called when user confirms they are okay
  void confirmWellbeing() {
    if (_currentState == FallDetectionState.userFeedback) {
      _userFeedbackTimer?.cancel();
      _userFeedbackTimer = null;

      onFallDetectionCanceled?.call();

      _transitionTo(
        FallDetectionState.recording,
        reason: 'User confirmed wellbeing',
      );
    }
  }

  /// Manually resets the FSM to recording state
  void reset() {
    _userFeedbackTimer?.cancel();
    _impactWindowTimer?.cancel();

    _transitionTo(
      FallDetectionState.recording,
      reason: 'Manual reset',
    );
  }

  /// Disposes of resources
  void dispose() {
    _impactWindowTimer?.cancel();
    _userFeedbackTimer?.cancel();
    _stateChangeListeners.clear();
  }
}
