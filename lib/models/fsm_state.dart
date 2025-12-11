/// Represents the states of the Fall Detection Finite State Machine.
///
/// The FSM transitions through these states based on sensor data analysis:
/// Monitoring → StationarityCheck → Upload → (back to Monitoring)
enum FallDetectionState {
  /// Normal operation: continuously recording sensor data to circular buffer.
  /// Monitoring for high-G impact events (SVM > 3.5g).
  monitoring,

  /// Impact detected: checking for stationarity within the impact window.
  /// Checking accelerometer std dev < 0.05 and gyroscope rotation < 0.1 rad/s.
  stationarityCheck,

  /// Crash confirmed: uploading buffered data to server for post-mortem analysis.
  /// Server validates impact and checks post-impact silence.
  upload,
}

/// Extension to provide human-readable descriptions of FSM states
extension FallDetectionStateExtension on FallDetectionState {
  /// Returns a human-readable name for the state
  String get displayName {
    switch (this) {
      case FallDetectionState.monitoring:
        return 'Monitoring';
      case FallDetectionState.stationarityCheck:
        return 'Checking Stationarity';
      case FallDetectionState.upload:
        return 'Uploading Data';
    }
  }

  /// Returns a detailed description of what happens in this state
  String get description {
    switch (this) {
      case FallDetectionState.monitoring:
        return 'Continuously recording sensor data, watching for impact';
      case FallDetectionState.stationarityCheck:
        return 'Impact detected, checking for stationarity';
      case FallDetectionState.upload:
        return 'Uploading data to server for post-mortem analysis';
    }
  }

  /// Returns true if this state requires active sensor monitoring
  bool get requiresSensorMonitoring {
    return this == FallDetectionState.monitoring ||
        this == FallDetectionState.stationarityCheck;
  }

  /// Returns true if this state represents a potential or confirmed fall
  bool get isFallDetected {
    return this == FallDetectionState.stationarityCheck ||
        this == FallDetectionState.upload;
  }
}

/// Represents a state transition event with timestamp and reason
class StateTransitionEvent {
  /// The previous state
  final FallDetectionState fromState;

  /// The new state
  final FallDetectionState toState;

  /// When the transition occurred
  final DateTime timestamp;

  /// Reason for the transition (for logging/debugging)
  final String reason;

  /// Additional metadata about the transition
  final Map<String, dynamic>? metadata;

  const StateTransitionEvent({
    required this.fromState,
    required this.toState,
    required this.timestamp,
    required this.reason,
    this.metadata,
  });

  @override
  String toString() {
    return 'StateTransition('
        '${fromState.displayName} → ${toState.displayName}, '
        'reason: $reason, '
        'time: ${timestamp.toIso8601String()}'
        ')';
  }

  /// Converts to JSON for logging
  Map<String, dynamic> toJson() {
    return {
      'fromState': fromState.name,
      'toState': toState.name,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
