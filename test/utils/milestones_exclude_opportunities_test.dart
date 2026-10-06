// Lusaka 25 review: "why is the opportunity still showing up here under the
// allowance, under the project milestones, because they are not milestones?"
//
// Project Opportunities and Allowances carry an `appliesTo` tag that can
// include 'Schedule'. An earlier build read that tag as "write this into
// Project Milestones", so the milestone table filled up with
// `Opportunity: …` / `Allowance: …` rows. They are not milestones, and the
// owner asked for them to be erased.
//
// These tests drive the real production path — the FEP Apply-To sync
// (`ProjectDataHelper.applyTaggedFrontEndPlanningData`) — which is what the
// Opportunities and Allowance screens call when they save.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/utils/project_data_helper.dart';

ProjectDataModel _dataWith(
  FrontEndPlanningData fep, {
  List<Milestone>? milestones,
}) {
  return ProjectDataModel(
    projectName: 'Test Project',
    frontEndPlanning: fep,
    keyMilestones: milestones,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Project Milestones hold milestones only', () {
    test('a Schedule-tagged opportunity does not become a milestone', () {
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        _dataWith(
          FrontEndPlanningData(
            opportunityItems: [
              OpportunityItem(
                id: 'opp_1',
                opportunity: 'Shift the pilot to the low season',
                discipline: 'Planning',
                appliesTo: const ['Schedule'],
                potentialScheduleSavings: '3 weeks',
              ),
            ],
          ),
        ),
      );

      expect(data.keyMilestones, isEmpty);
    });

    test('a Schedule-tagged allowance does not become a milestone', () {
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        _dataWith(
          FrontEndPlanningData(
            allowanceItems: [
              AllowanceItem(
                id: 'allow_1',
                number: 1,
                name: 'Weather contingency',
                type: 'Weather',
                appliesTo: const ['Schedule'],
                notes: 'Monsoon window',
              ),
            ],
          ),
        ),
      );

      expect(data.keyMilestones, isEmpty);
    });

    test('rows an earlier build already wrote are purged on save', () {
      // Exactly what the owner had on screen: an Opportunity row and an
      // Allowance row sitting under the project milestones.
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        _dataWith(
          FrontEndPlanningData(),
          milestones: [
            Milestone(
              name: 'Design freeze',
              discipline: 'Design',
              dueDate: '2026-10-01',
            ),
            Milestone(
              name: 'Opportunity: Shift the pilot to the low season',
              discipline: 'Planning',
              comments: 'Auto-applied from Project Opportunities',
            ),
            Milestone(
              name: 'Allowance: Weather contingency',
              discipline: 'Weather',
              comments: 'Auto-applied from Allowance',
            ),
          ],
        ),
      );

      expect(data.keyMilestones, hasLength(1));
      expect(data.keyMilestones.single.name, 'Design freeze');
    });

    test('manual milestones survive the sync untouched', () {
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        _dataWith(
          FrontEndPlanningData(
            opportunityItems: [
              OpportunityItem(
                id: 'opp_2',
                opportunity: 'Bundle the two site surveys',
                appliesTo: const ['Schedule', 'Estimate'],
              ),
            ],
          ),
          milestones: [
            Milestone(
              name: 'Design freeze',
              discipline: 'Design',
              dueDate: '2026-10-01',
            ),
            Milestone(
              name: 'Handover',
              discipline: 'Delivery',
              dueDate: '2027-02-01',
            ),
          ],
        ),
      );

      expect(
        data.keyMilestones.map((m) => m.name),
        ['Design freeze', 'Handover'],
      );
    });

    test('the other Apply-To destinations still fire', () {
      // Guard rail: removing the Schedule destination must not take the
      // Estimate destination down with it.
      final data = ProjectDataHelper.applyTaggedFrontEndPlanningData(
        _dataWith(
          FrontEndPlanningData(
            allowanceItems: [
              AllowanceItem(
                id: 'allow_2',
                number: 2,
                name: 'Weather contingency',
                type: 'Weather',
                amount: 50000,
                appliesTo: const ['Estimate'],
              ),
            ],
          ),
        ),
      );

      expect(data.costEstimateItems, hasLength(1));
      expect(data.keyMilestones, isEmpty);
    });
  });
}
