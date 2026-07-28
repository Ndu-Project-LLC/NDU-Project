import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ndu_project/widgets/app_logo.dart';
import 'package:ndu_project/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
 const PrivacyPolicyScreen({super.key});

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
 'Privacy Policy',
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
 'Privacy Policy',
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
 '1. Introduction',
 'Welcome to NDU Project. We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our project management platform.',
 ),
 _buildSection(
 '2. Information We Collect',
 '''We collect information that you provide directly to us, including:

• Personal Information: Name, email address, company name, and contact details when you create an account.
• Project Data: Project details, team information, schedules, documents, and other content you upload or create within the platform.
• Usage Data: Information about how you interact with our platform, including features used, pages visited, and actions taken.
• Device Information: Browser type, operating system, IP address, and device identifiers.''',
 ),
 _buildSection(
 '3. How We Use Your Information',
 '''We use the information we collect to:

• Provide, maintain, and improve our project management services.
• Process and complete transactions, and send related information.
• Send administrative messages, updates, and security alerts.
• Respond to your comments, questions, and customer service requests.
• Analyze usage patterns to improve user experience and platform performance.
• Protect against unauthorized access and maintain platform security.''',
 ),
 _buildSection(
 '4. Data Storage and Security',
 '''Your data is stored securely using industry-standard encryption and security protocols. We use Firebase and other trusted cloud services to ensure data integrity and availability. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.''',
 ),
 _buildSection(
 '5. Data Sharing and Disclosure',
 '''We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:

• With your consent or at your direction.
• With service providers who assist us in operating our platform.
• To comply with legal obligations or respond to lawful requests.
• To protect our rights, privacy, safety, or property.
• In connection with a merger, acquisition, or sale of assets.''',
 ),
 _buildSection(
 '6. Your Rights and Choices',
 '''You have the right to:

• Access, update, or delete your personal information.
• Opt-out of receiving promotional communications.
• Request a copy of your data in a portable format.
• Withdraw consent where processing is based on consent.
• Lodge a complaint with a supervisory authority.

To exercise these rights, please contact us using the information provided below.''',
 ),
 _buildSection(
 '7. Data Retention',
 'We retain your personal information for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required by law. When you delete your account, we will delete or anonymize your personal information within a reasonable timeframe.',
 ),
 _buildSection(
 '8. Children\'s Privacy',
 'Our platform is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.',
 ),
 _buildSection(
 '9. International Data Transfers',
 'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information in accordance with applicable data protection laws.',
 ),
 _buildSection(
 '10. Changes to This Policy',
 'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
 ),
 _buildSection(
 '11. Contact Us',
 '''If you have any questions about this Privacy Policy or our data practices, please contact us at:

Email: privacy@nduproject.com
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
