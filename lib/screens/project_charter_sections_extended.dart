import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/project_data_model.dart';
import 'package:ndu_project/screens/project_charter_sections.dart'; // For shared styles

// --- 10. Contractors ---

class CharterContractors extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterContractors({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final contractors = data!.contractors
 .where((c) => c.name.isNotEmpty || c.service.isNotEmpty)
 .toList();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('CONTRACTORS', style: kSectionTitleStyle),
 const SizedBox(height: 16),
 if (contractors.isEmpty)
 const Text('No contractors assigned.',
 style:
 TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
 if (contractors.isNotEmpty)
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: DataTable(
 headingRowHeight: 40,
 columnSpacing: 24,
 columns: const [
 DataColumn(
 label: Text('Contractor Name',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Service / Responsibility',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Est. Cost',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Status',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 ],
 rows: contractors
 .map((c) => DataRow(cells: [
 DataCell(Text(c.name,
 style: const TextStyle(
 fontWeight: FontWeight.w500))),
 DataCell(Text(c.service)),
 DataCell(Text(NumberFormat.simpleCurrency(name: 'USD')
 .format(c.estimatedCost))),
 DataCell(Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: Colors.orange.shade50,
 borderRadius: BorderRadius.circular(12),
 ),
 child: Text(c.status,
 style: TextStyle(
 fontSize: 10,
 color: Colors.orange.shade800)),
 )),
 ]))
 .toList(),
 ),
 ),
 ],
 ),
 );
 }
}

// --- 11. Vendors ---

class CharterVendors extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterVendors({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 final vendors = data!.vendors.where((v) => v.name.isNotEmpty).toList();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('VENDORS', style: kSectionTitleStyle),
 const SizedBox(height: 16),
 if (vendors.isEmpty)
 const Text('No vendors assigned.',
 style:
 TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
 if (vendors.isNotEmpty)
 SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 child: DataTable(
 headingRowHeight: 40,
 columnSpacing: 24,
 columns: const [
 DataColumn(
 label: Text('Vendor Name',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Equipment / Service',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Est. Price',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 DataColumn(
 label: Text('Stage',
 style: TextStyle(
 fontWeight: FontWeight.bold, fontSize: 12))),
 ],
 rows: vendors
 .map((v) => DataRow(cells: [
 DataCell(Text(v.name,
 style: const TextStyle(
 fontWeight: FontWeight.w500))),
 DataCell(Text(v.equipmentOrService)),
 DataCell(Text(NumberFormat.simpleCurrency(name: 'USD')
 .format(v.estimatedPrice))),
 DataCell(Text(v.procurementStage)),
 ]))
 .toList(),
 ),
 ),
 ],
 ),
 );
 }
}

// --- 12. Approvals ---

class CharterApprovals extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterApprovals({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('APPROVALS', style: kSectionTitleStyle),
 const SizedBox(height: 30),
 Container(
 padding: const EdgeInsets.all(30),
 decoration: BoxDecoration(
 border: Border.all(
 color: const Color(0xFFE5E7EB),
 width: 1), // Light gray border
 borderRadius: BorderRadius.circular(8),
 color: const Color(0xFFF9FAFB), // Very light gray bg
 ),
 child: Column(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Expanded(
 child: _buildSignatureDisplay('Project Manager',
 data!.charterProjectManagerName)),
 const SizedBox(width: 40),
 Expanded(
 child: _buildSignatureDisplay(
 'Reviewed By', data!.charterReviewedBy)),
 ],
 ),
 const SizedBox(height: 50),
 Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Expanded(
 child: _buildSignatureDisplay('Project Sponsor',
 data!.charterProjectSponsorName)),
 const SizedBox(width: 40),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Date',
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.bold,
 color: Colors.grey[500],
 letterSpacing: 1.0)),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 8),
 decoration: const BoxDecoration(
 border: Border(
 bottom: BorderSide(
 color: Color(0xFF9CA3AF), width: 1)),
 ),
 child: Text(
 data!.charterApprovalDate != null
 ? DateFormat('MMMM d, yyyy')
 .format(data!.charterApprovalDate!)
 : 'Not signed',
 style: TextStyle(
 fontSize: 16,
 color: data!.charterApprovalDate != null
 ? const Color(0xFF111827)
 : Colors.grey[400],
 fontStyle: data!.charterApprovalDate == null
 ? FontStyle.italic
 : FontStyle.normal),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildSignatureDisplay(String label, String value) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label.toUpperCase(),
 style: TextStyle(
 fontSize: 11,
 fontWeight: FontWeight.bold,
 color: Colors.grey[500],
 letterSpacing: 1.0)),
 const SizedBox(height: 8),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 8),
 decoration: const BoxDecoration(
 border:
 Border(bottom: BorderSide(color: Color(0xFF9CA3AF), width: 1)),
 ),
 child: Text(
 value.isNotEmpty ? value : 'Pending Signature',
 style: TextStyle(
 fontFamily: value.isNotEmpty
 ? 'Cursive'
 : null, // Fallback if font missing, but intent is there
 fontSize: 24,
 fontStyle: FontStyle.italic,
 color: value.isNotEmpty
 ? const Color(0xFF1E3A8A)
 : Colors
 .grey[400]), // Dark blue specifically for signatures
 ),
 ),
 ],
 );
 }
}

// --- 13. Security ---

class CharterSecurity extends StatelessWidget {
 final ProjectDataModel? data;

 const CharterSecurity({super.key, required this.data});

 @override
 Widget build(BuildContext context) {
 if (data == null) return const SizedBox();

 // Check if we have security data to show
 final secRoles = data!.frontEndPlanning.securityRoles;
 final secPerms = data!.frontEndPlanning.securityPermissions;
 final secSettings = data!.frontEndPlanning.securitySettings;

 if (secRoles.isEmpty && secPerms.isEmpty && secSettings.isEmpty) {
 // Don't show empty section for now, or show placeholder?
 // User requirement: "Verify that the Project Charter includes... Security... If Missing: Implement it."
 // So we should show the section even if empty, or at least a placeholder.
 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text('SECURITY', style: kSectionTitleStyle),
 SizedBox(height: 16),
 Text('No specific security configurations defined.',
 style:
 TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
 ],
 ),
 );
 }

 return Container(
 padding: const EdgeInsets.all(20),
 decoration: kCardDecoration,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('SECURITY & ACCESS CONTROL', style: kSectionTitleStyle),
 const SizedBox(height: 16),
 if (secRoles.isNotEmpty) ...[
 const Text('Defined Roles',
 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
 const SizedBox(height: 8),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: secRoles
 .map((r) => Chip(
 label: Text(r.name),
 backgroundColor: Colors.blue.shade50,
 labelStyle: TextStyle(
 color: Colors.blue.shade800, fontSize: 11),
 ))
 .toList(),
 ),
 const SizedBox(height: 16),
 ],
 if (secSettings.isNotEmpty) ...[
 const Text('Security Settings',
 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
 const SizedBox(height: 8),
 ...secSettings.map((s) => Padding(
 padding: const EdgeInsets.only(bottom: 4),
 child: Row(
 children: [
 Icon(Icons.lock_outline,
 size: 14, color: Colors.grey[600]),
 const SizedBox(width: 8),
 Text('${s.key}: ',
 style: const TextStyle(fontWeight: FontWeight.w500)),
 Text(s.value),
 ],
 ),
 )),
 ]
 ],
 ),
 );
 }
}
