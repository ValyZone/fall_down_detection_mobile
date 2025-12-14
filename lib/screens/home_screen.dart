import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/sensor_service.dart';
import '../services/fall_detector_service.dart';
import '../models/fsm_state.dart';
import '../models/state_transition_event.dart';
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
  late final SensorService _sensorService;
  late final FallDetectorService _fallDetectorService;
  FallDetectionState _currentFsmState = FallDetectionState.monitoring;

  bool _fallDetected = false;
  bool _helpCalled = false;
  bool _isRecording = false;
  int _secondsLeft = AppConfig.fallDetectionCountdown;
  double _elapsedTime = 0.0;
  double _recordingTime = 0.0;

  final List<String> _accelerometerData = [];
  final List<String> _logMessages = [];
  int _sampleCount = 0;

  Timer? _countdownTimer;
  Timer? _recordingTimerUI;

  @override
  void initState() {
    super.initState();
    _initializeFsmServices();
  }

  void _initializeFsmServices() {
    _sensorService = SensorService();
    _fallDetectorService = FallDetectorService(sensorService: _sensorService);

    _fallDetectorService.onStateChanged = _onFsmStateChanged;
    _fallDetectorService.onCrashAnalyzed = _onCrashAnalyzed;
    _fallDetectorService.onUploadError = _onUploadError;

    _sensorService.onDataReceived = _onSensorDataReceived;
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _fallDetectorService.dispose();
    super.dispose();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _recordingTimerUI?.cancel();
  }

  void _onFsmStateChanged(StateTransitionEvent event) {
    setState(() {
      _currentFsmState = event.toState;
    });

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    _addLog('[$timeStr] FSM: ${event.fromState.name} → ${event.toState.name}');
    _addLog('         Reason: ${event.reason}');

    if (event.toState == FallDetectionState.stationarityCheck && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Impact detected - Checking for stationarity...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (event.toState == FallDetectionState.upload && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📤 Device stopped - Uploading crash data...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onCrashAnalyzed(bool isFall, Map<String, dynamic> analysis) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    if (isFall) {
      _addLog('[$timeStr] 🚨 FALL DETECTED - Server confirmed crash!');
      _addLog('         Analysis: ${analysis['message'] ?? 'Positive detection'}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 FALL DETECTED - Emergency response activated!'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _showFallAlert();
    } else {
      _addLog('[$timeStr] ✅ Server analysis: No fall detected (false alarm)');
      _addLog('         Analysis: ${analysis['message'] ?? 'Negative detection'}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ False alarm - No fall detected'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onUploadError(String error) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    _addLog('[$timeStr] ❌ Upload error: $error');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: $error'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onSensorDataReceived(data) {
    setState(() {
      _sampleCount++;
    });
  }

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

          final mockData = switch (testType) {
            'fall' => MockDataGenerator.generateFallData(_elapsedTime),
            'nofall' => MockDataGenerator.generateNoFallData(_elapsedTime),
            _ => MockDataGenerator.generateRandomData(_elapsedTime),
          };
          _accelerometerData.add(mockData);
          _secondsLeft = AppConfig.fallDetectionCountdown - _elapsedTime.floor();

          if (_elapsedTime >= AppConfig.fallDetectionCountdown.toDouble()) {
            timer.cancel();
            _callForHelp();
          }
        });
      },
    );
  }

  Future<void> _runPositiveAlarmTest() async {
    try {
      final mockData = await ApiService.fetchMockData('positive');
      final response = await ApiService.sendAccelerometerData(mockData);

      if (response.statusCode == 200) {
        final analysis = json.decode(response.body) as Map<String, dynamic>;
        final isFall = analysis['fallDetected'] as bool? ?? false;

        _onCrashAnalyzed(isFall, analysis);
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _runFalsePositiveAlarmTest() async {
    try {
      final mockData = await ApiService.fetchMockData('false-positive');
      final response = await ApiService.sendAccelerometerData(mockData);

      if (response.statusCode == 200) {
        final analysis = json.decode(response.body) as Map<String, dynamic>;
        final isFall = analysis['fallDetected'] as bool? ?? false;

        _onCrashAnalyzed(isFall, analysis);
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  void _startRealTimeRecording() {
    setState(() {
      _isRecording = true;
      _recordingTime = 0.0;
      _logMessages.clear();
      _sampleCount = 0;
    });

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('[$timeStr] 🔴 FSM started - Monitoring for crashes...');
    _addLog('         Mode: Impact-triggered upload only');
    _addLog('         Tracking: Accelerometer + Gyroscope + Circular Buffer');
    _addLog('         FSM State: ${_currentFsmState.name}');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    _fallDetectorService.start();
    _recordingTimerUI = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          _recordingTime += 0.1;
        });
      },
    );
  }

  void _stopRealTimeRecording() {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('[$timeStr] ⏹️ FSM stopped');
    _addLog('         Final sample count: $_sampleCount');
    _addLog('         Buffer size: ${_sensorService.bufferSize}');
    _addLog('         FSM State: ${_currentFsmState.name}');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    _fallDetectorService.stop();
    _recordingTimerUI?.cancel();

    setState(() {
      _isRecording = false;
    });
  }

  void _showFallAlert() {
    setState(() {
      _fallDetected = true;
      _isRecording = false;
      _secondsLeft = AppConfig.fallDetectionCountdown;
      _elapsedTime = 0.0;
    });

    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          _elapsedTime += 0.1;
          _secondsLeft = AppConfig.fallDetectionCountdown - _elapsedTime.floor();

          if (_elapsedTime >= AppConfig.fallDetectionCountdown.toDouble()) {
            timer.cancel();
            _helpNeeded();
          }
        });
      },
    );
  }

  Future<void> _confirmUserFine() async {
    _cancelAllTimers();
    
    setState(() {
      _fallDetected = false;
      _helpCalled = false;
    });

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addLog('[$timeStr] ✅ User confirmed: I\'m OK');
      _addLog('[$timeStr] Sending confirmation to server...');
      
      final response = await ApiService.sendUserFineConfirmation();
      
      if (response.statusCode == 200) {
        _addLog('[$timeStr] ✅ Confirmation sent successfully');
        final responseData = json.decode(response.body);
        if (responseData['message'] != null) {
          _addLog('         ${responseData['message']}');
        }
      } else {
        _addLog('[$timeStr] ⚠️ Failed to send confirmation (Status: ${response.statusCode})');
      }
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _addLog('[$timeStr] ❌ Error sending confirmation: $e');
    }
  }

  void _helpNeeded() {
    setState(() {
      _helpCalled = true;
    });
    
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('[$timeStr] 🚨 NO RESPONSE - Emergency services may be contacted');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add(message);
      if (_logMessages.length > 100) {
        _logMessages.removeAt(0);
      }
    });
    print(message);
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
    if (!_fallDetected && !_isRecording) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const ConnectionTester(),
            const SizedBox(height: 20),
            TestButtons(
              onRandomTest: () => _startMockTest('random'),
              onFallTest: _runPositiveAlarmTest,
              onNoFallTest: _runFalsePositiveAlarmTest,
              onStartRecording: _startRealTimeRecording,
            ),
          ],
        ),
      );
    }

    if (_isRecording) {
      return RecordingView(
        recordingTime: _recordingTime,
        dataPointsCount: _sensorService.bufferSize,
        logMessages: _logMessages,
        onStopRecording: _stopRealTimeRecording,
        fsmState: _currentFsmState,
      );
    }

    if (_fallDetected && !_helpCalled) {
      return FallDetectedView(
        secondsLeft: _secondsLeft,
        onConfirmWellbeing: _confirmUserFine,
      );
    }

    if (_helpCalled) {
      return HelpCalledView(
        onReset: _resetApp,
      );
    }

    return const SizedBox.shrink();
  }
}
