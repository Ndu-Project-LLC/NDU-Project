import 'package:ndu_project/widgets/page_tours/page_tour.dart';
import 'package:ndu_project/widgets/page_tours/agile_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/closeout_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/design_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/execution_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/front_end_planning_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/initiation_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/misc_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/module_page_tours.dart';
import 'package:ndu_project/widgets/page_tours/planning_page_tours.dart';

export 'package:ndu_project/widgets/page_tours/page_tour.dart';
export 'package:ndu_project/widgets/page_tours/module_page_tours.dart'
    show
        wbsModuleTour,
        wbsModuleTourStops,
        scheduleModuleTour,
        scheduleModuleTourStops,
        costEstimateModuleTour,
        costEstimateModuleTourStops,
        changeManagementModuleTour,
        changeManagementModuleTourStops;

/// Every bespoke page tour, keyed by the page id the header passes in.
///
/// Pages not listed here fall back to the derived tour. Add a new phase's map
/// to this merge when it is written.
final Map<String, PageTour> pageTours = {
  ...initiationPageTours,
  ...frontEndPlanningPageTours,
  ...planningPageTours,
  ...designPageTours,
  ...executionPageTours,
  ...agilePageTours,
  ...closeoutPageTours,
  ...miscPageTours,
  'wbs-module': wbsModuleTour,
  'schedule-module': scheduleModuleTour,
  'cost-estimate-module': costEstimateModuleTour,
  'change-management-module': changeManagementModuleTour,
};
