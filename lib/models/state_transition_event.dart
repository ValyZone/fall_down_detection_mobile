import 'fsm_state.dart';

/// Event representing a state transition in the FSM
class StateTransitionEvent {
  /// The state we're transitioning from
  final FallDetectionState fromState;

  /// The state we're transitioning to
  final FallDetectionState toState;

  /// When the transition occurred
  final DateTime timestamp;

  /// Why the transition happened
  final String reason;

  /// Optional metadata about the transition
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
    final metaStr = metadata != null ? ' (${metadata.toString()})' : '';
    return '${fromState.name} -> ${toState.name}: $reason$metaStr';
  }
}
