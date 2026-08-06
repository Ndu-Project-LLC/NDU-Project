import 'package:flutter/material.dart';
import 'package:ndu_project/screens/planning_procurement_v2_screen.dart';
import 'package:go_router/go_router.dart';

class PlanningProcurementScreen extends StatelessWidget {
 const PlanningProcurementScreen({super.key});

 static void open(BuildContext context) {
 context.push('/planning-procurement');
 }

 @override
 Widget build(BuildContext context) {
 return const PlanningProcurementV2Screen();
 }
}
