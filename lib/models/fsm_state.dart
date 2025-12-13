/// Fall Detection FSM State Definitions
enum FallDetectionState {
  /// State 1: Continuous monitoring for high-G impacts
  monitoring,

  /// State 2: Impact detected, waiting for device to become stationary
  stationarityCheck,

  /// State 3: Upload buffer to server for analysis
  upload,
}

/// Extension methods for FallDetectionState
extension FallDetectionStateExtension on FallDetectionState {
  /// Human-readable name
  String get name {
    switch (this) {
      case FallDetectionState.monitoring:
        return 'Monitoring';
      case FallDetectionState.stationarityCheck:
        return 'Stationarity Check';
      case FallDetectionState.upload:
        return 'Upload';
    }
  }

  /// State description
  String get description {
    switch (this) {
      case FallDetectionState.monitoring:
        return 'Watching for high-G impacts';
      case FallDetectionState.stationarityCheck:
        return 'Waiting for device to stop moving';
      case FallDetectionState.upload:
        return 'Sending data to server';
    }
  }
}
