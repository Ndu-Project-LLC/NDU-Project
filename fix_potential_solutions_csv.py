#!/usr/bin/env python3
"""Fix _handleSolutionCsvImport placement using line-based editing."""

with open('lib/screens/potential_solutions_screen.dart', 'r') as f:
    lines = f.readlines()

# Find the _handleSolutionCsvImport method start (line 2325)
csv_method_start = None
for i, line in enumerate(lines):
    if 'void _handleSolutionCsvImport' in line:
        csv_method_start = i
        print(f"Found _handleSolutionCsvImport at line {i+1}")
        break

if csv_method_start is None:
    print("_handleSolutionCsvImport not found!")
    exit(1)

# Find the end of _handleSolutionCsvImport (the closing brace at same indentation)
csv_method_end = None
brace_count = 0
for i in range(csv_method_start, len(lines)):
    line = lines[i]
    if '{' in line:
        brace_count += line.count('{')
    if '}' in line:
        brace_count -= line.count('}')
    if brace_count == 0 and i > csv_method_start:
        csv_method_end = i
        print(f"Found method end at line {i+1}")
        break

if csv_method_end is None:
    print("Could not find method end!")
    exit(1)

# Extract the method
csv_method_lines = lines[csv_method_start:csv_method_end+1]
print(f"Method spans lines {csv_method_start+1} to {csv_method_end+1}")

# Now find where to insert it - after _confirmDeleteSolution
# _confirmDeleteSolution ends with '}'
delete_method_end = None
brace_count = 0
# Find _confirmDeleteSolution start
for i, line in enumerate(lines):
    if '_confirmDeleteSolution' in line and 'void' in line:
        # Now find its end
        for j in range(i, len(lines)):
            if '{' in lines[j]:
                brace_count += lines[j].count('{')
            if '}' in lines[j]:
                brace_count -= lines[j].count('}')
            if brace_count == 0 and j > i:
                delete_method_end = j
                print(f"Found _confirmDeleteSolution end at line {j+1}")
                break
        break

if delete_method_end is None:
    print("Could not find _confirmDeleteSolution end!")
    exit(1)

# Remove the incorrectly placed method (lines csv_method_start to csv_method_end)
del lines[csv_method_start:csv_method_end+1]
print(f"Removed lines {csv_method_start+1} to {csv_method_end+1}")

# Adjust delete_method_end since we removed lines
delete_method_end -= (csv_method_end - csv_method_start + 1)

# Insert the method after _confirmDeleteSolution
insert_lines = [
    '\n',
    '  void _handleSolutionCsvImport(List<Map<String, String>> rows) {\n',
    '    if (_solutions.length >= 3) {\n',
    '      ScaffoldMessenger.of(context).showSnackBar(\n',
    '        const SnackBar(\n',
    '          content: Text(\'Maximum 3 solutions allowed. Please delete one first.\'),\n',
    '          duration: Duration(seconds: 2),\n',
    '        ),\n',
    '      );\n',
    '      return;\n',
    '    }\n',
    '    int imported = 0;\n',
    '    for (final row in rows) {\n',
    '      if (_solutions.length >= 3) break;\n',
    '      final title = row[\'title\'] ?? \'\';\n',
    '      final description = row[\'description\'] ?? \'\';\n',
    '      if (title.trim().isEmpty && description.trim().isEmpty) continue;\n',
    '      final created = SolutionRow(\n',
    '        number: _solutions.length + 1,\n',
    '        titleController: TextEditingController(text: title),\n',
    '        descriptionController: _createDescriptionController(text: description),\n',
    '        isAiGenerated: false,\n',
    '      );\n',
    '      _seedSolutionFieldHistory(created);\n',
    '      _solutions.add(created);\n',
    '      imported++;\n',
    '    }\n',
    '    _syncDraftToProvider();\n',
    '    setState(() {});\n',
    '    _saveSolutions();\n',
    '    if (mounted) {\n',
    '      ScaffoldMessenger.of(context).showSnackBar(\n',
    '        SnackBar(\n',
    '          content: Text(\'Imported $imported solution${imported == 1 ? \'\' : \'s\'}\'),\n',
    '          backgroundColor: const Color(0xFF059669),\n',
    '          duration: const Duration(seconds: 2),\n',
    '        ),\n',
    '      );\n',
    '    }\n',
    '  }\n',
]

lines[delete_method_end+1:delete_method_end+1] = insert_lines
print(f"Inserted method after line {delete_method_end+1}")

with open('lib/screens/potential_solutions_screen.dart', 'w') as f:
    f.writelines(lines)

print("Done!")
