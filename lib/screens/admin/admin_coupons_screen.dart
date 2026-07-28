import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ndu_project/models/coupon_model.dart';
import 'package:ndu_project/services/coupon_service.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/navigation_context_service.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';
import 'package:ndu_project/widgets/unified_phase_header.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  String _filterBy = 'all';

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
            const Icon(Icons.local_offer, color: Color(0xFF4CAF50), size: 28),
            const SizedBox(width: 12),
            const Text('Coupon Management',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: UnifiedProfileMenu(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateCouponDialog(context),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Create Coupon',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<CouponModel>>(
                stream: CouponService.watchAllCoupons(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final allCoupons = snapshot.data ?? [];
                  final filteredCoupons = _filterCoupons(allCoupons);

                  if (filteredCoupons.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No coupons found',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _showCreateCouponDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Create your first coupon'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredCoupons.length,
                    itemBuilder: (context, index) => _CouponCard(
                      coupon: filteredCoupons[index],
                      onToggleStatus: () =>
                          _toggleCouponStatus(filteredCoupons[index]),
                      onDelete: () => _deleteCoupon(filteredCoupons[index]),
                      onEdit: () => _showEditCouponDialog(
                          context, filteredCoupons[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          const Text('Filter: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ...[
            {'label': 'All', 'value': 'all'},
            {'label': 'Active', 'value': 'active'},
            {'label': 'Inactive', 'value': 'inactive'},
            {'label': 'Expired', 'value': 'expired'},
          ].map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter['label']!),
                  selected: _filterBy == filter['value'],
                  onSelected: (selected) {
                    if (selected) setState(() => _filterBy = filter['value']!);
                  },
                  selectedColor: const Color(0xFF4CAF50),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _filterBy == filter['value']
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: _filterBy == filter['value']
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  List<CouponModel> _filterCoupons(List<CouponModel> coupons) {
    final now = DateTime.now();
    switch (_filterBy) {
      case 'active':
        return coupons
            .where((c) => c.isActive && c.validUntil.isAfter(now))
            .toList();
      case 'inactive':
        return coupons.where((c) => !c.isActive).toList();
      case 'expired':
        return coupons.where((c) => c.validUntil.isBefore(now)).toList();
      default:
        return coupons;
    }
  }

  Future<void> _showCreateCouponDialog(BuildContext context) async {
    // Capture before await to avoid use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _CouponFormDialog(),
    );

    if (!mounted) return;
    if (result == true) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Coupon created successfully'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showEditCouponDialog(
      BuildContext context, CouponModel coupon) async {
    // Capture before await to avoid use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CouponFormDialog(coupon: coupon),
    );

    if (!mounted) return;
    if (result == true) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Coupon updated successfully'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _toggleCouponStatus(CouponModel coupon) async {
    final success =
        await CouponService.toggleCouponStatus(coupon.id, !coupon.isActive);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              success ? 'Coupon status updated' : 'Failed to update coupon'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCoupon(CouponModel coupon) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Coupon',
      itemLabel: coupon.code,
    );
    if (!confirmed) return;
    final success = await CouponService.deleteCoupon(coupon.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Coupon deleted' : 'Failed to delete coupon'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onEdit,
  });

  final CouponModel coupon;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isExpired = coupon.validUntil.isBefore(DateTime.now());
    final statusColor = isExpired
        ? Colors.grey
        : coupon.isActive
            ? const Color(0xFF4CAF50)
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    coupon.code,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                        letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(isActive: coupon.isActive, isExpired: isExpired),
                const Spacer(),
                Text(
                  '${coupon.discountPercent.toStringAsFixed(0)}% OFF',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4CAF50)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(coupon.description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.calendar_today,
                    label:
                        'Valid: ${_formatDateRange(coupon.validFrom, coupon.validUntil)}'),
                const SizedBox(width: 16),
                _InfoChip(
                    icon: Icons.person,
                    label:
                        'Used: ${coupon.currentUses}${coupon.maxUses != null ? '/${coupon.maxUses}' : ''}'),
                if (coupon.applicableTiers.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  _InfoChip(
                      icon: Icons.category,
                      label: 'Tiers: ${coupon.applicableTiers.join(', ')}'),
                ],
                const Spacer(),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  color: const Color(0xFFD97706),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onToggleStatus,
                  icon: Icon(coupon.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  color: coupon.isActive ? Colors.orange : Colors.green,
                  tooltip: coupon.isActive ? 'Deactivate' : 'Activate',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime from, DateTime until) {
    final df = DateFormat('MMM d, y');
    return '${df.format(from)} - ${df.format(until)}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive, required this.isExpired});

  final bool isActive;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (isExpired) {
      label = 'EXPIRED';
      color = Colors.grey;
    } else if (isActive) {
      label = 'ACTIVE';
      color = const Color(0xFF4CAF50);
    } else {
      label = 'INACTIVE';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _CouponFormDialog extends StatefulWidget {
  const _CouponFormDialog({this.coupon});

  final CouponModel? coupon;

  @override
  State<_CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<_CouponFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountController = TextEditingController();
  final _maxUsesController = TextEditingController();

  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final Set<String> _selectedTiers = {};
  bool _isLoading = false;

  bool get isEditing => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    if (widget.coupon != null) {
      _codeController.text = widget.coupon!.code;
      _descriptionController.text = widget.coupon!.description;
      _discountController.text = widget.coupon!.discountPercent.toString();
      if (widget.coupon!.maxUses != null) {
        _maxUsesController.text = widget.coupon!.maxUses.toString();
      }
      _validFrom = widget.coupon!.validFrom;
      _validUntil = widget.coupon!.validUntil;
      _selectedTiers.addAll(widget.coupon!.applicableTiers);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer,
                        color: Color(0xFF4CAF50), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Coupon' : 'Create New Coupon',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                VoiceTextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code',
                    hintText: 'e.g., SAVE20',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !isEditing,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                VoiceTextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g., 20% off for early adopters',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount %',
                          hintText: 'e.g., 20',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Required';
                          final val = double.tryParse(v!);
                          if (val == null || val < 0 || val > 100)
                            return 'Invalid %';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: VoiceTextFormField(
                        controller: _maxUsesController,
                        decoration: const InputDecoration(
                          labelText: 'Max Uses (optional)',
                          hintText: 'Unlimited',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildDateField('Valid From', _validFrom,
                            (d) => setState(() => _validFrom = d))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildDateField('Valid Until', _validUntil,
                            (d) => setState(() => _validUntil = d))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Applicable Tiers (leave empty for all)',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['project', 'program', 'portfolio'].map((tier) {
                    final isSelected = _selectedTiers.contains(tier);
                    return FilterChip(
                      label: Text(tier.substring(0, 1).toUpperCase() +
                          tier.substring(1)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTiers.add(tier);
                          } else {
                            _selectedTiers.remove(tier);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF4CAF50),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Update' : 'Create',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
      String label, DateTime value, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(DateFormat('MMM d, y').format(value)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        final updated = widget.coupon!.copyWith(
          description: _descriptionController.text,
          discountPercent: double.parse(_discountController.text),
          maxUses: _maxUsesController.text.isEmpty
              ? null
              : int.parse(_maxUsesController.text),
          validFrom: _validFrom,
          validUntil: _validUntil,
          applicableTiers: _selectedTiers.toList(),
        );
        await CouponService.updateCoupon(updated);
      } else {
        await CouponService.createCoupon(
          code: _codeController.text,
          description: _descriptionController.text,
          discountPercent: double.parse(_discountController.text),
          validFrom: _validFrom,
          validUntil: _validUntil,
          maxUses: _maxUsesController.text.isEmpty
              ? null
              : int.parse(_maxUsesController.text),
          applicableTiers: _selectedTiers.toList(),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
