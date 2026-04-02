import 'package:flutter/material.dart';

import 'services/share_navigation_coordinator.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OneLapStravaApp());
}

class OneLapStravaApp extends StatefulWidget {
  const OneLapStravaApp({super.key});

  @override
  State<OneLapStravaApp> createState() => _OneLapStravaAppState();
}

class _OneLapStravaAppState extends State<OneLapStravaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final ShareNavigationCoordinator _shareNavigationCoordinator =
      ShareNavigationCoordinator(navigatorKey: _navigatorKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareNavigationCoordinator.start();
    });
  }

  @override
  void dispose() {
    _shareNavigationCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'WanSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
