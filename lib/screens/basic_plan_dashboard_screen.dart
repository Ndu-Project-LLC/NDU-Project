import 'package:flutter/material.dart';
import 'package:ndu_project/screens/project_dashboard_screen.dart';

class BasicPlanDashboardScreen extends StatelessWidget {
 const BasicPlanDashboardScreen({super.key});

 @override
 Widget build(BuildContext context) {
 return const ProjectDashboardScreen(isBasicPlan: true);
 }
}
