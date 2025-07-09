import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Fall Detector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MyHomePage(title: 'Simple Fall Detector'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool fallDetected = false;
  bool helpCalled = false;
  bool isRecording = false;
  int secondsLeft = 15;
  Timer? timer;
  Timer? recordingTimer;
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
  List<String> accelerometerData = [];
  List<String> realTimeData = [];
  double elapsedTime = 0.0;
  double recordingTime = 0.0;
  final Random random = Random();

  void mockFall() {
    print('🔴 Mock fall button pressed!');
    _startMockTest('random');
  }

  void mockFallDetected() {
    print('🔴 Mock FALL data button pressed!');
    _startMockTest('fall');
  }

  void mockNoFall() {
    print('🔴 Mock NO-FALL data button pressed!');
    _startMockTest('nofall');
  }

  void _startMockTest(String testType) {
    setState(() {
      fallDetected = true;
      secondsLeft = 3;
      accelerometerData.clear();
      elapsedTime = 0.0;
    });

    timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        elapsedTime += 0.1; // Increment by 0.1 seconds (100ms)
        
        // Generate appropriate data based on test type
        switch (testType) {
          case 'fall':
            generateMockFallData(elapsedTime);
            break;
          case 'nofall':
            generateMockNoFallData(elapsedTime);
            break;
          default:
            generateMockData(elapsedTime);
        }

        // Update seconds left every 10 ticks (1 second)
        if ((elapsedTime * 10).round() % 10 == 0) {
          secondsLeft = 3 - (elapsedTime / 1.0).floor();
          print('⏰ Timer tick: $secondsLeft seconds left');
        }

        if (elapsedTime >= 3.0) {
          print('⏰ Timer expired, calling help!');
          t.cancel();
          callHelp();
        }
      });
    });
  }

  void generateMockData(double time) {
    final ax = (0.5 + random.nextDouble()).toStringAsFixed(2);
    final ay = (1.5 + random.nextDouble()).toStringAsFixed(2);
    final az = (9.5 + random.nextDouble()).toStringAsFixed(2);
    final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
        double.parse(ay) * double.parse(ay) +
        double.parse(az) * double.parse(az))).toStringAsFixed(2);

    final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
    accelerometerData.add(csvRow);
  }

  void generateMockFallData(double time) {
    // Generate data that will be detected as a fall
    // Phase 1: Normal standing/walking (0.0 - 0.8s)
    if (time <= 0.8) {
      final ax = (0.5 + random.nextDouble() * 0.5).toStringAsFixed(2);
      final ay = (1.0 + random.nextDouble() * 0.5).toStringAsFixed(2);
      final az = (9.6 + random.nextDouble() * 0.4).toStringAsFixed(2); // Z-axis will be dominant
      final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
          double.parse(ay) * double.parse(ay) +
          double.parse(az) * double.parse(az))).toStringAsFixed(2);
      
      final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
      accelerometerData.add(csvRow);
    }
    // Phase 2: Start of fall - losing balance (0.8s - 1.5s)
    else if (time <= 1.5) {
      final ax = (0.3 + random.nextDouble() * 0.4).toStringAsFixed(2);
      final ay = (0.8 + random.nextDouble() * 0.6).toStringAsFixed(2);
      final az = (0.1 + random.nextDouble() * 0.3).toStringAsFixed(2); // Below 0.5 threshold
      final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
          double.parse(ay) * double.parse(ay) +
          double.parse(az) * double.parse(az))).toStringAsFixed(2);
      
      final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
      accelerometerData.add(csvRow);
    }
    // Phase 3: Free fall - very low acceleration (1.5s - 2.0s)
    else if (time <= 2.0) {
      final ax = (0.1 + random.nextDouble() * 0.2).toStringAsFixed(2);
      final ay = (0.2 + random.nextDouble() * 0.3).toStringAsFixed(2);
      final az = (0.0 + random.nextDouble() * 0.1).toStringAsFixed(2); // Very low, some exactly 0.0
      final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
          double.parse(ay) * double.parse(ay) +
          double.parse(az) * double.parse(az))).toStringAsFixed(2);
      
      final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
      accelerometerData.add(csvRow);
    }
    // Phase 4: Impact with ground (2.0s - 2.3s)
    else if (time <= 2.3) {
      final ax = (0.1 + random.nextDouble() * 0.3).toStringAsFixed(2);
      final ay = (0.3 + random.nextDouble() * 0.4).toStringAsFixed(2);
      final az = '0.0'; // Exact zero for impact detection
      final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
          double.parse(ay) * double.parse(ay) +
          double.parse(az) * double.parse(az))).toStringAsFixed(2);
      
      final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
      accelerometerData.add(csvRow);
    }
    // Phase 5: After impact - recovery/settling (2.3s - 3.0s)
    else {
      final ax = (0.6 + random.nextDouble() * 0.6).toStringAsFixed(2);
      final ay = (1.0 + random.nextDouble() * 0.8).toStringAsFixed(2);
      final az = (8.0 + random.nextDouble() * 2.0).toStringAsFixed(2);
      final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
          double.parse(ay) * double.parse(ay) +
          double.parse(az) * double.parse(az))).toStringAsFixed(2);
      
      final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
      accelerometerData.add(csvRow);
    }
  }

  void generateMockNoFallData(double time) {
    // Generate data that will NOT be detected as a fall
    // Keep all axes above 0.5 threshold and never hit 0.0
    final ax = (0.6 + random.nextDouble() * 0.8).toStringAsFixed(2);
    final ay = (1.0 + random.nextDouble() * 1.0).toStringAsFixed(2);
    final az = (8.5 + random.nextDouble() * 2.0).toStringAsFixed(2); // Always well above 0.5
    final absAcc = (sqrt(double.parse(ax) * double.parse(ax) +
        double.parse(ay) * double.parse(ay) +
        double.parse(az) * double.parse(az))).toStringAsFixed(2);

    final csvRow = '$time\t$ax\t$ay\t$az\t$absAcc';
    accelerometerData.add(csvRow);
  }

  void confirmWellbeing() {
    timer?.cancel();
    setState(() {
      fallDetected = false;
      helpCalled = false;
      secondsLeft = 3;
      accelerometerData.clear();
    });
  }

  void resetApp() {
    timer?.cancel();
    setState(() {
      fallDetected = false;
      helpCalled = false;
      secondsLeft = 3;
      accelerometerData.clear();
    });
  }

  void startRealTimeRecording() {
    print('🎬 Starting real-time recording');
    setState(() {
      isRecording = true;
      recordingTime = 0.0;
      realTimeData.clear();
    });

    // Listen to accelerometer events
    accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final currentTime = recordingTime.toStringAsFixed(1);
      final ax = event.x.toStringAsFixed(2);
      final ay = event.y.toStringAsFixed(2);
      final az = event.z.toStringAsFixed(2);
      final absAcc = sqrt(event.x * event.x + event.y * event.y + event.z * event.z).toStringAsFixed(2);
      
      final csvRow = '$currentTime\t$ax\t$ay\t$az\t$absAcc';
      realTimeData.add(csvRow);
      
      // Print occasional debug info
      if (realTimeData.length % 50 == 0) {
        print('📊 Real-time data points collected: ${realTimeData.length}');
      }
    });

    // Timer to track recording time and send data every 5 seconds
    recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        recordingTime += 0.1;
      });
      
      // Send data every 5 seconds
      if (recordingTime % 5.0 < 0.1 && realTimeData.isNotEmpty) {
        sendRealTimeData();
      }
    });
  }

  void stopRealTimeRecording() {
    print('🛑 Stopping real-time recording');
    accelerometerSubscription?.cancel();
    recordingTimer?.cancel();
    
    setState(() {
      isRecording = false;
    });
    
    // Send any remaining data
    if (realTimeData.isNotEmpty) {
      sendRealTimeData();
    }
  }

  void sendRealTimeData() async {
    if (realTimeData.isEmpty) return;
    
    // Keep only the last 60 seconds of data (approximately 600 data points at 10Hz)
    final maxDataPoints = 600; // 60 seconds * 10 data points per second
    List<String> dataToSend = realTimeData;
    
    if (realTimeData.length > maxDataPoints) {
      // Keep only the most recent 60 seconds
      dataToSend = realTimeData.sublist(realTimeData.length - maxDataPoints);
      print('📊 Trimming data to last 60 seconds (${dataToSend.length} points)');
    }
    
    print('📡 Sending real-time data (${dataToSend.length} points, max 60 seconds)');
    
    final csvHeader = '"Time (s)","Acceleration x (m/s^2)","Acceleration y (m/s^2)","Acceleration z (m/s^2)","Absolute acceleration (m/s^2)"\n';
    final csvData = csvHeader + dataToSend.join('\n');
    
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.100:3030/fall-detection/receive-data'),
        headers: {'Content-Type': 'text/csv'},
        body: csvData,
      );
      print('✅ Real-time data sent - Status: ${response.statusCode}');
      print('📝 Response: ${response.body}');
      
      // Trim the stored data to keep only last 60 seconds
      if (realTimeData.length > maxDataPoints) {
        realTimeData = realTimeData.sublist(realTimeData.length - maxDataPoints);
        print('🗂️ Trimmed stored data to ${realTimeData.length} points (60 seconds)');
      }
    } catch (e) {
      print('❌ Failed to send real-time data: $e');
    }
  }

  void callHelp() async {
    print('📞 callHelp() method started');
    setState(() {
      helpCalled = true;
    });

    final csvHeader =
        '"Time (s)","Acceleration x (m/s^2)","Acceleration y (m/s^2)","Acceleration z (m/s^2)","Absolute acceleration (m/s^2)"\n';
    final csvData = csvHeader + accelerometerData.join('\n');

    print('🚨 Starting API call to: http://192.168.0.100:3030/fall-detection/receive-data');
    print('📊 Data length: ${csvData.length} characters');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.100:3030/fall-detection/receive-data'),
        headers: {'Content-Type': 'text/csv'},
        body: csvData,
      );
      print('✅ Response status: ${response.statusCode}');
      print('📝 Response body: ${response.body}');
    } catch (e, stackTrace) {
      print('❌ Failed to call help: $e');
      print('📋 Stack trace: $stackTrace');
    }

    accelerometerData.clear();
  }

  @override
  void dispose() {
    timer?.cancel();
    recordingTimer?.cancel();
    accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!fallDetected && !isRecording)
              Column(
                children: [
                  const Text(
                    'All Clear — No Fall Detected',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Choose test type:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: mockFall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        ),
                        child: const Text('Random\nData', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                      ),
                      ElevatedButton(
                        onPressed: mockFallDetected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        ),
                        child: const Text('Fall\nDetected', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: mockNoFall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        ),
                        child: const Text('No Fall\nDetected', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Real-time monitoring:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: startRealTimeRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    ),
                    child: const Text('Start Real-Time\nRecording', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            if (isRecording)
              Column(
                children: [
                  const Text(
                    '🔴 Recording Real-Time Data',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recording time: ${recordingTime.toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Data points: ${realTimeData.length}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Data is automatically sent every 5 seconds',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: stopRealTimeRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    ),
                    child: const Text('Stop Recording', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ],
              ),
            if (fallDetected && !helpCalled)
              Column(
                children: [
                  const Text(
                    'Fall Detected! Are you okay?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Time remaining: $secondsLeft s',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: confirmWellbeing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 20),
                    ),
                    child: const Text("I'm OK", style: TextStyle(fontSize: 22)),
                  ),
                ],
              ),
            if (helpCalled)
              Column(
                children: [
                  const Text(
                    'Help is being contacted! Data sent.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: resetApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 20),
                    ),
                    child: const Text(
                      "Start Over",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
