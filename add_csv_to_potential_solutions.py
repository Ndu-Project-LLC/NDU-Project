#!/usr/bin/env python3
"""Add CSV import to Potential Solutions screen - attempt 2 with correct strings."""
with open('lib/screens/potential_solutions_screen.dart', 'r') as f:
    lines = f.readlines()

# 1. Replace the Align widget (lines 1632-1640) with Row containing CsvTableImportButton
# Lines 1632-1640 (0-indexed: 1631-1639)
old_align = ''.join(lines[1631:1640])
print(f"Old Align text found: {'Align(' in old_align}")

new_row = """        Row(
              children: [
                CsvTableImportButton(
                  tableTitle: 'Potential Solutions',
                  columns: _solutionCsvColumns,
                  onImport: (rows) => _handleSolutionCsvImport(rows),
                  compact: true,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isLoadingSolutions ? null : _addManualSolution,
                  icon: const Icon(Icons.add),
                  label: Text('Add Solution (${_solutions.length}/3)'),
                ),
              ],
            ),"""

lines[1631:1640] = [new_row + '\n']
print("CsvTableImportButton replaced: SUCCESS")

# 2. Find the _addManualSolution method end and add _handleSolutionCsvImport after it
# The method ends at line 2290 (0-indexed: 2289) with '  }\n'
# Find the exact line
for i, line in enumerate(lines):
    if 'await _saveSolutions();' in line and i > 2280:
        # The next line should be '  }\n'
        end_idx = i + 1
        print(f"Found _addManualSolution end at line {end_idx + 1}")
        break

csv_import_method = """
  void _handleSolutionCsvImport(List<Map<String, String>> rows) {
    if (_solutions.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 solutions allowed. Please delete one first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    int imported = 0;
    for (final row in rows) {
      if (_solutions.length >= 3) break;
      final title = row['title'] ?? '';
      final description = row['description'] ?? '';
      if (title.trim().isEmpty && description.trim().isEmpty) continue;
      final created = SolutionRow(
        number: _solutions.length + 1,
        titleController: TextEditingController(text: title),
        descriptionController: _createDescriptionController(text: description),
        isAiGenerated: false,
      );
      _solutions.add(created);
      imported++;
    }
    _syncDraftToProvider();
    setState(() {});
    _saveSolutions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $imported solution${imported == 1 ? '' : 's'}'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
"""

lines.insert(end_idx, csv_import_method)
print("_handleSolutionCsvImport added: SUCCESS")

with open('lib/screens/potential_solutions_screen.dart', 'w') as f:
    f.writelines(lines)

print("Done!")
