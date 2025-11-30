import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../utils/mock_data_generator.dart';
import '../widgets/test_buttons.dart';
import '../widgets/recording_view.dart';
import '../widgets/fall_detected_view.dart';
import '../widgets/help_called_view.dart';
import '../widgets/connection_tester.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables
  bool _fallDetected = false;
  bool _helpCalled = false;
  bool _isRecording = false;
  int _secondsLeft = AppConfig.fallDetectionCountdown;
  double _elapsedTime = 0.0;
  double _recordingTime = 0.0;

  // Data storage
  final List<String> _accelerometerData = [];
  final List<String> _realTimeData = [];

  // Timers and subscriptions
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _accelerometerSubscription?.cancel();
  }

  // ===========================================================================
  // Mock Test Functions
  // ===========================================================================

  void _startMockTest(String testType) {
    setState(() {
      _fallDetected = true;
      _secondsLeft = AppConfig.fallDetectionCountdown;
      _accelerometerData.clear();
      _elapsedTime = 0.0;
    });

    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          _elapsedTime += 0.1;

          // Generate mock data based on test type
          final mockData = switch (testType) {
            'fall' => MockDataGenerator.generateFallData(_elapsedTime),
            'nofall' => MockDataGenerator.generateNoFallData(_elapsedTime),
            _ => MockDataGenerator.generateRandomData(_elapsedTime),
          };
          _accelerometerData.add(mockData);

          // Update countdown every second
          if ((_elapsedTime * 10).round() % 10 == 0) {
            _secondsLeft =
                AppConfig.fallDetectionCountdown - (_elapsedTime / 1.0).floor();
          }

          // Timer expired - call for help
          if (_elapsedTime >= AppConfig.fallDetectionCountdown.toDouble()) {
            timer.cancel();
            _callForHelp();
          }
        });
      },
    );
  }

  void _confirmWellbeing() {
    _cancelAllTimers();
    setState(() {
      _fallDetected = false;
      _helpCalled = false;
      _secondsLeft = AppConfig.fallDetectionCountdown;
      _accelerometerData.clear();
    });
  }

  void _resetApp() {
    _cancelAllTimers();
    setState(() {
      _fallDetected = false;
      _helpCalled = false;
      _secondsLeft = AppConfig.fallDetectionCountdown;
      _accelerometerData.clear();
    });
  }

  // ===========================================================================
  // Real-time Recording Functions
  // ===========================================================================

  void _startRealTimeRecording() {
    setState(() {
      _isRecording = true;
      _recordingTime = 0.0;
      _realTimeData.clear();
    });

    // Subscribe to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final csvRow = '${_recordingTime.toStringAsFixed(1)}\t'
          '${event.x.toStringAsFixed(2)}\t'
          '${event.y.toStringAsFixed(2)}\t'
          '${event.z.toStringAsFixed(2)}\t'
          '${sqrt(event.x * event.x + event.y * event.y + event.z * event.z).toStringAsFixed(2)}';
      _realTimeData.add(csvRow);
    });

    // Update timer
    _recordingTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          _recordingTime += 0.1;
        });

        // Send data every configured interval
        if (_recordingTime % AppConfig.realTimeUpdateInterval < 0.1 &&
            _realTimeData.isNotEmpty) {
          _sendRealTimeData();
        }
      },
    );
  }

  void _stopRealTimeRecording() {
    _accelerometerSubscription?.cancel();
    _recordingTimer?.cancel();

    setState(() {
      _isRecording = false;
    });

    // Send any remaining data
    if (_realTimeData.isNotEmpty) {
      _sendRealTimeData();
    }
  }

  // ===========================================================================
  // API Communication Functions
  // ===========================================================================

  Future<void> _sendRealTimeData() async {
    if (_realTimeData.isEmpty) return;

    List<String> dataToSend = _realTimeData;

    // Limit data to max points
    if (_realTimeData.length > AppConfig.maxDataPoints) {
      dataToSend = _realTimeData.sublist(
        _realTimeData.length - AppConfig.maxDataPoints,
      );
    }

    try {
      await ApiService.sendAccelerometerData(dataToSend);

      // Trim stored data
      if (_realTimeData.length > AppConfig.maxDataPoints) {
        setState(() {
          _realTimeData.removeRange(
            0,
            _realTimeData.length - AppConfig.maxDataPoints,
          );
        });
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        print('Error sending real-time data: $e');
      }
    }
  }

  Future<void> _callForHelp() async {
    setState(() {
      _helpCalled = true;
    });

    try {
      await ApiService.sendAccelerometerData(_accelerometerData);
      _accelerometerData.clear();
    } catch (e) {
      if (AppConfig.debugMode) {
        print('Error calling for help: $e');
      }
    }
  }

  // ===========================================================================
  // UI Build Method
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Detector'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Normal State - Show Test Buttons and Connection Tester
    if (!_fallDetected && !_isRecording) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const ConnectionTester(),
            const SizedBox(height: 20),
            TestButtons(
              onRandomTest: () => _startMockTest('random'),
              onFallTest: () => _startMockTest('fall'),
              onNoFallTest: () => _startMockTest('nofall'),
              onStartRecording: _startRealTimeRecording,
            ),
          ],
        ),
      );
    }

    // Recording State
    if (_isRecording) {
      return RecordingView(
        recordingTime: _recordingTime,
        dataPointsCount: _realTimeData.length,
        onStopRecording: _stopRealTimeRecording,
      );
    }

    // Fall Detected State
    if (_fallDetected && !_helpCalled) {
      return FallDetectedView(
        secondsLeft: _secondsLeft,
        onConfirmWellbeing: _confirmWellbeing,
      );
    }

    // Help Called State
    if (_helpCalled) {
      return HelpCalledView(
        onReset: _resetApp,
      );
    }

    // Fallback
    return const SizedBox.shrink();
  }
}
