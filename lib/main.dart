import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FallDetectorApp());
}

class FallDetectorApp extends StatelessWidget {
  const FallDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
