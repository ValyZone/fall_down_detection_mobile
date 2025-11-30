import 'package:flutter/material.dart';

/// Widget that displays the help called state
class HelpCalledView extends StatelessWidget {
  final VoidCallback onReset;

  const HelpCalledView({
    super.key,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Help is being contacted! Data sent.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: onReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 20,
            ),
          ),
          child: const Text(
            "Start Over",
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
