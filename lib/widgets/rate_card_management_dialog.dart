import 'package:flutter/material.dart';
import 'package:ndu_project/models/rate_card.dart';
import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/delete_confirmation_dialog.dart';

/// Dialog for managing personnel rate cards with tiered rates and role-based access.
class RateCardManagementDialog extends StatefulWidget {
  final List<RateCard> existingCards;
  final Function(List<RateCard>) onSave;

  const RateCardManagementDialog({
    super.key,
    required this.existingCards,
    required this.onSave,
  });

  /// Show the rate card management dialog
  static Future<List<RateCard>?> show(
    BuildContext context, {
    required List<RateCard> existingCards,
  }) async {
    final result = await showDialog<List<RateCard>>(
      context: context,
      builder: (context) => RateCardManagementDialog(
        existingCards: existingCards,
        onSave: (cards) => Navigator.pop(context, cards),
      ),
    );
    return result;
  }

  @override
  State<RateCardManagementDialog> createState() =>
      _RateCardManagementDialogState();
}

class _RateCardManagementDialogState extends State<RateCardManagementDialog> {
  late List<RateCard> _cards;
  int? _expandedCardIndex;
  bool _showAddForm = false;

  // New card form controllers
  final _nameCtrl = TextEditingController();
  String _selectedTier = 'National';
  final _effectiveDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();
  String _accessLevel = 'Admin';
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.existingCards);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _effectiveDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme, colorScheme),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    _buildInfoBanner(colorScheme),
                    const SizedBox(height: 16),
                    
                    // Rate cards list or empty state
                    if (_cards.isEmpty && !_showAddForm)
                      _buildEmptyState(colorScheme)
                    else ...[
                      // Cards list
                      ..._cards.asMap().entries.map((entry) =>
                          _buildRateCardCard(entry.key, entry.value, colorScheme)),
                      
                      // Add new card form
                      if (_showAddForm) _buildAddCardForm(colorScheme),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer buttons
            _buildFooter(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.attach_money, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personnel Rates Management', style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                )),
                Text('Configure tiered rates by role and region', style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rates are organized by tier: Global > Regional > National > Local. Higher tiers override lower ones.',
              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.table_chart_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No Rate Cards Configured', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface,
          )),
          const SizedBox(height: 8),
          Text('Create a rate card to define personnel costs by role and region', style: TextStyle(
            fontSize: 13, color: colorScheme.onSurfaceVariant,
          ), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => setState(() => _showAddForm = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create First Rate Card'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCardCard(int index, RateCard card, ColorScheme colorScheme) {
    final isExpanded = _expandedCardIndex == index;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpanded ? const Color(0xFFD97706) : colorScheme.outline.withOpacity(0.2)),
        boxShadow: isExpanded ? [BoxShadow(
          color: const Color(0xFFD97706).withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        )] : null,
      ),
      child: Column(
        children: [
          // Card header
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getTierColor(card.tier).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(_getTierIcon(card.tier), 
                color: _getTierColor(card.tier), size: 20)),
            ),
            title: Text(card.name.isNotEmpty ? card.name : 'Unnamed Rate Card',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(card.tier, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _getTierColor(card.tier).withOpacity(0.15),
                  side: BorderSide.none,
                ),
                const SizedBox(width: 6),
                Text('${card.rates.length} roles', style: TextStyle(fontSize: 11, 
                  color: colorScheme.onSurfaceVariant)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expandedCardIndex = isExpanded ? null : index),
                  tooltip: isExpanded ? 'Collapse' : 'Expand',
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18),
                  onSelected: (value) => _handleMenuAction(value, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                    const PopupMenuItem(value: 'add_rate', child: Text('Add Role Rate')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete'), enabled: false),
                  ],
                ),
              ],
            ),
            onTap: () => setState(() => _expandedCardIndex = isExpanded ? null : index),
          ),
          
          // Expanded content - rate table
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildRateTable(index, card, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildRateTable(int cardIndex, RateCard card, ColorScheme colorScheme) {
    if (card.rates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.money_off, size: 32, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text('No role rates defined yet', style: TextStyle(
              fontSize: 13, color: colorScheme.onSurfaceVariant,
            )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showAddRateDialog(cardIndex),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add First Role'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        border: TableBorder.all(color: colorScheme.outline.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FixedColumnWidth(44),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withOpacity(0.5)),
            children: ['Role Title', 'Discipline', 'Base Rate', 'Loaded Rate', '']
              .map((h) => Padding(
                padding: const EdgeInsets.all(10),
                child: Text(h, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11,
                  color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ))).toList(),
          ),
          ...card.rates.asMap().entries.map((entry) {
            final rate = entry.value;
            return TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text(rate.roleTitle, style: const TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(8), child: Text(rate.discipline, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))),
                Padding(padding: const EdgeInsets.all(8), child: Text('\$${rate.baseRate.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                Padding(padding: const EdgeInsets.all(8), child: Text('\$${rate.loadedRate.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669)), textAlign: TextAlign.right)),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
                    onPressed: () => _removeRate(cardIndex, entry.key),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddCardForm(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, color: const Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              const Text('New Rate Card', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showAddForm = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          VoiceTextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Rate Card Name *',
              hintText: 'e.g., Zambia National Rates 2024',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTier,
            items: const [
              DropdownMenuItem(value: 'Global', child: Text('Global - Worldwide standard rates')),
              DropdownMenuItem(value: 'Regional', child: Text('Regional - e.g., Southern Africa')),
              DropdownMenuItem(value: 'National', child: Text('National - Country-specific rates')),
              DropdownMenuItem(value: 'Local', child: Text('Local - City/area-specific rates')),
            ],
            onChanged: (v) => setState(() => _selectedTier = v ?? 'National'),
            decoration: InputDecoration(
              labelText: 'Rate Tier *',
              hintText: 'Geographic scope of this rate card',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _accessLevel,
                  items: const [
                    DropdownMenuItem(value: 'Owner', child: Text('Owner (Full Control)')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin (Can Edit)')),
                    DropdownMenuItem(value: 'Editor', child: Text('Editor (View Only)')),
                  ],
                  onChanged: (v) => setState(() => _accessLevel = v ?? 'Admin'),
                  decoration: InputDecoration(
                    labelText: 'Access Level',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveNewCard(),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Card'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _showAddForm = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Rate Card'),
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => widget.onSave(_cards),
                icon: const Icon(Icons.check, size: 18),
                label: Text('Save All (${_cards.length} cards)'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Global': return const Color(0xFF7C3AED);
      case 'Regional': return const Color(0xFFD97706);
      case 'National': return const Color(0xFF059669);
      case 'Local': return const Color(0xFFD97706);
      default: return Colors.grey;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'Global': return Icons.public;
      case 'Regional': return Icons.map;
      case 'National': return Icons.flag;
      case 'Local': return Icons.location_on;
      default: return Icons.attach_money;
    }
  }

  void _handleMenuAction(String action, int cardIndex) {
    switch (action) {
      case 'edit':
        setState(() => _expandedCardIndex = cardIndex);
        break;
      case 'add_rate':
        _showAddRateDialog(cardIndex);
        break;
      case 'duplicate':
        _duplicateCard(cardIndex);
        break;
      case 'delete':
        break;
    }
  }

  Future<void> _showAddRateDialog(int cardIndex) async {
    final card = _cards[cardIndex];
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddRateTierDialog(existingRates: card.rates),
    );
    
    if (result != null && mounted) {
      setState(() {
        final newRate = RateTier(
          roleTitle: result['roleTitle'] ?? '',
          discipline: result['discipline'] ?? '',
          baseRate: double.tryParse(result['baseRate']?.toString() ?? '0') ?? 0,
          currency: result['currency'] ?? 'USD',
          burdenMultiplier: double.tryParse(result['burdenMultiplier']?.toString() ?? '1.0') ?? 1.0,
          escalationPercent: double.tryParse(result['escalationPercent']?.toString() ?? '0') ?? 0,
          grade: result['grade'] ?? '',
          notes: result['notes'] ?? '',
        );
        
        final updatedCard = card.copyWith(rates: [...card.rates, newRate]);
        _cards[cardIndex] = updatedCard;
      });
    }
  }

  Future<void> _removeRate(int cardIndex, int rateIndex) async {
    final rate = _cards[cardIndex].rates[rateIndex];
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Delete Rate',
      itemLabel: rate.roleTitle.isNotEmpty ? rate.roleTitle : null,
    );
    if (!confirmed) return;
    setState(() {
      final card = _cards[cardIndex];
      final updatedRates = List<RateTier>.from(card.rates)..removeAt(rateIndex);
      _cards[cardIndex] = card.copyWith(rates: updatedRates);
    });
  }

  void _duplicateCard(int index) {
    final original = _cards[index];
    final duplicate = RateCard(
      name: '${original.name} (Copy)',
      tier: original.tier,
      effectiveDate: original.effectiveDate,
      expiryDate: original.expiryDate,
      rates: original.rates.map((r) => RateTier.fromJson(r.toJson())).toList(),
      createdBy: original.createdBy,
      accessLevel: original.accessLevel,
      notes: original.notes,
    );
    
    setState(() {
      _cards.insert(index + 1, duplicate);
      _expandedCardIndex = index + 1;
    });
  }

  void _saveNewCard() {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    final newCard = RateCard(
      name: _nameCtrl.text.trim(),
      tier: _selectedTier,
      effectiveDate: _effectiveDateCtrl.text.trim(),
      expiryDate: _expiryDateCtrl.text.trim(),
      accessLevel: _accessLevel,
      notes: _notesCtrl.text.trim(),
    );
    
    setState(() {
      _cards.add(newCard);
      _expandedCardIndex = _cards.length - 1;
      _showAddForm = false;
      _nameCtrl.clear();
      _notesCtrl.clear();
    });
  }
}

/// Dialog for adding a single rate tier to a rate card
class _AddRateTierDialog extends StatefulWidget {
  final List<RateTier> existingRates;
  
  const _AddRateTierDialog({required this.existingRates});

  @override
  State<_AddRateTierDialog> createState() => _AddRateTierDialogState();
}

class _AddRateTierDialogState extends State<_AddRateTierDialog> {
  final _roleCtrl = TextEditingController();
  final _disciplineCtrl = TextEditingController();
  final _baseRateCtrl = TextEditingController();
  final _burdenCtrl = TextEditingController(text: '1.35');
  final _gradeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _currency = 'USD';

  @override
  void dispose() {
    _roleCtrl.dispose();
    _disciplineCtrl.dispose();
    _baseRateCtrl.dispose();
    _burdenCtrl.dispose();
    _gradeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Role Rate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _roleCtrl, decoration: const InputDecoration(labelText: 'Role Title *', hintText: 'e.g., Project Manager')),
            const SizedBox(height: 10),
            TextField(controller: _disciplineCtrl, decoration: const InputDecoration(labelText: 'Discipline', hintText: 'e.g., Engineering, PMO')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _baseRateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Monthly Rate *', prefixText: '\$'))),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: DropdownButtonFormField<String>(
                value: _currency,
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                  DropdownMenuItem(value: 'ZMW', child: Text('ZMW')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                decoration: const InputDecoration(labelText: 'Currency'),
              )),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _burdenCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Burden Multiplier', helperText: 'e.g., 1.35 = 35% overhead')),
            const SizedBox(height: 10),
            TextField(controller: _gradeCtrl, decoration: const InputDecoration(labelText: 'Grade/Level', hintText: 'e.g., Senior, Junior, Lead')),
            const SizedBox(height: 10),
            TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_roleCtrl.text.trim().isEmpty || _baseRateCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'roleTitle': _roleCtrl.text.trim(),
              'discipline': _disciplineCtrl.text.trim(),
              'baseRate': _baseRateCtrl.text.trim(),
              'currency': _currency,
              'burdenMultiplier': _burdenCtrl.text.trim(),
              'grade': _gradeCtrl.text.trim(),
              'notes': _notesCtrl.text.trim(),
            });
          },
          child: const Text('Add Rate'),
        ),
      ],
    );
  }
}
