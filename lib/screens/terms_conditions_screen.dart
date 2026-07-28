import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/theme.dart';

class TermsConditionsScreen extends StatelessWidget {
 const TermsConditionsScreen({super.key});

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.white,
 appBar: AppBar(
 backgroundColor: Colors.white,
 elevation: 0,
 leading: IconButton(
 icon: const Icon(Icons.arrow_back, color: Colors.black87),
 onPressed: () => context.pop(),
 ),
 title: const Text(
 'Terms & Conditions',
 style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
 ),
 centerTitle: true,
 ),
 body: SafeArea(
 top: true,
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24),
 child: Center(
 child: ConstrainedBox(
 constraints: const BoxConstraints(maxWidth: 800),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(child: AppLogo(height: 80)),
 const SizedBox(height: 32),
 Center(
 child: Text(
 'Terms & Conditions',
 style: TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w700,
 color: Colors.grey[800],
 ),
 ),
 ),
 const SizedBox(height: 8),
 Center(
 child: Text(
 'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
 ),
 ),
 const SizedBox(height: 32),
 _buildSection(
 '1. Acceptance of Terms',
 'By accessing and using NDU Project ("the Platform"), you accept and agree to be bound by these Terms and Conditions and our Privacy Policy. If you do not agree to these terms, please do not use our Platform.',
 ),
 _buildSection(
 '2. Description of Service',
 '''NDU Project is a comprehensive project management platform designed to help organizations navigate, drive, and upgrade their project delivery capabilities. Our services include:

• Project planning and tracking tools
• Portfolio and program management
• Team collaboration features
• Risk and issue management
• Document management and reporting
• AI-powered project assistance''',
 ),
 _buildSection(
 '3. User Accounts',
 '''To access certain features of the Platform, you must register for an account. You agree to:

• Provide accurate, current, and complete information during registration.
• Maintain and promptly update your account information.
• Maintain the security of your password and account.
• Accept responsibility for all activities that occur under your account.
• Notify us immediately of any unauthorized use of your account.

We reserve the right to suspend or terminate accounts that violate these terms.''',
 ),
 _buildSection(
 '4. Subscription and Payments',
 '''• Subscription Plans: We offer various subscription plans with different features and pricing. Details are available on our Pricing page.
• Billing: Subscriptions are billed in advance on a monthly or annual basis, depending on your selected plan.
• Automatic Renewal: Subscriptions automatically renew unless cancelled before the renewal date.
• Refunds: Refunds are handled according to our refund policy. Generally, we do not provide refunds for partial subscription periods.
• Price Changes: We reserve the right to modify our pricing with reasonable notice to subscribers.''',
 ),
 _buildSection(
 '5. Acceptable Use',
 '''You agree not to use the Platform to:

• Violate any applicable laws or regulations.
• Infringe upon the intellectual property rights of others.
• Transmit harmful, offensive, or illegal content.
• Attempt to gain unauthorized access to our systems.
• Interfere with or disrupt the Platform's operation.
• Use automated means to access the Platform without permission.
• Impersonate any person or entity.
• Engage in any activity that could damage our reputation or business.''',
 ),
 _buildSection(
 '6. Intellectual Property',
 '''• Platform Ownership: The Platform, including its design, features, and content, is owned by NDU Project and protected by intellectual property laws.
• Your Content: You retain ownership of content you create or upload to the Platform. By using our services, you grant us a license to host, store, and display your content as necessary to provide our services.
• Feedback: Any feedback or suggestions you provide may be used by us without obligation to you.''',
 ),
 _buildSection(
 '7. Data and Privacy',
 'Your use of the Platform is also governed by our Privacy Policy, which describes how we collect, use, and protect your personal information. By using the Platform, you consent to the data practices described in the Privacy Policy.',
 ),
 _buildSection(
 '8. Third-Party Services',
 'The Platform may integrate with or contain links to third-party services. We are not responsible for the content, terms, or practices of these third-party services. Your use of such services is at your own risk.',
 ),
 _buildSection(
 '9. Disclaimer of Warranties',
 '''THE PLATFORM IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. WE DISCLAIM ALL WARRANTIES, INCLUDING:

• Merchantability and fitness for a particular purpose
• Non-infringement
• Uninterrupted or error-free operation
• Accuracy or reliability of content

We do not guarantee that the Platform will meet your specific requirements or expectations.''',
 ),
 _buildSection(
 '10. Limitation of Liability',
 'TO THE MAXIMUM EXTENT PERMITTED BY LAW, NDU PROJECT SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES.',
 ),
 _buildSection(
 '11. Indemnification',
 'You agree to indemnify, defend, and hold harmless NDU Project and its officers, directors, employees, and agents from any claims, damages, losses, liabilities, and expenses (including legal fees) arising from your use of the Platform or violation of these Terms.',
 ),
 _buildSection(
 '12. Termination',
 '''• By You: You may terminate your account at any time through your account settings.
• By Us: We may suspend or terminate your access to the Platform at any time for any reason, including violation of these Terms.
• Effect of Termination: Upon termination, your right to use the Platform ceases immediately. We may delete your data in accordance with our data retention policies.''',
 ),
 _buildSection(
 '13. Changes to Terms',
 'We reserve the right to modify these Terms at any time. We will notify you of significant changes by posting a notice on the Platform or sending you an email. Your continued use of the Platform after changes take effect constitutes acceptance of the new Terms.',
 ),
 _buildSection(
 '14. Governing Law',
 'These Terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles. Any disputes arising from these Terms shall be resolved through appropriate legal channels.',
 ),
 _buildSection(
 '15. Contact Information',
 '''If you have any questions about these Terms & Conditions, please contact us at:

Email: legal@nduproject.com
Address: NDU Project Headquarters

We will respond to your inquiry within a reasonable timeframe.''',
 ),
 const SizedBox(height: 40),
 Center(
 child: ElevatedButton(
 onPressed: () => context.pop(),
 style: ElevatedButton.styleFrom(
 backgroundColor: LightModeColors.accent,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(
 horizontal: 32, vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8)),
 ),
 child: const Text('Back',
 style: TextStyle(
 fontSize: 16, fontWeight: FontWeight.w600)),
 ),
 ),
 const SizedBox(height: 40),
 ],
 ),
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildSection(String title, String content) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 24),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Colors.grey[800],
 ),
 ),
 const SizedBox(height: 12),
 Text(
 content,
 style: TextStyle(
 fontSize: 15,
 color: Colors.grey[700],
 height: 1.6,
 ),
 ),
 ],
 ),
 );
 }
}
