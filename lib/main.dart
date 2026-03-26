import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OneLapStravaApp());
}

class OneLapStravaApp extends StatelessWidget {
  const OneLapStravaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WanSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
