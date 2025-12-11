import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sensor_data.dart';
import '../models/ring_buffer.dart';
import '../utils/sensor_math.dart';

/// Service for managing accelerometer and gyroscope sensor streams.
///
/// Provides continuous sensor data collection with callbacks for
/// impact detection and motionless state detection.
class SensorService {
  /// Subscription to accelerometer events
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  /// Subscription to gyroscope events
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  /// Circular buffer for storing recent accelerometer data
  final RingBuffer<SensorData> _dataBuffer;

  /// Buffer for recent gyroscope readings (for motion detection)
  final List<GyroscopeEvent> _gyroscopeBuffer = [];

  /// Maximum gyroscope buffer size (last 3 seconds at ~50Hz = 150 samples)
  static const int _maxGyroscopeBufferSize = 150;

  /// Callback for new sensor data
  void Function(SensorData data)? onDataReceived;

  /// Callback for impact detection
  void Function(double svm)? onImpactDetected;

  /// Callback for motionless state detected
  void Function()? onMotionlessDetected;

  /// Whether the service is currently running
  bool _isRunning = false;

  /// Impact threshold in m/s² (default: 3.5g = 34.335 m/s²)
  final double impactThreshold;

  /// Variance threshold for motionless detection (default: 0.5)
  final double varianceThreshold;

  /// Gyroscope threshold for motion detection (rad/s, default: 0.1)
  final double gyroscopeThreshold;

  /// Sampling rate check timer
  Timer? _samplingTimer;

  /// Number of samples received
  int _sampleCount = 0;

  /// Last sampling rate calculation time
  DateTime? _lastSamplingCheck;

  /// Current sampling rate (Hz)
  double _currentSamplingRate = 0.0;

  SensorService({
    required int bufferCapacity,
    this.impactThreshold = 34.335, // 3.5g
    this.varianceThreshold = 0.5,
    this.gyroscopeThreshold = 0.1,
  }) : _dataBuffer = RingBuffer<SensorData>(bufferCapacity);

  /// Starts listening to sensor streams
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _sampleCount = 0;
    _lastSamplingCheck = DateTime.now();

    // Start accelerometer stream
    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerEvent,
      onError: (error) {
        print('Error in accelerometer stream: $error');
      },
      cancelOnError: false,
    );

    // Start gyroscope stream
    _gyroscopeSubscription = gyroscopeEventStream().listen(
      _onGyroscopeEvent,
      onError: (error) {
        print('Error in gyroscope stream: $error');
      },
      cancelOnError: false,
    );

    // Start sampling rate monitor
    _samplingTimer = Timer.periodic(
      const Duration(seconds: 5),
      _checkSamplingRate,
    );
  }

  /// Stops listening to sensor streams
  void stop() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;

    _samplingTimer?.cancel();
    _samplingTimer = null;

    _isRunning = false;
  }

  /// Handles incoming accelerometer events
  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Convert to SensorData and add to buffer
    final sensorData = SensorData.fromAccelerometer(event);
    _dataBuffer.push(sensorData);
    _sampleCount++;

    // Notify callback
    onDataReceived?.call(sensorData);

    // Check for impact
    if (sensorData.svm > impactThreshold) {
      onImpactDetected?.call(sensorData.svm);
    }

    // Periodically check for motionless state
    if (_dataBuffer.isFull && _sampleCount % 50 == 0) {
      _checkMotionlessState();
    }
  }

  /// Handles incoming gyroscope events
  void _onGyroscopeEvent(GyroscopeEvent event) {
    // Add to buffer
    _gyroscopeBuffer.add(event);

    // Keep buffer size limited
    if (_gyroscopeBuffer.length > _maxGyroscopeBufferSize) {
      _gyroscopeBuffer.removeAt(0);
    }
  }

  /// Checks if the device is stationary (stopped)
  /// Uses STRICT criteria: Accel StdDev < 0.05 AND Gyro rotation < 0.1 rad/s
  void _checkMotionlessState() {
    // Get recent data (last 1 second for stationarity check)
    final recentData = _getRecentData(const Duration(seconds: 1));

    if (recentData.isEmpty) return;

    // Check accelerometer standard deviation
    final accelStdDev = _calculateAccelStdDev(recentData);
    final isAccelStationary = accelStdDev < 0.05;

    // Check gyroscope rotation
    final isGyroStationary = _isGyroscopeStationary();

    // Both must indicate stationary state
    if (isAccelStationary && isGyroStationary) {
      onMotionlessDetected?.call();
    }
  }

  /// Calculates standard deviation of SVM over the window
  double _calculateAccelStdDev(List<SensorData> window) {
    if (window.isEmpty) return 0.0;

    final svmValues = window.map((data) => data.svm).toList();
    return SensorMath.calculateStandardDeviation(svmValues);
  }

  /// Checks if gyroscope indicates stationary state
  /// Threshold: rotation < 0.1 rad/s
  bool _isGyroscopeStationary() {
    if (_gyroscopeBuffer.length < 50) return false;

    // Check last 1 second of gyroscope data (~50 samples at 50Hz)
    final recentGyro = _gyroscopeBuffer.length > 50
        ? _gyroscopeBuffer.sublist(_gyroscopeBuffer.length - 50)
        : _gyroscopeBuffer;

    // Calculate average absolute rotation rate
    double totalRotation = 0.0;
    for (final gyro in recentGyro) {
      final rotation = sqrt(gyro.x * gyro.x + gyro.y * gyro.y + gyro.z * gyro.z);
      totalRotation += rotation;
    }

    final avgRotation = totalRotation / recentGyro.length;

    // Stationary if rotation < 0.1 rad/s
    return avgRotation < 0.1;
  }

  /// Monitors sampling rate
  void _checkSamplingRate(Timer timer) {
    final now = DateTime.now();
    if (_lastSamplingCheck != null) {
      final elapsed = now.difference(_lastSamplingCheck!).inMilliseconds / 1000.0;
      _currentSamplingRate = _sampleCount / elapsed;

      // Reset counters
      _sampleCount = 0;
      _lastSamplingCheck = now;
    }
  }

  /// Gets recent data within the specified duration
  List<SensorData> _getRecentData(Duration duration) {
    final now = DateTime.now();
    final cutoff = now.subtract(duration);

    final allData = _dataBuffer.toList();
    return allData.where((data) => data.timestamp.isAfter(cutoff)).toList();
  }

  /// Gets all buffered sensor data
  List<SensorData> getBufferData() {
    return _dataBuffer.toList();
  }

  /// Gets a snapshot of the current buffer
  List<SensorData> getBufferSnapshot() {
    return _dataBuffer.snapshot();
  }

  /// Clears the sensor data buffer
  void clearBuffer() {
    _dataBuffer.clear();
    _gyroscopeBuffer.clear();
  }

  /// Gets the current buffer size
  int get bufferLength => _dataBuffer.length;

  /// Checks if the buffer is full
  bool get isBufferFull => _dataBuffer.isFull;

  /// Gets the buffer capacity
  int get bufferCapacity => _dataBuffer.capacity;

  /// Gets the current sampling rate in Hz
  double get samplingRate => _currentSamplingRate;

  /// Checks if the service is running
  bool get isRunning => _isRunning;

  /// Disposes of resources
  void dispose() {
    stop();
  }
}
