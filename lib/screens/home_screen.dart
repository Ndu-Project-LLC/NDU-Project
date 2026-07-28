import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';

/// Legacy home route now forwards to the project dashboard.
class HomeScreen extends StatelessWidget {
 const HomeScreen({super.key});

 static Future<void> open(BuildContext context) {
 return Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => const ProjectDashboardScreen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 return const ProjectDashboardScreen();
 }
}
