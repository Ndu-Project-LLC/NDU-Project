import 'package:flutter/material.dart';
import 'package:ndu_project/services/subscription_pricing_service.dart';

/// Admin screen for editing the subscription pricing config.
///
/// Shows all 4 tiers in a tabbed view. For each tier, the admin can edit:
/// - Label + subtitle (display only)
/// - Base monthly price + original (strikethrough) price
/// - Included users (the count covered by the base price)
/// - Maximum users (hard cap, even with add-ons)
/// - Per-role add-on monthly price for each of the 5 roles
///
/// Globals (currency, annual discount) are at the top.
///
/// Saves to Firestore at `config/subscription_pricing` on tap of the
/// Save button. A "Restore defaults" button reverts to the hardcoded
/// defaults from [TierPricingConfig.defaults].
class AdminPricingConfigScreen extends StatefulWidget {
  const AdminPricingConfigScreen({super.key});

  @override
  State<AdminPricingConfigScreen> createState() =>
      _AdminPricingConfigScreenState();
}

class _AdminPricingConfigScreenState extends State<AdminPricingConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SubscriptionPricingConfig? _config;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Controllers for global settings
  late final TextEditingController _currencyCodeController;
  late final TextEditingController _currencySymbolController;
  late final TextEditingController _annualDiscountController;

  // Per-tier controllers (one set of fields per tier)
  final Map<PricingTierId, _TierControllers> _tierControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currencyCodeController = TextEditingController();
    _currencySymbolController = TextEditingController();
    _annualDiscountController = TextEditingController();
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currencyCodeController.dispose();
    _currencySymbolController.dispose();
    _annualDiscountController.dispose();
    for (final c in _tierControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final config = await SubscriptionPricingService.load();
      _config = config;
      _syncControllersFromConfig(config);
    } catch (e) {
      _error = 'Failed to load pricing config: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncControllersFromConfig(SubscriptionPricingConfig config) {
    _currencyCodeController.text = config.currencyCode;
    _currencySymbolController.text = config.currencySymbol;
    _annualDiscountController.text =
        config.annualDiscountMultiplier.toStringAsFixed(4);

    for (final id in PricingTierId.values) {
      final tier = config.tier(id);
      final controllers =
          _tierControllers[id] ??= _TierControllers();
      controllers.label.text = tier.label;
      controllers.subtitle.text = tier.subtitle;
      controllers.monthlyPrice.text = tier.monthlyPrice.toStringAsFixed(2);
      controllers.monthlyOriginal.text =
          tier.monthlyOriginalPrice.toStringAsFixed(2);
      controllers.includedUsers.text = tier.includedUsers.toString();
      controllers.maxUsers.text = tier.maxUsers.toString();
      for (final role in PricingRoleId.values) {
        controllers.addonPrice[role]?.dispose();
        final price = tier.addonPricePerRole[role];
        controllers.addonPrice[role] =
            TextEditingController(text: (price ?? 0).toStringAsFixed(2));
      }
    }
  }

  Future<void> _save() async {
    if (_config == null) return;
    setState(() => _isSaving = true);
    try {
      final newConfig = _buildConfigFromControllers();
      await SubscriptionPricingService.save(newConfig);
      _config = newConfig;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pricing config saved.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  SubscriptionPricingConfig _buildConfigFromControllers() {
    final tiers = <PricingTierId, TierPricingConfig>{};
    for (final id in PricingTierId.values) {
      final c = _tierControllers[id]!;
      final addons = <PricingRoleId, double>{};
      for (final role in PricingRoleId.values) {
        final v = double.tryParse(c.addonPrice[role]!.text.trim()) ?? 0;
        if (v > 0) addons[role] = v;
      }
      tiers[id] = TierPricingConfig(
        id: id,
        label: c.label.text.trim().isEmpty
            ? _config!.tier(id).label
            : c.label.text.trim(),
        subtitle: c.subtitle.text.trim(),
        monthlyPrice:
            double.tryParse(c.monthlyPrice.text.trim()) ?? 0,
        monthlyOriginalPrice:
            double.tryParse(c.monthlyOriginal.text.trim()) ?? 0,
        includedUsers:
            int.tryParse(c.includedUsers.text.trim()) ?? 0,
        maxUsers: int.tryParse(c.maxUsers.text.trim()) ?? 0,
        addonPricePerRole: addons,
        features: _config!.tier(id).features,
        badgeColorArgb: _config!.tier(id).badgeColorArgb,
      );
    }
    return SubscriptionPricingConfig(
      tiers: tiers,
      currencyCode: _currencyCodeController.text.trim().isEmpty
          ? 'USD'
          : _currencyCodeController.text.trim().toUpperCase(),
      currencySymbol: _currencySymbolController.text.trim().isEmpty
          ? r'$'
          : _currencySymbolController.text.trim(),
      annualDiscountMultiplier:
          double.tryParse(_annualDiscountController.text.trim()) ??
              (11 / 12),
    );
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore defaults?'),
        content: const Text(
            'This will overwrite all current pricing with the built-in defaults. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await SubscriptionPricingService.resetToDefaults();
      _config = SubscriptionPricingConfig.defaults;
      _syncControllersFromConfig(_config!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pricing restored to defaults.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Pricing'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _restoreDefaults,
            icon: const Icon(Icons.restore),
            tooltip: 'Restore defaults',
          ),
          IconButton(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Regular Project'),
            Tab(text: 'Project'),
            Tab(text: 'Program'),
            Tab(text: 'Portfolio'),
          ],
        ),
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
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTierTab(PricingTierId.basicProject),
                    _buildTierTab(PricingTierId.project),
                    _buildTierTab(PricingTierId.program),
                    _buildTierTab(PricingTierId.portfolio),
                  ],
                ),
    );
  }

  Widget _buildTierTab(PricingTierId id) {
    final c = _tierControllers[id]!;
    final tier = _config!.tier(id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Globals section (only on first tab)
          if (id == PricingTierId.basicProject) ...[
            _sectionTitle('Global settings'),
            _globalsCard(),
            const SizedBox(height: 24),
          ],
          _sectionTitle('Tier: ${tier.label}'),
          const SizedBox(height: 12),
          _tierBasicsCard(c, tier),
          const SizedBox(height: 20),
          _sectionTitle('Per-role add-on pricing (USD / month / extra user)'),
          const SizedBox(height: 4),
          Text(
            'Additional users beyond the ${tier.includedUsers} included cost extra, by role. '
            'Set to 0 to make a role free.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          _addonPriceCard(c, tier),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _globalsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _textField(
                    label: 'Currency code',
                    hint: 'USD',
                    controller: _currencyCodeController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _textField(
                    label: 'Symbol',
                    hint: r'$',
                    controller: _currencySymbolController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _textField(
                    label: 'Annual discount (0–1)',
                    hint: '0.9167',
                    controller: _annualDiscountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Annual discount is the multiplier applied to the monthly price × 12. '
              '0.9167 means "pay for 11 months, get 12" (~1 month free).',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierBasicsCard(_TierControllers c, TierPricingConfig tier) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _textField(
                label: 'Label', hint: 'Project', controller: c.label),
            const SizedBox(height: 12),
            _textField(
                label: 'Subtitle',
                hint: 'Short marketing tagline',
                controller: c.subtitle,
                maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: 'Monthly price (USD)',
                    hint: '129.00',
                    controller: c.monthlyPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    label: 'Original (strikethrough)',
                    hint: '179.00',
                    controller: c.monthlyOriginal,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: 'Included users',
                    hint: '7',
                    controller: c.includedUsers,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    label: 'Max users (hard cap)',
                    hint: '20',
                    controller: c.maxUsers,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addonPriceCard(_TierControllers c, TierPricingConfig tier) {
    if (tier.id == PricingTierId.basicProject) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'The Regular Project tier is single-user only — add-on users are not available. '
          'Users who need more seats should upgrade to Project or higher.',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final role in PricingRoleId.values) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${_roleLabel(role)} (${_roleLevel(role)})',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _textField(
                      label: 'USD / mo',
                      hint: '0.00',
                      controller: c.addonPrice[role]!,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixText: '\$',
                    ),
                  ),
                ],
              ),
              if (role != PricingRoleId.values.last)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  String _roleLabel(PricingRoleId r) {
    switch (r) {
      case PricingRoleId.owner:
        return 'Owner';
      case PricingRoleId.admin:
        return 'Admin';
      case PricingRoleId.editor:
        return 'Editor';
      case PricingRoleId.user:
        return 'User';
      case PricingRoleId.guest:
        return 'Guest';
    }
  }

  String _roleLevel(PricingRoleId r) {
    switch (r) {
      case PricingRoleId.owner:
        return 'level 5 — full control incl. billing';
      case PricingRoleId.admin:
        return 'level 4 — user + system management';
      case PricingRoleId.editor:
        return 'level 3 — PM / content manager';
      case PricingRoleId.user:
        return 'level 2 — regular project user';
      case PricingRoleId.guest:
        return 'level 1 — view-only (usually free)';
    }
  }
}

/// Bundle of TextEditingControllers for one tier's editable fields.
class _TierControllers {
  final label = TextEditingController();
  final subtitle = TextEditingController();
  final monthlyPrice = TextEditingController();
  final monthlyOriginal = TextEditingController();
  final includedUsers = TextEditingController();
  final maxUsers = TextEditingController();
  final Map<PricingRoleId, TextEditingController> addonPrice = {};

  _TierControllers() {
    for (final role in PricingRoleId.values) {
      addonPrice[role] = TextEditingController();
    }
  }

  void dispose() {
    label.dispose();
    subtitle.dispose();
    monthlyPrice.dispose();
    monthlyOriginal.dispose();
    includedUsers.dispose();
    maxUsers.dispose();
    for (final c in addonPrice.values) {
      c.dispose();
    }
  }
}
