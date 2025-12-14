import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/ring_buffer.dart';
import '../models/sensor_data.dart';
import '../config.dart';

class SensorService {
  final RingBuffer<SensorData> _buffer = RingBuffer<SensorData>(
    AppConfig.bufferCapacity,
  );

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  GyroscopeEvent? _latestGyroscope;

  void Function(double svm)? onImpactDetected;
  void Function()? onMotionlessDetected;
  void Function(SensorData data)? onDataReceived;

  bool _isRunning = false;
  final List<double> _recentSvmValues = [];
  static const int _stationarityWindowSize = 50;

  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _buffer.clear();
    _recentSvmValues.clear();

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      _latestGyroscope = event;
    });

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final sensorData = SensorData.fromAccelerometer(event);

      _buffer.push(sensorData);
      onDataReceived?.call(sensorData);
      _checkImpactCondition(sensorData);
      _checkMotionlessState(sensorData);
    });
  }

  void stop() {
    _isRunning = false;
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _latestGyroscope = null;
  }

  List<SensorData> getBufferSnapshot() {
    return _buffer.snapshot();
  }

  int get bufferSize => _buffer.length;
  bool get isBufferFull => _buffer.isFull;
  bool get isRunning => _isRunning;

  void clearBuffer() {
    _buffer.clear();
    _recentSvmValues.clear();
  }
  void _checkImpactCondition(SensorData data) {
    if (data.svm > AppConfig.impactThreshold) {
      onImpactDetected?.call(data.svm);
    }
  }

  void _checkMotionlessState(SensorData data) {
    _recentSvmValues.add(data.svm);
    if (_recentSvmValues.length > _stationarityWindowSize) {
      _recentSvmValues.removeAt(0);
    }

    if (_recentSvmValues.length < _stationarityWindowSize) {
      return;
    }
    final stdDev = _calculateStandardDeviation(_recentSvmValues);

    final gyroMag = _latestGyroscope != null
        ? sqrt(
            _latestGyroscope!.x * _latestGyroscope!.x +
                _latestGyroscope!.y * _latestGyroscope!.y +
                _latestGyroscope!.z * _latestGyroscope!.z,
          )
        : 0.0;

    final isMotionless = stdDev < AppConfig.varianceThreshold &&
        gyroMag < AppConfig.gyroscopeThreshold;

    if (isMotionless) {
      onMotionlessDetected?.call();
    }
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;

    return sqrt(variance);
  }

  void dispose() {
    stop();
  }
}
