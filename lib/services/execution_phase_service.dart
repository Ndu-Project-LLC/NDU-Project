import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';
import 'package:ndu_project/models/staffing_row.dart';
import 'package:ndu_project/models/meeting_row.dart';
import 'package:ndu_project/models/deliverable_row.dart';
import 'package:ndu_project/models/recurring_deliverable_row.dart';
import 'package:ndu_project/models/status_report_row.dart';
import 'package:ndu_project/models/budget_row.dart';
import 'package:ndu_project/models/design_component.dart';
import 'package:ndu_project/models/agile_task.dart';
import 'package:ndu_project/models/scope_tracking_item.dart';
import 'package:ndu_project/models/stakeholder_alignment_item.dart';

class ExecutionPhaseService {
  static final _firestore = FirebaseFirestore.instance;

  /// Save execution phase page data to project subcollection
  static Future<void> savePageData({
    required String projectId,
    required String pageKey,
    required Map<String, List<LaunchEntry>> sections,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc(pageKey)
          .set({
        'page': pageKey,
        'sections': sections.map(
          (key, value) => MapEntry(
            key,
            value
                .map((e) => {
                      'title': e.title,
                      'details': e.details,
                      'status': e.status,
                    })
                .toList(),
          ),
        ),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge to allow updates
    } catch (e) {
      debugPrint('ExecutionPhaseService save error: $e');
      rethrow;
    }
  }

  /// Load execution phase page data from project subcollection
  static Future<Map<String, List<LaunchEntry>>?> loadPageData({
    required String projectId,
    required String pageKey,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc(pageKey)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() ?? {};
      final sections = <String, List<LaunchEntry>>{};

      final sectionsData = data['sections'];
      if (sectionsData is Map) {
        sectionsData.forEach((key, value) {
          if (value is List) {
            sections[key.toString()] = value.map((e) {
              if (e is Map) {
                return LaunchEntry(
                  title: e['title']?.toString() ?? '',
                  details: e['details']?.toString() ?? '',
                  status: e['status']?.toString() ?? '',
                );
              }
              return LaunchEntry(title: '', details: '', status: '');
            }).toList();
          }
        });
      }

      return sections.isEmpty ? null : sections;
    } catch (e) {
      debugPrint('ExecutionPhaseService load error: $e');
      return null;
    }
  }

  /// Save staffing rows for Staff Team page
  static Future<void> saveStaffingRows({
    required String projectId,
    required List<StaffingRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('staff_team')
          .set({
        'page': 'staff_team',
        'staffingRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveStaffingRows error: $e');
      rethrow;
    }
  }

  /// Load staffing rows for Staff Team page
  static Future<List<StaffingRow>> loadStaffingRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('staff_team')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['staffingRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return StaffingRow.fromJson(Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing StaffingRow: $e');
                return null;
              }
            })
            .whereType<StaffingRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadStaffingRows error: $e');
      return [];
    }
  }

  /// Save meeting rows for Team Meetings page
  static Future<void> saveMeetingRows({
    required String projectId,
    required List<MeetingRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('team_meetings')
          .set({
        'page': 'team_meetings',
        'meetingRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveMeetingRows error: $e');
      rethrow;
    }
  }

  /// Load meeting rows for Team Meetings page
  static Future<List<MeetingRow>> loadMeetingRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('team_meetings')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['meetingRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return MeetingRow.fromJson(Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing MeetingRow: $e');
                return null;
              }
            })
            .whereType<MeetingRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadMeetingRows error: $e');
      return [];
    }
  }

  /// Save deliverable rows for Progress Tracking page
  static Future<void> saveDeliverableRows({
    required String projectId,
    required List<DeliverableRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .set({
        'page': 'progress_tracking',
        'deliverableRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveDeliverableRows error: $e');
      rethrow;
    }
  }

  /// Load deliverable rows for Progress Tracking page
  static Future<List<DeliverableRow>> loadDeliverableRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['deliverableRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return DeliverableRow.fromJson(Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing DeliverableRow: $e');
                return null;
              }
            })
            .whereType<DeliverableRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadDeliverableRows error: $e');
      return [];
    }
  }

  /// Save recurring deliverable rows
  static Future<void> saveRecurringDeliverableRows({
    required String projectId,
    required List<RecurringDeliverableRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .set({
        'page': 'progress_tracking',
        'recurringDeliverableRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
          'ExecutionPhaseService saveRecurringDeliverableRows error: $e');
      rethrow;
    }
  }

  /// Load recurring deliverable rows
  static Future<List<RecurringDeliverableRow>> loadRecurringDeliverableRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['recurringDeliverableRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return RecurringDeliverableRow.fromJson(
                    Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing RecurringDeliverableRow: $e');
                return null;
              }
            })
            .whereType<RecurringDeliverableRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint(
          'ExecutionPhaseService loadRecurringDeliverableRows error: $e');
      return [];
    }
  }

  /// Save status report rows
  static Future<void> saveStatusReportRows({
    required String projectId,
    required List<StatusReportRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .set({
        'page': 'progress_tracking',
        'statusReportRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveStatusReportRows error: $e');
      rethrow;
    }
  }

  /// Load status report rows
  static Future<List<StatusReportRow>> loadStatusReportRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['statusReportRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return StatusReportRow.fromJson(Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing StatusReportRow: $e');
                return null;
              }
            })
            .whereType<StatusReportRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadStatusReportRows error: $e');
      return [];
    }
  }

  /// Save budget rows for Progress Tracking page
  static Future<void> saveBudgetRows({
    required String projectId,
    required List<BudgetRow> rows,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .set({
        'page': 'progress_tracking',
        'budgetRows': rows.map((r) => r.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveBudgetRows error: $e');
      rethrow;
    }
  }

  /// Load budget rows for Progress Tracking page
  static Future<List<BudgetRow>> loadBudgetRows({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('progress_tracking')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final rowsRaw = data['budgetRows'];
      if (rowsRaw is List) {
        return rowsRaw
            .map((r) {
              try {
                return BudgetRow.fromJson(Map<String, dynamic>.from(r));
              } catch (e) {
                debugPrint('Error parsing BudgetRow: $e');
                return null;
              }
            })
            .whereType<BudgetRow>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadBudgetRows error: $e');
      return [];
    }
  }

  /// Sync contract value to budget (adds or updates Contracts category)
  static Future<void> syncContractValueToBudget({
    required String projectId,
    required double contractValue,
    required String contractName,
    bool isDelete = false,
    String? userId,
  }) async {
    try {
      final budgetRows = await loadBudgetRows(projectId: projectId);

      // Find Contracts category row
      final contractsRowIndex = budgetRows.indexWhere(
        (row) => row.category.toLowerCase() == 'contracts',
      );

      BudgetRow contractsRow;
      if (contractsRowIndex == -1) {
        // Create new Contracts category row
        contractsRow = BudgetRow(
          category: 'Contracts',
          period: DateTime.now().year.toString(),
          plannedAmount: 0.0,
          actualAmount: isDelete ? 0.0 : contractValue,
        );
        budgetRows.add(contractsRow);
      } else {
        // Update existing Contracts category row
        contractsRow = budgetRows[contractsRowIndex];
        if (isDelete) {
          // Remove contract value (ensure it doesn't go negative)
          contractsRow = contractsRow.copyWith(
            actualAmount: (contractsRow.actualAmount - contractValue)
                .clamp(0.0, double.infinity),
          );
        } else {
          // Add contract value
          contractsRow = contractsRow.copyWith(
            actualAmount: contractsRow.actualAmount + contractValue,
          );
        }
        budgetRows[contractsRowIndex] = contractsRow;
      }

      // Save updated budget
      await saveBudgetRows(
        projectId: projectId,
        rows: budgetRows,
        userId: userId,
      );
    } catch (e) {
      debugPrint('ExecutionPhaseService syncContractValueToBudget error: $e');
      // Don't rethrow - budget sync failure shouldn't break contract save
    }
  }

  /// Save design components for Detailed Design page
  static Future<void> saveDesignComponents({
    required String projectId,
    required List<DesignComponent> components,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('detailed_design')
          .set({
        'page': 'detailed_design',
        'designComponents': components.map((c) => c.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveDesignComponents error: $e');
      rethrow;
    }
  }

  /// Load design components for Detailed Design page
  static Future<List<DesignComponent>> loadDesignComponents({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('detailed_design')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final componentsRaw = data['designComponents'];
      if (componentsRaw is List) {
        return componentsRaw
            .map((c) {
              try {
                return DesignComponent.fromJson(Map<String, dynamic>.from(c));
              } catch (e) {
                debugPrint('Error parsing DesignComponent: $e');
                return null;
              }
            })
            .whereType<DesignComponent>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadDesignComponents error: $e');
      return [];
    }
  }

  /// Save agile tasks for Agile Development Iterations page
  static Future<void> saveAgileTasks({
    required String projectId,
    required List<AgileTask> tasks,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('agile_development_iterations')
          .set({
        'page': 'agile_development_iterations',
        'agileTasks': tasks.map((t) => t.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveAgileTasks error: $e');
      rethrow;
    }
  }

  /// Load agile tasks for Agile Development Iterations page
  static Future<List<AgileTask>> loadAgileTasks({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('agile_development_iterations')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final tasksRaw = data['agileTasks'];
      if (tasksRaw is List) {
        return tasksRaw
            .map((t) {
              try {
                return AgileTask.fromJson(Map<String, dynamic>.from(t));
              } catch (e) {
                debugPrint('Error parsing AgileTask: $e');
                return null;
              }
            })
            .whereType<AgileTask>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadAgileTasks error: $e');
      return [];
    }
  }

  /// Save scope tracking items for Scope Tracking & Implementation page
  static Future<void> saveScopeTrackingItems({
    required String projectId,
    required List<ScopeTrackingItem> items,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('scope_tracking_implementation')
          .set({
        'page': 'scope_tracking_implementation',
        'scopeTrackingItems': items.map((i) => i.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveScopeTrackingItems error: $e');
      rethrow;
    }
  }

  /// Load scope tracking items for Scope Tracking & Implementation page
  static Future<List<ScopeTrackingItem>> loadScopeTrackingItems({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('scope_tracking_implementation')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final itemsRaw = data['scopeTrackingItems'];
      if (itemsRaw is List) {
        return itemsRaw
            .map((i) {
              try {
                return ScopeTrackingItem.fromJson(Map<String, dynamic>.from(i));
              } catch (e) {
                debugPrint('Error parsing ScopeTrackingItem: $e');
                return null;
              }
            })
            .whereType<ScopeTrackingItem>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('ExecutionPhaseService loadScopeTrackingItems error: $e');
      return [];
    }
  }

  /// Load scope statement deliverables from Front End Planning
  /// Extracts deliverables from frontEndPlanning.requirements field
  static Future<List<String>> loadScopeStatementDeliverables({
    required String projectId,
  }) async {
    try {
      // Try to load from project document's frontEndPlanning data
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();

      if (!projectDoc.exists) return [];

      final projectData = projectDoc.data() ?? {};
      final frontEndPlanning =
          projectData['frontEndPlanning'] as Map<String, dynamic>?;

      if (frontEndPlanning == null) return [];

      // Prefer structured requirement items and robust delimiter parsing first.
      final prioritizedDeliverables = <String>[];

      final requirementItems = frontEndPlanning['requirementItems'];
      if (requirementItems is List) {
        for (final item in requirementItems) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final description =
              (map['description'] ?? map['requirement'] ?? map['title'] ?? '')
                  .toString()
                  .trim();
          if (description.isNotEmpty) {
            prioritizedDeliverables.add(description);
          }
        }
      }

      final freeTextRequirements =
          frontEndPlanning['requirements']?.toString() ?? '';
      if (freeTextRequirements.trim().isNotEmpty) {
        prioritizedDeliverables.addAll(
          freeTextRequirements
              .split(RegExp(r'[\n\r,;•·\-]+'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty && item.length > 3),
        );
      }

      if (prioritizedDeliverables.isNotEmpty) {
        final seen = <String>{};
        return prioritizedDeliverables.where((item) {
          final key = item.toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).toList();
      }

      // Extract requirements which typically contains scope items
      final requirements = frontEndPlanning['requirements']?.toString() ?? '';
      if (requirements.isEmpty) return [];

      // Parse requirements into individual deliverables
      // Split by common delimiters: newlines, bullets, commas
      final deliverables = requirements
          .split(RegExp(r'[\n•,\-]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item.length > 3)
          .toList();

      return deliverables;
    } catch (e) {
      debugPrint(
          'ExecutionPhaseService loadScopeStatementDeliverables error: $e');
      return [];
    }
  }

  /// Save stakeholder alignment items for Stakeholder Alignment page
  static Future<void> saveStakeholderAlignmentItems({
    required String projectId,
    required List<StakeholderAlignmentItem> items,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('stakeholder_alignment')
          .set({
        'page': 'stakeholder_alignment',
        'stakeholderAlignmentItems': items.map((i) => i.toJson()).toList(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
          'ExecutionPhaseService saveStakeholderAlignmentItems error: $e');
      rethrow;
    }
  }

  /// Load stakeholder alignment items for Stakeholder Alignment page
  static Future<List<StakeholderAlignmentItem>> loadStakeholderAlignmentItems({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('stakeholder_alignment')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() ?? {};
      final itemsRaw = data['stakeholderAlignmentItems'];
      if (itemsRaw is List) {
        return itemsRaw
            .map((i) {
              try {
                return StakeholderAlignmentItem.fromJson(
                    Map<String, dynamic>.from(i));
              } catch (e) {
                debugPrint('Error parsing StakeholderAlignmentItem: $e');
                return null;
              }
            })
            .whereType<StakeholderAlignmentItem>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint(
          'ExecutionPhaseService loadStakeholderAlignmentItems error: $e');
      return [];
    }
  }

  /// Save risk tracking snapshot data.
  static Future<void> saveRiskTrackingSnapshot({
    required String projectId,
    required List<Map<String, dynamic>> riskItems,
    required List<Map<String, dynamic>> riskSignals,
    required List<Map<String, dynamic>> mitigationPlans,
    String? userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('risk_tracking')
          .set({
        'page': 'risk_tracking',
        'riskItems': riskItems,
        'riskSignals': riskSignals,
        'mitigationPlans': mitigationPlans,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ExecutionPhaseService saveRiskTrackingSnapshot error: $e');
      rethrow;
    }
  }

  /// Load risk tracking snapshot data.
  static Future<Map<String, dynamic>> loadRiskTrackingSnapshot({
    required String projectId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('execution_phase_entries')
          .doc('risk_tracking')
          .get();

      if (!doc.exists) return {};
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('ExecutionPhaseService loadRiskTrackingSnapshot error: $e');
      return {};
    }
  }

  /// Load core stakeholders from CoreStakeholdersData
  /// Returns a list of stakeholder name/role pairs parsed from internal and external stakeholders
  static Future<List<Map<String, String>>> loadCoreStakeholders({
    required String projectId,
  }) async {
    try {
      // Try to load from project document's coreStakeholdersData
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();

      if (!projectDoc.exists) return [];

      final projectData = projectDoc.data() ?? {};
      final coreStakeholdersData =
          projectData['coreStakeholdersData'] as Map<String, dynamic>?;

      if (coreStakeholdersData == null) return [];

      final solutionStakeholderData =
          coreStakeholdersData['solutionStakeholderData'] as List?;
      if (solutionStakeholderData == null) return [];

      final stakeholders = <Map<String, String>>[];
      final seenStakeholders = <String>{};

      for (final solutionData in solutionStakeholderData) {
        final solutionMap = solutionData as Map<String, dynamic>?;
        if (solutionMap == null) continue;

        // Parse internal stakeholders
        final internal = solutionMap['internalStakeholders']?.toString() ?? '';
        if (internal.isNotEmpty) {
          final parsed = _parseStakeholderList(internal);
          for (final stakeholder in parsed) {
            final key = '${stakeholder['name']}_${stakeholder['role']}';
            if (!seenStakeholders.contains(key)) {
              seenStakeholders.add(key);
              stakeholders.add(stakeholder);
            }
          }
        }

        // Parse external stakeholders
        final external = solutionMap['externalStakeholders']?.toString() ?? '';
        if (external.isNotEmpty) {
          final parsed = _parseStakeholderList(external);
          for (final stakeholder in parsed) {
            final key = '${stakeholder['name']}_${stakeholder['role']}';
            if (!seenStakeholders.contains(key)) {
              seenStakeholders.add(key);
              stakeholders.add(stakeholder);
            }
          }
        }

        // Parse notable stakeholders (backward compatibility)
        final notable = solutionMap['notableStakeholders']?.toString() ?? '';
        if (notable.isNotEmpty && internal.isEmpty && external.isEmpty) {
          final parsed = _parseStakeholderList(notable);
          for (final stakeholder in parsed) {
            final key = '${stakeholder['name']}_${stakeholder['role']}';
            if (!seenStakeholders.contains(key)) {
              seenStakeholders.add(key);
              stakeholders.add(stakeholder);
            }
          }
        }
      }

      return stakeholders;
    } catch (e) {
      debugPrint('ExecutionPhaseService loadCoreStakeholders error: $e');
      return [];
    }
  }

  /// Parse a bulleted list of stakeholders into name/role pairs
  /// Format: ". Name - Role" or ". Name, Role" or ". Name (Role)"
  static List<Map<String, String>> _parseStakeholderList(String text) {
    final stakeholders = <Map<String, String>>[];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      // Remove bullet prefix if present
      String cleaned = line.replaceFirst(RegExp(r'^[.\-•]\s*'), '').trim();
      cleaned = cleaned.replaceFirst(RegExp(r'^[•·]\s*'), '').trim();
      if (cleaned.isEmpty) continue;

      String name = cleaned;
      String role = '';

      // Try different patterns: "Name - Role", "Name, Role", "Name (Role)"
      if (cleaned.contains(' - ')) {
        final parts = cleaned.split(' - ');
        name = parts[0].trim();
        role = parts.length > 1 ? parts[1].trim() : '';
      } else if (cleaned.contains(', ')) {
        final parts = cleaned.split(', ');
        name = parts[0].trim();
        role = parts.length > 1 ? parts[1].trim() : '';
      } else if (cleaned.contains('(') && cleaned.contains(')')) {
        final match = RegExp(r'^(.+?)\s*\((.+?)\)').firstMatch(cleaned);
        if (match != null) {
          name = match.group(1)!.trim();
          role = match.group(2)!.trim();
        }
      }

      if (name.isNotEmpty) {
        stakeholders.add({
          'name': name,
          'role': role.isNotEmpty ? role : 'Stakeholder',
        });
      }
    }

    return stakeholders;
  }
}
