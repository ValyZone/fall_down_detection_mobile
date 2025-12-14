import 'package:flutter/material.dart';
import '../models/fsm_state.dart';

class RecordingView extends StatelessWidget {
  final double recordingTime;
  final int dataPointsCount;
  final List<String> logMessages;
  final VoidCallback onStopRecording;
  final FallDetectionState? fsmState;

  const RecordingView({
    super.key,
    required this.recordingTime,
    required this.dataPointsCount,
    required this.logMessages,
    required this.onStopRecording,
    this.fsmState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
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
          'Buffer size: $dataPointsCount',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        if (fsmState != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStateColor(fsmState!),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'FSM: ${fsmState!.name}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onStopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 15,
            ),
          ),
          child: const Text(
            'Stop Recording',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(thickness: 2),
        const SizedBox(height: 10),
        const Text(
          '📋 Terminal Output',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: logMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for logs...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: false,
                    itemCount: logMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          logMessages[index],
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Color _getStateColor(FallDetectionState state) {
    switch (state) {
      case FallDetectionState.monitoring:
        return Colors.green;
      case FallDetectionState.stationarityCheck:
        return Colors.orange;
      case FallDetectionState.upload:
        return Colors.blue;
    }
  }
}
