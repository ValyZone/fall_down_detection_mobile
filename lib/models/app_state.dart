/// Represents the current state of the fall detection app
enum AppState {
  normal,
  recording,
  fallDetected,
  helpCalled,
}

/// Model for managing fall detection state
class FallDetectionState {
  final AppState state;
  final bool fallDetected;
  final bool helpCalled;
  final bool isRecording;
  final int secondsLeft;
  final double elapsedTime;
  final double recordingTime;
  final List<String> accelerometerData;
  final List<String> realTimeData;

  const FallDetectionState({
    this.state = AppState.normal,
    this.fallDetected = false,
    this.helpCalled = false,
    this.isRecording = false,
    this.secondsLeft = 3,
    this.elapsedTime = 0.0,
    this.recordingTime = 0.0,
    this.accelerometerData = const [],
    this.realTimeData = const [],
  });

  FallDetectionState copyWith({
    AppState? state,
    bool? fallDetected,
    bool? helpCalled,
    bool? isRecording,
    int? secondsLeft,
    double? elapsedTime,
    double? recordingTime,
    List<String>? accelerometerData,
    List<String>? realTimeData,
  }) {
    return FallDetectionState(
      state: state ?? this.state,
      fallDetected: fallDetected ?? this.fallDetected,
      helpCalled: helpCalled ?? this.helpCalled,
      isRecording: isRecording ?? this.isRecording,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      recordingTime: recordingTime ?? this.recordingTime,
      accelerometerData: accelerometerData ?? this.accelerometerData,
      realTimeData: realTimeData ?? this.realTimeData,
    );
  }
}
