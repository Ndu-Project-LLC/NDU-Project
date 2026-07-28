import 'package:flutter/material.dart';
import 'package:ndu_project/screens/planning_technology_screen.dart';

@Deprecated('Use PlanningTechnologyScreen instead.')
class FrontEndPlanningTechnologyScreen extends PlanningTechnologyScreen {
 const FrontEndPlanningTechnologyScreen({super.key});

 static void open(BuildContext context) {
 PlanningTechnologyScreen.open(context);
 }
}
