import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/user_model.dart';
import 'package:ndu_project/services/user_service.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class AdminSubscriptionLookupScreen extends StatefulWidget {
  const AdminSubscriptionLookupScreen({super.key});

  @override
  State<AdminSubscriptionLookupScreen> createState() =>
      _AdminSubscriptionLookupScreenState();
}

class _AdminSubscriptionLookupScreenState
    extends State<AdminSubscriptionLookupScreen> {
  final _searchController = TextEditingController();
  UserModel? _selectedUser;
  List<Subscription> _subscriptions = [];
  List<Invoice> _invoices = [];
  bool _isSearching = false;
  bool _isLoadingSubscriptions = false;
  bool _isLoadingInvoices = false;
  List<UserModel> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NavigationContextService.instance
        .setLastAdminDashboard(AppRoutes.adminHome);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF2196F3), size: 28),
            const SizedBox(width: 12),
            const Text('Subscription Lookup',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UnifiedProfileMenu(compact: true),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchSection(),
              if (_searchResults.isNotEmpty && _selectedUser == null) ...[
                const SizedBox(height: 16),
                _buildSearchResults(),
              ],
              if (_selectedUser != null) ...[
                const SizedBox(height: 24),
                _buildSelectedUserCard(),
                const SizedBox(height: 24),
                _buildSubscriptionsSection(),
                const SizedBox(height: 24),
                _buildInvoiceHistorySection(),
                const SizedBox(height: 24),
                _buildActionsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Search by email or name to view subscription details',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: VoiceTextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter email or name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Search',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Search Results (${_searchResults.length})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          ...ListTile.divideTiles(
            context: context,
            tiles: _searchResults.map((user) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFC107).withOpacity(0.2),
                    child: Text(user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : 'U'),
                  ),
                  title: Text(user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(user.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectUser(user),
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUserCard() {
    if (_selectedUser == null) return const SizedBox.shrink();
    final user = _selectedUser!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    if (user.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(user.email,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Joined ${DateFormat('MMM d, y').format(user.createdAt)}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedUser = null;
              _subscriptions = [];
              _invoices = [];
            }),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.credit_card, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            const Text('Subscription History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_isLoadingSubscriptions)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 16),
        if (_subscriptions.isEmpty && !_isLoadingSubscriptions)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.credit_card_off,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No subscriptions found',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('This user has not subscribed to any plan',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          )
        else
          ...List.generate(
              _subscriptions.length,
              (index) =>
                  _SubscriptionCard(subscription: _subscriptions[index])),
      ],
    );
  }

  Widget _buildInvoiceHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF9C27B0)),
            const SizedBox(width: 8),
            const Text('Invoice History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_isLoadingInvoices)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 16),
        if (_invoices.isEmpty && !_isLoadingInvoices)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No invoices found',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('This user has no payment history',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          )
        else
          ...List.generate(_invoices.length,
              (index) => _InvoiceCard(invoice: _invoices[index])),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                icon: Icons.add_card,
                label: 'Grant Subscription',
                color: const Color(0xFF4CAF50),
                onPressed: () => _showGrantSubscriptionDialog(),
              ),
              _ActionButton(
                icon: Icons.card_giftcard,
                label: 'Extend Trial',
                color: const Color(0xFFFFC107),
                onPressed: () => _showExtendTrialDialog(),
              ),
              _ActionButton(
                icon: Icons.cancel,
                label: 'Cancel Subscription',
                color: Colors.red,
                onPressed: _hasActiveSubscription
                    ? () => _showCancelSubscriptionDialog()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasActiveSubscription => _subscriptions.any((s) => s.isActive);

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _selectedUser = null;
      _subscriptions = [];
    });

    try {
      final results = await UserService.searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectUser(UserModel user) async {
    setState(() {
      _selectedUser = user;
      _searchResults = [];
      _isLoadingSubscriptions = true;
      _isLoadingInvoices = true;
    });

    try {
      final subscriptions = await _loadUserSubscriptions(user.uid);
      setState(() => _subscriptions = subscriptions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading subscriptions: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoadingSubscriptions = false);
    }

    // Load invoices
    try {
      final invoices = await SubscriptionService.getInvoiceHistory(
        userId: user.uid,
        userEmail: user.email,
      );
      setState(() => _invoices = invoices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading invoices: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoadingInvoices = false);
    }
  }

  Future<List<Subscription>> _loadUserSubscriptions(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Subscription.fromJson(doc.data()))
        .toList();
  }

  Future<void> _showGrantSubscriptionDialog() async {
    if (_selectedUser == null) return;

    SubscriptionTier? selectedTier;
    bool isAnnual = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Grant Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grant a subscription to ${_selectedUser!.displayName}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<SubscriptionTier>(
                initialValue: selectedTier,
                decoration: const InputDecoration(
                  labelText: 'Subscription Tier',
                  border: OutlineInputBorder(),
                ),
                items: SubscriptionTier.values
                    .map((tier) => DropdownMenuItem(
                          value: tier,
                          child: Text(SubscriptionService.getTierName(tier)),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedTier = v),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Annual subscription'),
                value: isAnnual,
                onChanged: (v) => setDialogState(() => isAnnual = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedTier == null
                  ? null
                  : () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50)),
              child: const Text('Grant', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedTier != null) {
      await _grantSubscription(selectedTier!, isAnnual);
    }
  }

  Future<void> _grantSubscription(SubscriptionTier tier, bool isAnnual) async {
    if (_selectedUser == null) return;

    try {
      final now = DateTime.now();
      final endDate = isAnnual
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30));

      final docRef =
          FirebaseFirestore.instance.collection('subscriptions').doc();
      await docRef.set({
        'id': docRef.id,
        'userId': _selectedUser!.uid,
        'tier': tier.name,
        'status': 'active',
        'provider': 'admin_granted',
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'isAnnual': isAnnual,
        'isTrial': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Subscription granted successfully'),
              backgroundColor: Colors.green),
        );
        await _selectUser(_selectedUser!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showExtendTrialDialog() async {
    if (_selectedUser == null) return;

    int daysToExtend = 7;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Extend Trial'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Extend trial for ${_selectedUser!.displayName}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: daysToExtend,
                decoration: const InputDecoration(
                  labelText: 'Days to extend',
                  border: OutlineInputBorder(),
                ),
                items: [3, 7, 14, 30]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d days'),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => daysToExtend = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107)),
              child:
                  const Text('Extend', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _extendTrial(daysToExtend);
    }
  }

  Future<void> _extendTrial(int days) async {
    if (_selectedUser == null) return;

    try {
      // Find active trial or create a new one
      final existingTrial = _subscriptions
          .where((s) => s.isTrial && s.status == SubscriptionStatus.trial)
          .firstOrNull;

      if (existingTrial != null) {
        final newEndDate = (existingTrial.trialEndDate ?? DateTime.now())
            .add(Duration(days: days));
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(existingTrial.id)
            .update({
          'trialEndDate': Timestamp.fromDate(newEndDate),
          'endDate': Timestamp.fromDate(newEndDate),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        // Create a new trial
        final now = DateTime.now();
        final endDate = now.add(Duration(days: days));
        final docRef =
            FirebaseFirestore.instance.collection('subscriptions').doc();
        await docRef.set({
          'id': docRef.id,
          'userId': _selectedUser!.uid,
          'tier': 'project',
          'status': 'trial',
          'provider': 'admin_granted',
          'startDate': Timestamp.fromDate(now),
          'endDate': Timestamp.fromDate(endDate),
          'trialEndDate': Timestamp.fromDate(endDate),
          'isTrial': true,
          'isAnnual': false,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Trial extended successfully'),
              backgroundColor: Colors.green),
        );
        await _selectUser(_selectedUser!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCancelSubscriptionDialog() async {
    if (_selectedUser == null) return;

    final activeSubscription =
        _subscriptions.where((s) => s.isActive).firstOrNull;
    if (activeSubscription == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text(
            'Are you sure you want to cancel the subscription for ${_selectedUser!.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(activeSubscription.id)
            .update({
          'status': 'cancelled',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Subscription cancelled'),
                backgroundColor: Colors.green),
          );
          await _selectUser(_selectedUser!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (subscription.status) {
      SubscriptionStatus.active => const Color(0xFF4CAF50),
      SubscriptionStatus.trial => const Color(0xFFFFC107),
      SubscriptionStatus.cancelled => Colors.red,
      SubscriptionStatus.expired => Colors.grey,
      SubscriptionStatus.pending => Colors.orange,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.credit_card, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        SubscriptionService.getTierName(subscription.tier),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          subscription.status.name.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor),
                        ),
                      ),
                      if (subscription.isTrial) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('TRIAL',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFC107))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provider: ${subscription.provider.name}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Period: ${DateFormat('MMM d, y').format(subscription.startDate)} - ${subscription.endDate != null ? DateFormat('MMM d, y').format(subscription.endDate!) : 'Ongoing'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey : color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        invoice.isPaid ? const Color(0xFF4CAF50) : Colors.orange;
    final providerIcon = switch (invoice.provider.toLowerCase()) {
      'stripe' => Icons.credit_card,
      'paypal' => Icons.payment,
      'paystack' => Icons.account_balance,
      'admin_granted' => Icons.admin_panel_settings,
      _ => Icons.receipt,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF9C27B0).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(providerIcon, color: const Color(0xFF9C27B0), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        invoice.formattedAmount,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          invoice.isPaid
                              ? 'PAID'
                              : invoice.status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Via ${invoice.providerDisplayName}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, y').format(invoice.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (invoice.receiptUrl != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Color(0xFF9C27B0)),
                tooltip: 'View Receipt',
                onPressed: () {
                  // Open receipt URL in new tab
                  // Using url_launcher would be ideal but for web we can use dart:html
                },
              ),
          ],
        ),
      ),
    );
  }
}
