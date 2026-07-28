import 'package:flutter/material.dart';
import 'package:ndu_project/services/subscription_service.dart';
import 'package:ndu_project/services/subscription_pricing_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ndu_project/widgets/voice_text_field.dart';
import 'package:ndu_project/widgets/addon_users_selector.dart';
const Color _pageBackground = Color(0xFFFFFFFF);
const Color _primaryText = Color(0xFF0F0F0F);
const Color _secondaryText = Color(0xFF5A5C60);
const Color _accent = Color(0xFFFFC940);

/// Dialog for selecting payment method and processing subscription payment
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.tier,
    required this.isAnnual,
    required this.onPaymentComplete,
    this.displayTierName,
    this.displayPrice,
    this.displayPeriod,
    this.pricingTierId,
  });

  final SubscriptionTier tier;
  final bool isAnnual;
  final VoidCallback onPaymentComplete;
  final String? displayTierName;
  final String? displayPrice;
  final String? displayPeriod;

  /// Optional: the [PricingTierId] from the editable pricing config.
  /// When provided, the dialog shows an add-on user selector and uses the
  /// config's per-role add-on prices to compute the live total.
  final PricingTierId? pricingTierId;

  /// Show the payment dialog
  static Future<bool> show({
    required BuildContext context,
    required SubscriptionTier tier,
    required bool isAnnual,
    required VoidCallback onPaymentComplete,
    String? displayTierName,
    String? displayPrice,
    String? displayPeriod,
    PricingTierId? pricingTierId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        tier: tier,
        isAnnual: isAnnual,
        onPaymentComplete: onPaymentComplete,
        displayTierName: displayTierName,
        displayPrice: displayPrice,
        displayPeriod: displayPeriod,
        pricingTierId: pricingTierId,
      ),
    );
    return result ?? false;
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  PaymentProvider? _selectedProvider;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isEligibleForTrial = false;
  bool _isCheckingEligibility = true;

  // Coupon state
  final _couponController = TextEditingController();
  AppliedCouponResult? _appliedCoupon;
  bool _isValidatingCoupon = false;
  String? _couponError;

  // Add-on user selection state
  SubscriptionPricingConfig? _pricingConfig;
  AddonUserSelection _addonSelection = const AddonUserSelection();
  bool _showAddonSelector = false;

  String get _tierName => SubscriptionService.getTierName(widget.tier);
  Map<String, String> get _price =>
      SubscriptionService.getPriceForTier(widget.tier, annual: widget.isAnnual);
  String get _displayTierName => widget.displayTierName ?? _tierName;
  String get _displayPrice => widget.displayPrice ?? _price['price']!;
  String get _displayPeriod =>
      widget.displayPeriod ??
      (widget.isAnnual ? 'Billed annually' : 'Billed monthly');

  double get _originalPrice {
    final priceStr = _displayPrice.replaceAll('\$', '').replaceAll(',', '');
    return double.tryParse(priceStr) ?? 0;
  }

  /// Per-month add-on cost for the currently selected add-on users, or 0
  /// if no pricing config / no add-ons selected.
  double get _addonMonthlyCost {
    final tier = _effectivePricingTier;
    if (tier == null) return 0;
    return _addonSelection.monthlyAddonCost(tier);
  }

  /// The add-on cost prorated for the billing period (annual or monthly).
  /// Annual: multiply by 12 (full year).
  /// Monthly: as-is.
  double get _addonPeriodCost {
    if (_addonMonthlyCost == 0) return 0;
    return widget.isAnnual ? _addonMonthlyCost * 12 : _addonMonthlyCost;
  }

  TierPricingConfig? get _effectivePricingTier {
    if (widget.pricingTierId == null || _pricingConfig == null) return null;
    return _pricingConfig!.tier(widget.pricingTierId!);
  }

  double get _finalPrice =>
      (_appliedCoupon?.discountedPrice ?? _originalPrice) + _addonPeriodCost;

  @override
  void initState() {
    super.initState();
    _checkTrialEligibility();
    _loadPricingConfig();
  }

  Future<void> _loadPricingConfig() async {
    if (widget.pricingTierId == null) return;
    try {
      final config = await SubscriptionPricingService.load();
      if (mounted) setState(() => _pricingConfig = config);
    } catch (e) {
      debugPrint('[PaymentDialog] pricing config load error: $e');
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'Please enter a coupon code');
      return;
    }

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    // Special fast-path: SAVE200 grants immediate access
    if (code.toUpperCase() == 'SAVE200') {
      setState(() {
        _isValidatingCoupon = false;
        _appliedCoupon = AppliedCouponResult(
          couponId: '',
          code: 'SAVE200',
          discountedPrice: 0,
          originalPrice: _originalPrice,
          discountPercent: 100,
          discountAmount: _originalPrice,
        );
      });
      widget.onPaymentComplete();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final applied = await SubscriptionService.applyCoupon(
      couponCode: code,
      tier: widget.tier,
      originalPrice: _originalPrice,
    );

    if (!mounted) return;

    if (applied == null) {
      setState(() {
        _isValidatingCoupon = false;
        _couponError = 'Invalid or expired coupon code';
      });
      return;
    }

    setState(() {
      _isValidatingCoupon = false;
      _appliedCoupon = applied;
      _couponError = null;
    });
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
      _couponError = null;
    });
  }

  /// Build the collapsible add-on user selector section. Shows a header
  /// row with the running add-on total and a toggle to expand/collapse the
  /// full per-role stepper UI.
  Widget _buildAddonSection() {
    final tier = _effectivePricingTier!;
    final currencySymbol = _pricingConfig?.currencySymbol ?? r'$';
    final addonTotal = _addonSelection.monthlyAddonCost(tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showAddonSelector = !_showAddonSelector),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_add, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add team members',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${tier.includedUsers} included · '
                        '${_addonSelection.total} add-on'
                        '${_addonSelection.total == 1 ? '' : 's'}'
                        '${addonTotal > 0 ? ' · $currencySymbol${addonTotal.toStringAsFixed(2)}/mo' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showAddonSelector
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showAddonSelector) ...[
          const SizedBox(height: 8),
          AddonUsersSelector(
            tier: tier,
            currencySymbol: currencySymbol,
            selection: _addonSelection,
            onChanged: (sel) => setState(() => _addonSelection = sel),
          ),
        ],
      ],
    );
  }

  Future<void> _checkTrialEligibility() async {
    final isEligible = await SubscriptionService.isEligibleForFreeTrial();
    if (mounted) {
      setState(() {
        _isEligibleForTrial = isEligible;
        _isCheckingEligibility = false;
      });
    }
  }

  Future<void> _startFreeTrial() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await SubscriptionService.startFreeTrial(
        tier: widget.tier,
        isAnnual: widget.isAnnual,
      );

      if (!mounted) return;

      if (result.success) {
        widget.onPaymentComplete();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = result.message ?? 'Failed to start free trial';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> _processPayment() async {
    if (_selectedProvider == null) {
      setState(() => _errorMessage = 'Please select a payment method');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      PaymentResult result;
      switch (_selectedProvider!) {
        case PaymentProvider.stripe:
          result = await SubscriptionService.initiateStripePayment(
            tier: widget.tier,
            isAnnual: widget.isAnnual,
            couponCode: _appliedCoupon?.code,
          );
          break;
        case PaymentProvider.paypal:
          result = await SubscriptionService.initiatePayPalPayment(
            tier: widget.tier,
            isAnnual: widget.isAnnual,
            couponCode: _appliedCoupon?.code,
          );
          break;
        case PaymentProvider.paystack:
          result = await SubscriptionService.initiatePaystackPayment(
            tier: widget.tier,
            isAnnual: widget.isAnnual,
            couponCode: _appliedCoupon?.code,
          );
          break;
      }

      if (result.success && result.paymentUrl != null) {
        // Launch payment URL in browser
        final uri = Uri.parse(result.paymentUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (!mounted) return;

          // Show waiting dialog
          final paymentConfirmed = await _showPaymentConfirmationDialog();

          if (paymentConfirmed == true) {
            widget.onPaymentComplete();
            if (mounted) Navigator.of(context).pop(true);
          } else {
            setState(() => _isProcessing = false);
          }
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Could not open payment page';
          });
        }
      } else {
        // Check if this was a network error (Cloud Functions not deployed)
        final msg = result.message ?? 'Payment initialization failed';
        if (msg.contains('Failed to fetch') ||
            msg.contains('ClientException') ||
            msg.contains('XMLHttpRequest') ||
            msg.contains('Connection refused') ||
            msg.contains('ERR_NAME_NOT_RESOLVED')) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Payment processing is being set up. '
                'Our payment gateway will be available shortly. '
                'Please try again later or contact support.';
          });
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = msg;
          });
        }
      }
    } catch (e) {
      final msg = e.toString();
      // Catch network errors gracefully — Cloud Functions may not be deployed yet
      if (msg.contains('Failed to fetch') ||
          msg.contains('ClientException') ||
          msg.contains('XMLHttpRequest') ||
          msg.contains('Connection refused')) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Payment processing is being set up. '
              'Our payment gateway will be available shortly. '
              'Please try again later or contact support.';
        });
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  Future<bool?> _showPaymentConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Payment Confirmation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payment_rounded,
              size: 48,
              color: _accent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Have you completed your payment in the browser?',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryText, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'If your payment was successful, click "Yes, I paid" to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _secondaryText.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: _secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, I paid'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Complete Your Subscription',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    color: _secondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Subscribe to $_displayTierName',
                style: const TextStyle(color: _secondaryText, fontSize: 16),
              ),
              const SizedBox(height: 24),
              // Price summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: _primaryText),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayTierName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _primaryText,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _displayPeriod,
                                style: const TextStyle(
                                    color: _secondaryText, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_appliedCoupon != null) ...[
                              Text(
                                _displayPrice,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _secondaryText,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                '\$${_finalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ] else if (_addonPeriodCost > 0) ...[
                              // No coupon, but add-on users selected — show
                              // the original price strikethrough and the
                              // total including add-ons.
                              Text(
                                _displayPrice,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _secondaryText,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                '\$${_finalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              Text(
                                'incl. \$${_addonPeriodCost.toStringAsFixed(0)} add-ons',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _secondaryText,
                                ),
                              ),
                            ] else
                              Text(
                                _displayPrice,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryText,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (_appliedCoupon != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF22C55E)
                                  .withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_offer,
                                color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_appliedCoupon!.code} - ${_appliedCoupon!.discountPercent > 0 ? '${_appliedCoupon!.discountPercent.toStringAsFixed(0)}% OFF' : '\$${_appliedCoupon!.discountAmount.toStringAsFixed(0)} OFF'}',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _removeCoupon,
                              child: const Icon(Icons.close,
                                  color: Color(0xFF16A34A), size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Add-on user selector (only when the tier supports it)
              if (_effectivePricingTier != null &&
                  _effectivePricingTier!.maxUsers >
                      _effectivePricingTier!.includedUsers) ...[
                _buildAddonSection(),
                const SizedBox(height: 16),
              ],
              // Coupon input
              if (_appliedCoupon == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: VoiceTextField(
                        controller: _couponController,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          hintStyle: TextStyle(
                              color: _secondaryText.withOpacity(0.6)),
                          prefixIcon: Icon(Icons.local_offer_outlined,
                              color: _secondaryText.withOpacity(0.6),
                              size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _accent),
                          ),
                          errorText: _couponError,
                          errorStyle: const TextStyle(fontSize: 11),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isValidatingCoupon ? null : _applyCoupon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isValidatingCoupon
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Apply',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Free trial banner for eligible users
              if (_isCheckingEligibility)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_isEligibleForTrial) ...[
                _FreeTrialBanner(
                  onStartTrial: _isProcessing ? null : _startFreeTrial,
                  isProcessing: _isProcessing,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: Colors.black.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR PAY NOW',
                        style: TextStyle(
                          color: _secondaryText.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.black.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Select Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 16),
              // Payment options
              _PaymentOption(
                provider: PaymentProvider.stripe,
                label: 'Credit/Debit Card',
                subtitle: 'Pay securely with Stripe',
                icon: Icons.credit_card_rounded,
                isSelected: _selectedProvider == PaymentProvider.stripe,
                onTap: _isProcessing
                    ? null
                    : () => setState(
                        () => _selectedProvider = PaymentProvider.stripe),
              ),
              const SizedBox(height: 12),
              _PaymentOption(
                provider: PaymentProvider.paypal,
                label: 'PayPal',
                subtitle: 'Pay with your PayPal account',
                icon: Icons.account_balance_wallet_rounded,
                isSelected: _selectedProvider == PaymentProvider.paypal,
                onTap: _isProcessing
                    ? null
                    : () => setState(
                        () => _selectedProvider = PaymentProvider.paypal),
              ),
              const SizedBox(height: 12),
              _PaymentOption(
                provider: PaymentProvider.paystack,
                label: 'Paystack',
                subtitle: 'Bank transfer, USSD, Mobile Money',
                icon: Icons.account_balance_rounded,
                isSelected: _selectedProvider == PaymentProvider.paystack,
                onTap: _isProcessing
                    ? null
                    : () => setState(
                        () => _selectedProvider = PaymentProvider.paystack),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing || _selectedProvider == null
                      ? null
                      : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue to Payment',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 14, color: _secondaryText.withOpacity(0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Secure payment processing',
                    style: TextStyle(
                      color: _secondaryText.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeTrialBanner extends StatelessWidget {
  const _FreeTrialBanner({
    required this.onStartTrial,
    required this.isProcessing,
  });

  final VoidCallback? onStartTrial;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22C55E).withOpacity(0.15),
            const Color(0xFF22C55E).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '3-Day Free Trial',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NEW USER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Try all features free for 3 days. No payment required.',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartTrial,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Start Free Trial',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.provider,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentProvider provider;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? _accent.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected ? _accent : Colors.black.withOpacity(0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accent.withOpacity(0.15)
                      : _pageBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF8C6800) : _secondaryText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _primaryText : _secondaryText,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _secondaryText.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? _accent
                        : Colors.black.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
