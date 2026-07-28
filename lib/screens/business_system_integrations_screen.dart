import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ndu_project/services/business_system_integration_service.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';

/// Screen for connecting CRM / ERP / Accounting integrations to a program.
///
/// Shows all 12 providers grouped by category (CRM, ERP, Accounting) with
/// their connection status. Tapping a provider opens a configuration dialog
/// to enter credentials (OAuth for providers that support it, API key for
/// the rest) and toggle auto-sync.
///
/// On connect, the integration is saved to Firestore at
/// `programs/{programId}/businessIntegrations/{providerName}`. The program
/// dashboard reads these to render the aggregated roll-up card.
class BusinessSystemIntegrationsScreen extends StatefulWidget {
 const BusinessSystemIntegrationsScreen({
 super.key,
 required this.programId,
 this.programName,
 });

 final String programId;
 final String? programName;

 @override
 State<BusinessSystemIntegrationsScreen> createState() =>
 _BusinessSystemIntegrationsScreenState();
}

class _BusinessSystemIntegrationsScreenState
 extends State<BusinessSystemIntegrationsScreen> {
 List<BusinessSystemIntegration> _integrations = [];
 bool _isLoading = true;
 String? _error;

 @override
 void initState() {
 super.initState();
 _load();
 }

 Future<void> _load() async {
 setState(() {
 _isLoading = true;
 _error = null;
 });
 try {
 final list = await BusinessSystemIntegrationService.loadAll(
 widget.programId);
 if (mounted) setState(() => _integrations = list);
 } catch (e) {
 if (mounted) setState(() => _error = 'Failed to load: $e');
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 BusinessSystemIntegration? _integrationFor(BusinessSystemProvider p) {
 for (final i in _integrations) {
 if (i.provider == p) return i;
 }
 return null;
 }

 Future<void> _openConfigDialog(BusinessSystemProvider p) async {
 final existing = _integrationFor(p);
 final result = await showDialog<BusinessSystemIntegration>(
 context: context,
 builder: (ctx) => _ProviderConfigDialog(
 provider: p,
 existing: existing,
 programId: widget.programId,
 ),
 );
 if (result != null) {
 // Refresh list — the dialog already saved to Firestore.
 await _load();
 }
 }

 Future<void> _disconnect(BusinessSystemProvider p) async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: Text('Disconnect ${p.label}?'),
 content: Text(
 'This will revoke the connection and delete cached data for '
 '${p.label}. You can reconnect at any time.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel')),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.red.shade700,
 foregroundColor: Colors.white),
 child: const Text('Disconnect'),
 ),
 ],
 ),
 );
 if (confirmed != true) return;
 try {
 await BusinessSystemIntegrationService.delete(widget.programId, p);
 await _load();
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('${p.label} disconnected.'),
 behavior: SnackBarBehavior.floating,
 ),
 );
 }
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Failed to disconnect: $e'),
 backgroundColor: Colors.red.shade700),
 );
 }
 }
 }

 // ── Build ──────────────────────────────────────────────────────────────────

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 appBar: AppBar(
 title: Text(widget.programName != null
 ? 'Integrations · ${widget.programName}'
 : 'Business System Integrations'),
 backgroundColor: const Color(0xFF0F172A),
 foregroundColor: Colors.white,
 ),
 body: _isLoading
 ? const Center(child: CircularProgressIndicator())
 : _error != null
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(24),
 child: Text(_error!,
 style: const TextStyle(color: Colors.red),
 textAlign: TextAlign.center),
 ),
 )
 : RefreshIndicator(
 onRefresh: _load,
 child: ListView(
 padding: const EdgeInsets.all(20),
 children: [
 _introBanner(),
 const SizedBox(height: 24),
 _categorySection(BusinessSystemCategory.crm),
 const SizedBox(height: 24),
 _categorySection(BusinessSystemCategory.erp),
 const SizedBox(height: 24),
 _categorySection(BusinessSystemCategory.accounting),
 const SizedBox(height: 32),
 ],
 ),
 ),
 );
 }

 Widget _introBanner() {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFFFFD700).withOpacity(0.08),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
 ),
 child: Row(
 children: [
 const Icon(Icons.link, color: Color(0xFFFFD700)),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: const [
 Text(
 'Connect your business systems',
 style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
 ),
 SizedBox(height: 4),
 Text(
 'Pull customers, deals, invoices, and orders from your CRM, '
 'ERP, and accounting tools into the program dashboard for a '
 'unified roll-up.',
 style: TextStyle(fontSize: 12.5, height: 1.4),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _categorySection(BusinessSystemCategory cat) {
 final providers = BusinessSystemProvider.values
 .where((p) => p.category == cat)
 .toList();
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(
 cat.label,
 style: const TextStyle(
 fontSize: 18, fontWeight: FontWeight.w800),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 cat.description,
 style: const TextStyle(
 color: Color(0xFF64748B), fontSize: 12.5),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 12,
 runSpacing: 12,
 children: providers.map((p) => _providerCard(p)).toList(),
 ),
 ],
 );
 }

 Widget _providerCard(BusinessSystemProvider p) {
 final integration = _integrationFor(p);
 final status = integration?.status ?? IntegrationStatus.disconnected;
 final connected = status.isActive;
 return InkWell(
 onTap: () => _openConfigDialog(p),
 borderRadius: BorderRadius.circular(12),
 child: Container(
 width: 260,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: connected
 ? const Color(0xFF22C55E).withOpacity(0.4)
 : const Color(0xFFE2E8F0),
 width: connected ? 1.5 : 1),
 boxShadow: connected
 ? [
 BoxShadow(
 color: const Color(0xFF22C55E).withOpacity(0.08),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ]
 : null,
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 width: 36,
 height: 36,
 decoration: BoxDecoration(
 color: Color(p.brandColorArgb),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Center(
 child: Text(
 p.label.substring(0, 1),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w800,
 fontSize: 16),
 ),
 ),
 ),
 const Spacer(),
 _statusBadge(status),
 ],
 ),
 const SizedBox(height: 12),
 Text(
 p.label,
 style: const TextStyle(
 fontSize: 14.5, fontWeight: FontWeight.w700),
 ),
 const SizedBox(height: 4),
 Text(
 p.description,
 style: const TextStyle(
 color: Color(0xFF64748B), fontSize: 12, height: 1.4),
 ),
 const SizedBox(height: 10),
 if (connected && integration != null) ...[
 Text(
 'Last sync: ${_formatSyncTime(integration.lastSyncAt)}',
 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Icon(integration.autoSync ? Icons.sync : Icons.sync_disabled,
 size: 14, color: const Color(0xFF94A3B8)),
 const SizedBox(width: 4),
 Text(
 integration.autoSync ? 'Auto-sync on' : 'Manual sync',
 style: const TextStyle(
 fontSize: 11, color: Color(0xFF94A3B8)),
 ),
 const Spacer(),
 TextButton(
 onPressed: () => _disconnect(p),
 style: TextButton.styleFrom(
 foregroundColor: Colors.red.shade600,
 padding: const EdgeInsets.symmetric(horizontal: 8),
 minimumSize: const Size(0, 28),
 tapTargetSize: MaterialTapTargetSize.shrinkWrap),
 child: const Text('Disconnect',
 style: TextStyle(fontSize: 11)),
 ),
 ],
 ),
 ] else ...[
 Text(
 p.supportsOAuth ? 'OAuth · Connect' : 'API key · Configure',
 style: TextStyle(
 fontSize: 11.5,
 color: p.supportsOAuth
 ? const Color(0xFF16A34A)
 : const Color(0xFF0EA5E9),
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ],
 ),
 ),
 );
 }

 Widget _statusBadge(IntegrationStatus s) {
 Color c;
 String label;
 switch (s) {
 case IntegrationStatus.connected:
 c = const Color(0xFF22C55E);
 label = 'Connected';
 break;
 case IntegrationStatus.connecting:
 c = const Color(0xFFFFD700);
 label = 'Connecting';
 break;
 case IntegrationStatus.error:
 c = Colors.red.shade700;
 label = 'Error';
 break;
 case IntegrationStatus.expired:
 c = Colors.orange.shade700;
 label = 'Expired';
 break;
 case IntegrationStatus.disconnected:
 c = const Color(0xFF94A3B8);
 label = 'Not connected';
 break;
 }
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
 child: Text(label,
 style: TextStyle(
 color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
 );
 }

 String _formatSyncTime(DateTime? t) {
 if (t == null) return 'never';
 final age = DateTime.now().difference(t);
 if (age.inMinutes < 1) return 'just now';
 if (age.inMinutes < 60) return '${age.inMinutes}m ago';
 if (age.inHours < 24) return '${age.inHours}h ago';
 return '${age.inDays}d ago';
 }
}

/// Configuration dialog for one provider. Lets the user enter credentials
/// (OAuth redirect URL or API key + base URL), toggle auto-sync, and save.
class _ProviderConfigDialog extends StatefulWidget {
 const _ProviderConfigDialog({
 required this.provider,
 required this.existing,
 required this.programId,
 });

 final BusinessSystemProvider provider;
 final BusinessSystemIntegration? existing;
 final String programId;

 @override
 State<_ProviderConfigDialog> createState() => _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends State<_ProviderConfigDialog> {
 late final TextEditingController _apiKeyController;
 late final TextEditingController _baseUrlController;
 late final TextEditingController _oauthRedirectController;
 late bool _autoSync;
 bool _isSaving = false;

 @override
 void initState() {
 super.initState();
 _apiKeyController =
 TextEditingController(text: widget.existing?.apiKey ?? '');
 _baseUrlController =
 TextEditingController(text: widget.existing?.baseUrlOverride ?? '');
 _oauthRedirectController = TextEditingController();
 _autoSync = widget.existing?.autoSync ?? true;
 }

 @override
 void dispose() {
 _apiKeyController.dispose();
 _baseUrlController.dispose();
 _oauthRedirectController.dispose();
 super.dispose();
 }

 Future<void> _save() async {
 setState(() => _isSaving = true);
 try {
 final user = FirebaseAuth.instance.currentUser;
 final existing = widget.existing;
 BusinessSystemIntegration integration;
 if (existing != null) {
 integration = existing.copyWith(
 apiKey: _apiKeyController.text.trim().isEmpty
 ? null
 : _apiKeyController.text.trim(),
 baseUrlOverride: _baseUrlController.text.trim().isEmpty
 ? null
 : _baseUrlController.text.trim(),
 autoSync: _autoSync,
 status: IntegrationStatus.connected,
 lastSyncAt: DateTime.now(),
 lastSyncError: null,
 );
 } else {
 // Fresh connection
 integration = BusinessSystemIntegration(
 provider: widget.provider,
 status: IntegrationStatus.connected,
 authMethod: widget.provider.supportsOAuth
 ? AuthMethod.oauth
 : AuthMethod.apiKey,
 apiKey: _apiKeyController.text.trim().isEmpty
 ? null
 : _apiKeyController.text.trim(),
 baseUrlOverride: _baseUrlController.text.trim().isEmpty
 ? null
 : _baseUrlController.text.trim(),
 accessToken: widget.provider.supportsOAuth ? 'pending_oauth' : null,
 autoSync: _autoSync,
 lastSyncAt: DateTime.now(),
 scopes: const [],
 connectedById: user?.uid ?? '',
 connectedByEmail: user?.email ?? '',
 createdAt: DateTime.now(),
 updatedAt: DateTime.now(),
 );
 }
 await BusinessSystemIntegrationService.save(
 widget.programId, integration);
 // Seed a zero-filled snapshot so the dashboard roll-up has something
 // to render before the first real sync.
 await BusinessSystemIntegrationService.saveSnapshot(widget.programId,
 BusinessSystemSnapshot.empty(widget.provider));
 if (mounted) Navigator.pop(context, integration);
 } catch (e) {
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Save failed: $e'),
 backgroundColor: Colors.red.shade700),
 );
 }
 } finally {
 if (mounted) setState(() => _isSaving = false);
 }
 }

 @override
 Widget build(BuildContext context) {
 final p = widget.provider;
 return AlertDialog(
 title: Row(
 children: [
 Container(
 width: 32,
 height: 32,
 decoration: BoxDecoration(
 color: Color(p.brandColorArgb),
 borderRadius: BorderRadius.circular(6),
 ),
 child: Center(
 child: Text(p.label.substring(0, 1),
 style: const TextStyle(
 color: Colors.white, fontWeight: FontWeight.w800)),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Connect ${p.label}',
 style: const TextStyle(fontSize: 16)),
 Text('${p.category.label} · ${p.description}',
 style: const TextStyle(
 fontSize: 11.5, color: Color(0xFF64748B))),
 ],
 ),
 ),
 ],
 ),
 content: SizedBox(
 width: 420,
 child: SingleChildScrollView(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 mainAxisSize: MainAxisSize.min,
 children: [
 if (p.supportsOAuth) ...[
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: const Color(0xFF0EA5E9).withOpacity(0.08),
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: const Color(0xFF0EA5E9).withOpacity(0.3)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text('OAuth 2.0 redirect URL',
 style: TextStyle(
 fontSize: 12, fontWeight: FontWeight.w700)),
 const SizedBox(height: 4),
 const Text(
 'Register this URL in your provider\'s app settings, '
 'then tap Connect to launch the OAuth flow in a new tab.',
 style: TextStyle(fontSize: 11.5, height: 1.4)),
 const SizedBox(height: 8),
 VoiceTextField(
 controller: _oauthRedirectController,
 enableVoice: false,
 enableDocxImport: false,
 readOnly: true,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: Colors.white,
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(6)),
 contentPadding: const EdgeInsets.symmetric(
 horizontal: 10, vertical: 10),
 hintText:
 'https://nduproject.com/oauth/callback/${p.name}',
 hintStyle: const TextStyle(fontSize: 12),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ],
 Text('API key${p.supportsOAuth ? ' (optional, fallback)' : ' (required)'}',
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: _apiKeyController,
 enableVoice: false,
 enableDocxImport: false,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8)),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 hintText: 'Paste your ${p.label} API key',
 hintStyle: const TextStyle(fontSize: 12.5),
 ),
 ),
 const SizedBox(height: 12),
 Text('Base URL override (optional)',
 style: const TextStyle(
 fontSize: 13, fontWeight: FontWeight.w600)),
 const SizedBox(height: 6),
 VoiceTextField(
 controller: _baseUrlController,
 enableVoice: false,
 enableDocxImport: false,
 decoration: InputDecoration(
 isDense: true,
 filled: true,
 fillColor: const Color(0xFFF8FAFC),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8)),
 contentPadding:
 const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 hintText: 'e.g. https://myinstance.odoo.com',
 hintStyle: const TextStyle(fontSize: 12.5),
 ),
 ),
 const SizedBox(height: 12),
 SwitchListTile(
 value: _autoSync,
 onChanged: (v) => setState(() => _autoSync = v),
 title: const Text('Auto-sync',
 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
 subtitle: const Text(
 'Pull fresh data every hour. Off = manual sync only.',
 style: TextStyle(fontSize: 11.5)),
 contentPadding: EdgeInsets.zero,
 dense: true,
 ),
 ],
 ),
 ),
 ),
 actions: [
 TextButton(
 onPressed: _isSaving ? null : () => Navigator.pop(context),
 child: const Text('Cancel'),
 ),
 ElevatedButton(
 onPressed: _isSaving ? null : _save,
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFFFFD700),
 foregroundColor: const Color(0xFF0F172A),
 ),
 child: _isSaving
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2, color: Color(0xFF0F172A)),
 )
 : const Text('Save connection'),
 ),
 ],
 );
 }
}
