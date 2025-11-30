import 'package:flutter/material.dart';

/// Widget that displays the recording state
class RecordingView extends StatelessWidget {
  final double recordingTime;
  final int dataPointsCount;
  final VoidCallback onStopRecording;

  const RecordingView({
    super.key,
    required this.recordingTime,
    required this.dataPointsCount,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '🔴 Recording Real-Time Data',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recording time: ${recordingTime.toStringAsFixed(1)}s',
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          'Data points: $dataPointsCount',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        const Text(
          'Data is automatically sent every 5 seconds',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: onStopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 20,
            ),
          ),
          child: const Text(
            'Stop Recording',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
