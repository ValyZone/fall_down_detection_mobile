import 'package:flutter/material.dart';

/// Widget that displays the test mode buttons
class TestButtons extends StatelessWidget {
  final VoidCallback onRandomTest;
  final VoidCallback onFallTest;
  final VoidCallback onNoFallTest;
  final VoidCallback onStartRecording;

  const TestButtons({
    super.key,
    required this.onRandomTest,
    required this.onFallTest,
    required this.onNoFallTest,
    required this.onStartRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'All Clear — No Fall Detected',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
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
            _TestButton(
              label: 'Random\nData',
              color: Colors.orange,
              onPressed: onRandomTest,
            ),
            _TestButton(
              label: 'Positive\nAlarm',
              color: Colors.red,
              onPressed: onFallTest,
            ),
            _TestButton(
              label: 'False Positive\nAlarm',
              color: Colors.green,
              onPressed: onNoFallTest,
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
          onPressed: onStartRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(
              horizontal: 25,
              vertical: 15,
            ),
          ),
          child: const Text(
            'Start Real-Time\nRecording',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _TestButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TestButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
    );
  }
}
