import 'package:flutter/material.dart';
import 'package:ndu_project/screens/planning_procurement_v2_screen.dart';

class PlanningProcurementScreen extends StatelessWidget {
 const PlanningProcurementScreen({super.key});

 static void open(BuildContext context) {
 Navigator.of(context).push(
 MaterialPageRoute(builder: (_) => const PlanningProcurementV2Screen()),
 );
 }

 @override
 Widget build(BuildContext context) {
 return const PlanningProcurementV2Screen();
 }
}
