import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/routing/app_router.dart';

/// Mobile-optimized pricing screen with vertical stacked cards
class MobilePricingScreen extends StatefulWidget {
  const MobilePricingScreen({super.key});

  @override
  State<MobilePricingScreen> createState() => _MobilePricingScreenState();
}

class _MobilePricingScreenState extends State<MobilePricingScreen> {
  bool _isAnnual = false;
  String? _selectedPlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Choose Your Plan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Billing toggle
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isAnnual
                                ? const Color(0xFFFFD700)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Monthly',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: !_isAnnual ? Colors.black : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAnnual = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isAnnual
                                ? const Color(0xFFFFD700)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Annual',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      _isAnnual ? Colors.black : Colors.black54,
                                ),
                              ),
                              if (_isAnnual)
                                const Text(
                                  'Save 20%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pricing cards
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildPricingCard(
                    title: 'Free',
                    price: '0',
                    period: 'forever',
                    features: [
                      '1 Project',
                      'Basic templates',
                      'Community support',
                      'Limited AI generations',
                    ],
                    planId: 'free',
                    isPopular: false,
                  ),
                  const SizedBox(height: 16),
                  _buildPricingCard(
                    title: 'Pro',
                    price: _isAnnual ? '16' : '20',
                    period: _isAnnual ? 'month (billed annually)' : 'month',
                    features: [
                      'Unlimited Projects',
                      'All templates',
                      'Priority support',
                      'Unlimited AI generations',
                      'Advanced analytics',
                      'Team collaboration',
                    ],
                    planId: 'pro',
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  _buildPricingCard(
                    title: 'Enterprise',
                    price: 'Custom',
                    period: 'contact sales',
                    features: [
                      'Everything in Pro',
                      'Custom integrations',
                      'Dedicated support',
                      'SLA guarantees',
                      'Advanced security',
                      'Custom training',
                    ],
                    planId: 'enterprise',
                    isPopular: false,
                  ),
                  const SizedBox(height: 80), // Space for bottom button
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selectedPlan != null
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to create account or dashboard
                  context.go('/${AppRoutes.createAccount}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selectedPlan == 'enterprise'
                      ? 'Contact Sales'
                      : 'Get Started',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required String planId,
    required bool isPopular,
  }) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700).withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (price != 'Custom')
                        const Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Features
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFFFD700),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            // Popular badge
            if (isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD700),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
