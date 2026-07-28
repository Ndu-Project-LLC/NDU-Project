import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:ndu_project/routing/app_router.dart';
import 'package:ndu_project/services/user_preferences_service.dart';

/// Onboarding screen with 3 pages
/// Shown only on first app launch (native apps only)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _getStarted();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _getStarted() async {
    await UserPreferencesService.markOnboardingComplete();
    if (!mounted) return;
    context.go('/${AppRoutes.createAccount}');
  }

  void _signIn() {
    context.go('/${AppRoutes.signIn}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                ],
              ),
            ),

            // Page indicator and navigation
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 3,
                    effect: WormEffect(
                      dotColor: Colors.grey.shade300,
                      activeDotColor: const Color(0xFFFFD700),
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 16,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFFFFD700)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage == 2 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sign in link
                  TextButton(
                    onPressed: _signIn,
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 1: Concept to Launch
  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Logo
          _buildLogo(),

          const SizedBox(height: 60),

          // Illustration
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIconCircle(Icons.lightbulb_outline, Colors.orange),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      const SizedBox(width: 16),
                      _buildIconCircle(
                          Icons.design_services_outlined, Colors.blue),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      const SizedBox(width: 16),
                      _buildIconCircle(Icons.rocket_launch_outlined,
                          const Color(0xFFFFD700)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Headline
          const Text(
            'Manage Projects from\nConcept to Launch',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Supporting text
          Text(
            'Set your project up for success by capturing requirements, deciding on design, and meticulously planning all aspects.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Page 2: Stay on Schedule
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
          children: [
            const SizedBox(height: 40),

            // Logo
            _buildLogo(),

            const SizedBox(height: 60),

            // Illustration
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Timeline
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMilestone(true),
                        _buildTimelineLine(),
                        _buildMilestone(true),
                        _buildTimelineLine(),
                        _buildMilestone(false),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Team avatars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAvatar(Colors.blue),
                        const SizedBox(width: 8),
                        _buildAvatar(Colors.green),
                        const SizedBox(width: 8),
                        _buildAvatar(Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Headline
            const Text(
              'Stay on Schedule',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            // Supporting text
            const Text(
              'Track milestones and team progress in real time to ensure your launch happens on time, every time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
    );
  }

  // Page 3: Competitive Advantage
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Logo
          _buildLogo(),

          const SizedBox(height: 60),

          // Illustration
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 80,
                    color: const Color(0xFFFFD700),
                  ),
                  const SizedBox(height: 16),
                  // Growth chart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBar(40),
                      const SizedBox(width: 8),
                      _buildBar(60),
                      const SizedBox(width: 8),
                      _buildBar(80),
                      const SizedBox(width: 8),
                      _buildBar(100),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Headline
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              text: 'Deliver projects to propel your business\' ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.2,
                color: Colors.black,
              ),
              children: [
                TextSpan(
                  text: 'competitive advantage',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Subscription tier selector
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildProjectTypeChip('Regular Project', '1 user'),
              _buildProjectTypeChip('Project', 'Up to 7 users'),
              _buildProjectTypeChip('Program', 'Up to 12 users'),
              _buildProjectTypeChip('Portfolio', 'Up to 24 users'),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildLogo({bool isDark = false}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFFFFD700) : Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'NDU',
              style: TextStyle(
                color: isDark ? Colors.black : const Color(0xFFFFD700),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'NDUPROJECT',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildIconCircle(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildMilestone(bool completed) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFFFD700) : Colors.grey.shade700,
        shape: BoxShape.circle,
        border: Border.all(
          color: completed ? const Color(0xFFFFD700) : Colors.grey.shade600,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildTimelineLine() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.grey.shade700,
    );
  }

  Widget _buildAvatar(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 24,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildProjectTypeChip(String label, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
