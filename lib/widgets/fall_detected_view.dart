import 'package:flutter/material.dart';

class FallDetectedView extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onConfirmWellbeing;

  const FallDetectedView({
    super.key,
    required this.secondsLeft,
    required this.onConfirmWellbeing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Fall Detected! Are you okay?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          'Time remaining: $secondsLeft s',
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onConfirmWellbeing,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 20,
            ),
          ),
          child: const Text(
            "I'm OK",
            style: TextStyle(fontSize: 22),
          ),
        ),
      ],
    );
  }
}
