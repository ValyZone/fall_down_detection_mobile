import 'dart:async';
import 'dart:convert';
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
  final List<String> _logMessages = [];
  int _sampleCount = 0;

  // Timers and subscriptions
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  // Latest gyroscope reading (synced with accelerometer)
  GyroscopeEvent? _latestGyroscope;

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
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

          // Update countdown based on elapsed time
          _secondsLeft = AppConfig.fallDetectionCountdown - _elapsedTime.floor();

          // Timer expired - call for help
          if (_elapsedTime >= AppConfig.fallDetectionCountdown.toDouble()) {
            timer.cancel();
            _callForHelp();
          }
        });
      },
    );
  }

  /// Runs "positive alarm" test - fetches and sends mock positive data from server
  Future<void> _runPositiveAlarmTest() async {
    try {
      // Fetch mock positive data from server
      final mockData = await ApiService.fetchMockData('positive');

      // Send data to server for analysis
      await ApiService.sendAccelerometerData(mockData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Positive alarm data sent successfully'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
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

  /// Runs "false positive alarm" test - fetches and sends mock false positive data from server
  Future<void> _runFalsePositiveAlarmTest() async {
    try {
      // Fetch mock false positive data from server
      final mockData = await ApiService.fetchMockData('false-positive');

      // Send data to server for analysis
      await ApiService.sendAccelerometerData(mockData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ False positive alarm data sent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
      _logMessages.clear();
      _sampleCount = 0;
    });

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('[$timeStr] 🔴 Recording started - Monitoring for falls...');
    _addLog('         Tracking: Accelerometer + Gyroscope');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Subscribe to gyroscope events (runs at higher frequency)
    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      _latestGyroscope = event;
    });

    // Subscribe to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      // Get gyroscope data (or default to 0 if not available)
      final gyroX = _latestGyroscope?.x ?? 0.0;
      final gyroY = _latestGyroscope?.y ?? 0.0;
      final gyroZ = _latestGyroscope?.z ?? 0.0;
      final gyroMagnitude = sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
      
      final csvRow = '${_recordingTime.toStringAsFixed(1)}\t'
          '${event.x.toStringAsFixed(2)}\t'
          '${event.y.toStringAsFixed(2)}\t'
          '${event.z.toStringAsFixed(2)}\t'
          '${sqrt(event.x * event.x + event.y * event.y + event.z * event.z).toStringAsFixed(2)}\t'
          '${gyroX.toStringAsFixed(3)}\t'
          '${gyroY.toStringAsFixed(3)}\t'
          '${gyroZ.toStringAsFixed(3)}\t'
          '${gyroMagnitude.toStringAsFixed(3)}';
      
      setState(() {
        _realTimeData.add(csvRow);
        _sampleCount++;
        
        // Implement rolling buffer: keep only last 20 seconds (200 samples at 10Hz)
        // When buffer exceeds max, remove oldest samples
        if (_realTimeData.length > AppConfig.maxDataPoints) {
          final samplesToRemove = _realTimeData.length - AppConfig.maxDataPoints;
          _realTimeData.removeRange(0, samplesToRemove);
        }
      });
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
    _gyroscopeSubscription?.cancel();
    _recordingTimer?.cancel();
    _latestGyroscope = null;

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('[$timeStr] ⏹️ Recording stopped');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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

    // Send all data in buffer (last 20 seconds)
    List<String> dataToSend = List.from(_realTimeData);

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addLog('[$timeStr] Sending ${dataToSend.length} data points...');

      // Show notification that data is being sent
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 Sending ${dataToSend.length} data points to server...'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      final response = await ApiService.sendAccelerometerData(dataToSend);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Try to parse the response
        try {
          final responseData = json.decode(response.body);
          final fallDetected = responseData['fallDetected'] ?? false;

          if (fallDetected) {
            _addLog('[$timeStr] 🚨 FALL DETECTED! Emergency response activated.');

            // Show fall detected notification
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 FALL DETECTED - Emergency response activated!'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                ),
              );
            }

            // Stop recording and show alert
            _stopRealTimeRecording();
            _showFallAlert();
          } else {
            _addLog('[$timeStr] ✅ Normal motion - No fall detected');

            // Show success notification
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Data sent successfully - No fall detected'),
                  duration: const Duration(milliseconds: 800),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }

          // Show additional info if available
          if (responseData['message'] != null) {
            _addLog('         Analysis: ${responseData['message']}');
          }
        } catch (e) {
          // If response is not JSON, just show success
          _addLog('[$timeStr] ✅ Data sent successfully');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Data sent successfully'),
                duration: Duration(milliseconds: 800),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
              ),
            );
          }
        }
      } else {
        _addLog('[$timeStr] ⚠️ Server error (Status: ${response.statusCode})');

        // Show error notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Server error (Status: ${response.statusCode})'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }

      // Note: Buffer is maintained at 20 seconds automatically in the listener
    } catch (e) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _addLog('[$timeStr] ❌ Connection failed: ${e.toString()}');

      // Show connection error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection failed: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showFallAlert() {
    setState(() {
      _fallDetected = true;
      _secondsLeft = AppConfig.fallDetectionCountdown;
      _elapsedTime = 0.0;
    });

    // Start countdown timer
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        setState(() {
          _elapsedTime += 0.1;
          _secondsLeft = AppConfig.fallDetectionCountdown - _elapsedTime.floor();

          // Timer expired - help needed
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
      // Keep only last 100 log lines to prevent memory issues
      if (_logMessages.length > 100) {
        _logMessages.removeAt(0);
      }
    });
    // Also print to console
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
              onFallTest: _runPositiveAlarmTest,
              onNoFallTest: _runFalsePositiveAlarmTest,
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
        logMessages: _logMessages,
        onStopRecording: _stopRealTimeRecording,
      );
    }

    // Fall Detected State
    if (_fallDetected && !_helpCalled) {
      return FallDetectedView(
        secondsLeft: _secondsLeft,
        onConfirmWellbeing: _confirmUserFine,
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
