import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';
import 'package:go_router/go_router.dart';

/// Legacy home route now forwards to the project dashboard.
class HomeScreen extends StatelessWidget {
 const HomeScreen({super.key});

 static Future<void> open(BuildContext context) {
 return context.push('/dashboard');
 }

 @override
 Widget build(BuildContext context) {
 return const ProjectDashboardScreen();
 }
}
