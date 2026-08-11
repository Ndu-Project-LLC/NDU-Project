import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ndu_project/utils/project_data_helper.dart';
import 'package:ndu_project/services/activity_log_service.dart';

Future<void> showInterfaceIdentificationDialog(BuildContext context) async {
  final alreadyShown = ProjectDataHelper.getData(context)
          .planningNotes['interface_identification_shown'] ==
      'true';
  if (alreadyShown) return;

  var text = 'Not Applicable';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.link, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Identify any additional internal or external interfaces not already captured within the project scope.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: TextField(
                controller: TextEditingController(text: text),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Not Applicable',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (v) => text = v,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final data = ProjectDataHelper.getData(context);
                  ProjectDataHelper.updateAndSave(
                    context: context,
                    checkpoint: 'interface_management',
                    dataUpdater: (d) => d.copyWith(
                      planningNotes: {
                        ...d.planningNotes,
                        'interface_identification_shown': 'true',
                        'additional_interfaces': text,
                      },
                    ),
                    showSnackbar: false,
                  );
                  unawaited(ActivityLogService.instance.logCheckpointActivity(
                    projectId: data.projectId ?? '',
                    checkpoint: 'interface_management',
                    action: 'Interface Identification Completed',
                    details: {'additionalInterfaces': text},
                  ));
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD24C),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );
}
