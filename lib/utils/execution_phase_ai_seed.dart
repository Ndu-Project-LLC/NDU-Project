import 'package:flutter/material.dart';
import 'package:ndu_project/services/openai_service_secure.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/widgets/launch_editable_section.dart';

class ExecutionPhaseAiSeed {
  const ExecutionPhaseAiSeed._();

  static String buildContext(BuildContext context, {required String section}) {
    final data = ProjectDataHelper.getData(context);
    var contextText = ProjectDataHelper.buildExecutivePlanContext(
      data,
      sectionLabel: section,
    );
    if (contextText.trim().isEmpty) {
      contextText = ProjectDataHelper.buildProjectContextScan(
        data,
        sectionLabel: section,
      );
    }
    return contextText.trim();
  }

  static Future<Map<String, List<LaunchEntry>>> generateEntries({
    required BuildContext context,
    required String section,
    required Map<String, String> sections,
    int itemsPerSection = 3,
  }) async {
    final contextText = buildContext(context, section: section);
    if (contextText.isEmpty) return {};

    final ai = OpenAiServiceSecure();
    final result = await ai.generateLaunchPhaseEntries(
      context: contextText,
      sections: sections,
      itemsPerSection: itemsPerSection,
    );

    final mapped = <String, List<LaunchEntry>>{};
    for (final entry in result.entries) {
      mapped[entry.key] = entry.value
          .map(
            (item) => LaunchEntry(
              title: item['title']?.toString() ?? '',
              details: item['details']?.toString() ?? '',
              status: item['status']?.toString(),
            ),
          )
          .where((item) => item.title.trim().isNotEmpty)
          .toList();
    }
    return mapped;
  }
}
