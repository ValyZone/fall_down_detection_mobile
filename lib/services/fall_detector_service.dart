import 'dart:async';
import 'dart:convert';
import '../models/fsm_state.dart';
import '../models/state_transition_event.dart';
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';
import '../services/api_service.dart';
import '../config.dart';

class FallDetectorService {
  FallDetectionState _currentState = FallDetectionState.monitoring;
  final SensorService sensorService;
  Timer? _impactWindowTimer;
  Timer? _postImpactTimer;
  bool _possibleCrash = false;
  bool _stationarityProcessed = false;
  DateTime? _impactTimestamp;
  double _peakImpactValue = 0.0;

  void Function(StateTransitionEvent)? onStateChanged;
  void Function(bool isFall, Map<String, dynamic> analysis)? onCrashAnalyzed;
  void Function(String error)? onUploadError;
  final List<Map<String, dynamic>> _crashLog = [];

  FallDetectorService({
    required this.sensorService,
  }) {
    _initializeSensorCallbacks();
  }

  void _initializeSensorCallbacks() {
    sensorService.onImpactDetected = _onImpactDetected;
    sensorService.onMotionlessDetected = _onStationarityDetected;
  }

  FallDetectionState get currentState => _currentState;
  List<Map<String, dynamic>> get crashLog => List.unmodifiable(_crashLog);

  Future<void> start() async {
    await sensorService.start();
    _transitionTo(
      FallDetectionState.monitoring,
      reason: 'Service started',
    );
  }

  void stop() {
    sensorService.stop();
    _impactWindowTimer?.cancel();
    _postImpactTimer?.cancel();
  }

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
    onStateChanged?.call(event);
    _onStateEntered(newState);

    if (AppConfig.debugMode) {
      print('FSM: ${event.fromState.name} → ${event.toState.name} ($reason)');
    }
  }

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

  void _onEnterMonitoring() {
    _possibleCrash = false;
    _stationarityProcessed = false;
    _impactTimestamp = null;
    _peakImpactValue = 0.0;
    _impactWindowTimer?.cancel();
    _impactWindowTimer = null;
    _postImpactTimer?.cancel();
    _postImpactTimer = null;
  }

  void _onImpactDetected(double svm) {
    if (_currentState != FallDetectionState.monitoring) return;

    _possibleCrash = true;
    _impactTimestamp = DateTime.now();
    _peakImpactValue = svm;
    _impactWindowTimer?.cancel();
    _impactWindowTimer = Timer(
      Duration(seconds: AppConfig.impactWindowSeconds),
      _onImpactWindowExpired,
    );

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
    if (_currentState == FallDetectionState.stationarityCheck) {
      _transitionTo(
        FallDetectionState.monitoring,
        reason: '10s impact window expired without stationarity',
      );
    }
  }

  void _onPostImpactCollectionComplete() {
    if (_currentState == FallDetectionState.stationarityCheck) {
      final timeSinceImpact = _impactTimestamp != null
          ? DateTime.now().difference(_impactTimestamp!).inSeconds
          : 0;

      _transitionTo(
        FallDetectionState.upload,
        reason: 'Post-impact data collection complete (5s)',
        metadata: {
          'timeSinceImpact': timeSinceImpact,
          'peakSvm': _peakImpactValue,
          'postImpactSeconds': AppConfig.postImpactCollectionSeconds,
        },
      );
    }
  }

  void _onEnterStationarityCheck() {
    _stationarityProcessed = false;
  }

  void _onStationarityDetected() {
    if (_currentState != FallDetectionState.stationarityCheck) {
      return;
    }

    if (_stationarityProcessed) {
      return;
    }

    if (!_possibleCrash) {
      _transitionTo(
        FallDetectionState.monitoring,
        reason: 'Stationarity without impact (traffic light)',
      );
      return;
    }

    _stationarityProcessed = true;
    final timeSinceImpact = _impactTimestamp != null
        ? DateTime.now().difference(_impactTimestamp!).inSeconds
        : 0;

    _impactWindowTimer?.cancel();
    _impactWindowTimer = null;
    _postImpactTimer?.cancel();
    _postImpactTimer = Timer(
      Duration(seconds: AppConfig.postImpactCollectionSeconds),
      _onPostImpactCollectionComplete,
    );

    if (AppConfig.debugMode) {
      print('Stationarity detected at ${timeSinceImpact}s after impact. Collecting 5s post-mortem data...');
    }
  }

  void _onEnterUpload() {
    _uploadDataToServer();
  }

  Future<void> _uploadDataToServer() async {
    try {
      final bufferData = sensorService.getBufferSnapshot();
      final csvData = _convertBufferToCsv(bufferData);
      final response = await ApiService.sendAccelerometerData(csvData);

      if (response.statusCode == 200) {
        final analysis = _parseServerResponse(response.body);
        final isFall = analysis['fallDetected'] as bool;

        _logCrashEvent(
          isFall: isFall,
          analysis: analysis,
          bufferSize: bufferData.length,
        );

        onCrashAnalyzed?.call(isFall, analysis);

        _transitionTo(
          FallDetectionState.monitoring,
          reason: isFall ? 'Server confirmed fall' : 'No fall detected',
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

      _logCrashEvent(
        isFall: null,
        analysis: {'error': e.toString()},
        bufferSize: sensorService.bufferSize,
      );

      _transitionTo(
        FallDetectionState.monitoring,
        reason: 'Upload failed, resuming monitoring',
        metadata: {'error': e.toString()},
      );
    }
  }

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

  Map<String, dynamic> _parseServerResponse(String responseBody) {
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

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
      'timeSinceImpact': DateTime.now().difference(_impactTimestamp!).inSeconds,
      'bufferSize': bufferSize,
      'analysis': analysis,
    };

    _crashLog.add(event);
  }

  void reset() {
    _impactWindowTimer?.cancel();
    _postImpactTimer?.cancel();
    _transitionTo(
      FallDetectionState.monitoring,
      reason: 'Manual reset',
    );
  }

  void dispose() {
    _impactWindowTimer?.cancel();
    _postImpactTimer?.cancel();
    sensorService.dispose();
  }
}
