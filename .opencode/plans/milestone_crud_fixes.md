# Milestone CRUD Fixes & Refinements

## 1. Date Format Fix (project_framework_next_screen.dart)

In `_GoalCardWidgetState`, replace `_formatMilestoneDate`:

```dart
String _formatMilestoneDate(String raw) {
  final parsed = DateTime.tryParse(raw) ??
      DateFormat('MMM d, y').tryParse(raw) ??
      DateFormat('MMM dd, y').tryParse(raw);
  if (parsed == null) return raw.trim().isEmpty ? 'No date' : raw.trim();
  return _dateFormat.format(parsed);
}
```

## 2. GlobalKey Fix — Add ValueKey to milestone items

In `_GoalCardWidgetState.build`, find the `.map((milestone) {` inside the milestone list and add `key: ValueKey(milestone.id),` to the outer `Padding` widget:

```dart
return Padding(
  key: ValueKey(milestone.id),   // <-- ADD THIS
  padding: const EdgeInsets.only(bottom: 8),
  child: InkWell(
```

## 3. Remove "+" from Timeline & Table

In `_buildMilestoneTimelineSection()`, remove the `trailing:` parameter from `_CollapsibleSection(...)`.
In `_buildMilestoneTableSection()`, remove the `trailing:` parameter from `_CollapsibleSection(...)`.

## 4. Next Button Snackbar

Replace the `onPressed` in `_buildFixedFooter`:

```dart
onPressed: _reviewConfirmed
    ? _navigateToNext
    : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check the acknowledgment box above before proceeding.'),
            duration: Duration(seconds: 3),
          ),
        );
      },
```

## 5. Add label param to ReviewConfirmationCheckbox

### review_confirmation_checkbox.dart
Add optional `label` parameter:
```dart
final String? label;
```
In the Text widget: `label ?? defaultLabel`

### proceed_confirmation_gate.dart
Add optional `label` parameter, pass to `ReviewConfirmationCheckbox`:
```dart
final String? label;
```
In the build: `ReviewConfirmationCheckbox(label: widget.label, ...)`

### project_framework_next_screen.dart
Pass the label:
```dart
ProceedConfirmationGate(
  label: 'I confirm that key stakeholders have aligned on these project milestones for all goals.',
  value: _reviewConfirmed,
  onChanged: (value) => setState(() => _reviewConfirmed = value),
  padding: EdgeInsets.zero,
),
```

## 6. Rename Heading

In `_buildGoalsSection`, change `'Project Goals'` to `'Goals and Milestones'`.

## 7. AI Auto-Assign (New Method + Button)

### Add state variable
```dart
bool _isAutoAssigning = false;
```

### Add method (near `_suggestMilestonesForGoal`)
```dart
Future<void> _aiAutoAssignAllMilestones() async {
  if (_isAutoAssigning) return;
  final data = ProjectDataHelper.getData(context);
  final milestones = _sortedMilestones;
  if (milestones.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No milestones available to assign.')),
    );
    return;
  }
  final goals = List.generate(3, (i) => {
    'title': _goalTitleControllers[i].text.trim().isEmpty
        ? 'Goal ${i + 1}'
        : _goalTitleControllers[i].text.trim(),
    'description': _goalDescControllers[i].text.trim(),
  });

  setState(() => _isAutoAssigning = true);
  try {
    final prompt = '''
You are a project planning assistant. Given 3 project goals and a list of milestones, decide which milestones map to which goals.

Goals:
${goals.asMap().entries.map((e) => 'Goal ${e.key + 1}: "${e.value['title']}" - ${e.value['description']}').join('\n')}

Milestones:
${milestones.asMap().entries.map((e) => '${e.key}: "${e.value.name.trim()}" (${e.value.dueDate})').join('\n')}

Return ONLY valid JSON: {"assignments": [{"milestoneIndex": 0, "goalIndex": 0}, ...]}
A milestone can map to multiple goals. Return empty array if none match.
''';

    final response = await _openAi.generateCompletion(prompt, maxTokens: 800, temperature: 0.3);
    if (!mounted) return;

    final json = jsonDecode(response);
    final assignments = json['assignments'] as List?;
    if (assignments == null || assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI could not determine any milestone-goal mappings.')),
      );
      return;
    }

    setState(() {
      for (final a in assignments) {
        final mi = a['milestoneIndex'] as int?;
        final gi = a['goalIndex'] as int?;
        if (mi == null || gi == null || gi < 0 || gi > 2) continue;
        if (mi < 0 || mi >= milestones.length) continue;
        final id = milestones[mi].id;
        if (id.trim().isNotEmpty && !_goalMilestoneIds[gi].contains(id)) {
          _goalMilestoneIds[gi].add(id);
        }
      }
    });
    _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI auto-assigned milestones to goals.')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-assign failed: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isAutoAssigning = false);
  }
}
```

### Add "Auto-Assign" button
In `_buildGoalsSection`, near the section header, add a Row with the existing text and a new "Auto-Assign" button:

```dart
Row(
  children: [
    Expanded(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: 'Goals and Milestones', style: ...),
            TextSpan(text: ' ...', style: ...),
          ],
        ),
      ),
    ),
    TextButton.icon(
      onPressed: _isAutoAssigning ? null : _aiAutoAssignAllMilestones,
      icon: _isAutoAssigning
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.auto_awesome, size: 16),
      label: Text('Auto-Assign'),
      style: TextButton.styleFrom(foregroundColor: _kAccentColor),
    ),
  ],
),
```

## 8. Table Reposition & Restyle (Hidden by Default)

### Add state variable
```dart
bool _showMilestoneTable = false;
```

### Replace `_buildMilestoneTableSection()`
Remove `_CollapsibleSection` wrapper. Use a simple bordered container with a compact DataTable. Keep `trailing` removed (already done in step 3).

```dart
Widget _buildMilestoneTableSection() {
  final milestones = _sortedMilestones;
  return Column(
    children: [
      if (milestones.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('No milestones available yet.',
              style: TextStyle(fontSize: 13, color: _kSecondaryText)),
        )
      else
        Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 12,
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Milestone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Discipline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Mapped Goals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('References', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Comments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('', style: TextStyle(fontSize: 11))),
                ],
                rows: milestones.map((milestone) {
                  final goalLabels = _goalLabelsForMilestone(milestone.id);
                  return DataRow(cells: [
                    DataCell(GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(milestone.name.trim().isEmpty ? 'Untitled milestone' : milestone.name.trim(), style: const TextStyle(fontSize: 13)))),
                    DataCell(GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(_formatDateString(milestone.dueDate), style: const TextStyle(fontSize: 13)))),
                    DataCell(GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(milestone.discipline.trim().isEmpty ? '—' : milestone.discipline.trim(), style: const TextStyle(fontSize: 13)))),
                    DataCell(SizedBox(width: 180, child: GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(goalLabels.isEmpty ? 'Unmapped' : goalLabels.join(', '), style: const TextStyle(fontSize: 13))))),
                    DataCell(SizedBox(width: 140, child: GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(milestone.references.trim().isEmpty ? '—' : milestone.references.trim(), style: const TextStyle(fontSize: 13))))),
                    DataCell(SizedBox(width: 180, child: GestureDetector(onTap: () => _openMilestoneDialog(existing: milestone), child: Text(milestone.comments.trim().isEmpty ? '—' : milestone.comments.trim(), style: const TextStyle(fontSize: 13))))),
                    DataCell(InkWell(onTap: () => _openMilestoneDialog(existing: milestone), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF))))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
    ],
  );
}
```

### Add toggle button at bottom of `_buildGoalsSection`
After the goal cards list, before the closing `]` / `)`:

```dart
const SizedBox(height: 12),
Center(
  child: TextButton.icon(
    onPressed: () => setState(() => _showMilestoneTable = !_showMilestoneTable),
    icon: Icon(_showMilestoneTable ? Icons.table_chart : Icons.table_chart_outlined, size: 18),
    label: Text('${_showMilestoneTable ? 'Hide' : 'View'} Milestones Table (${_sortedMilestones.length})'),
    style: TextButton.styleFrom(foregroundColor: _kAccentColor),
  ),
),
if (_showMilestoneTable) _buildMilestoneTableSection(),
```

### Move table after goals in build order
In `build()`, change the section order from:
```
Notes → Context → Timeline → Table → Goals
```
to:
```
Notes → Context → Timeline → Goals → Table
```

Remove the standalone `_buildMilestoneTableSection()` call from before `_buildGoalsSection()`.

## 9. Run Analysis

```bash
dart analyze lib/screens/project_framework_next_screen.dart lib/widgets/review_confirmation_checkbox.dart lib/widgets/proceed_confirmation_gate.dart lib/widgets/milestone_edit_dialog.dart
```
