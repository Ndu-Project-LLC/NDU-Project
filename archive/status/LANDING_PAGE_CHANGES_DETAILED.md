# Detailed Changes to Landing Page - Terms, Privacy Policy, and FAQ

## Overview
This document provides a comprehensive description of all changes made to the landing page (`lib/screens/landing_screen.dart`) to add FAQ, Terms and Conditions, and Privacy Policy sections. The Terms and Privacy Policy are implemented as popup dialogs for a cleaner UI, while FAQ remains as an expandable section on the page.

---

## 1. MAIN LAYOUT CHANGES

### File: `lib/screens/landing_screen.dart`

#### 1.1 Update Main ScrollView Children
**Location**: In the `build` method, within the `SingleChildScrollView`'s `Column` children (around line 254-270)

**Change**: Add FAQ section call, remove full Terms and Privacy sections from main scroll

**Before**:
```dart
SizedBox(height: isDesktop ? 80 : 56),
_buildCTASection(context, isDesktop),
_buildFooter(context),
```

**After**:
```dart
SizedBox(height: isDesktop ? 80 : 56),
_buildCTASection(context, isDesktop),
SizedBox(height: isDesktop ? 80 : 56),
_buildFAQSection(context, isDesktop),
_buildFooter(context),
```

**Note**: The Terms and Privacy sections are NO LONGER called here. They are now accessed via popup dialogs from footer links.

---

## 2. FAQ SECTION IMPLEMENTATION

### 2.1 Add `_buildFAQSection` Method
**Location**: Add as a new method in `_LandingScreenState` class (around line 2305)

**Implementation**:
```dart
Widget _buildFAQSection(BuildContext context, bool isDesktop) {
  return _FAQSectionWidget(isDesktop: isDesktop);
}
```

This method returns a separate StatefulWidget to manage the FAQ expandable state.

### 2.2 Create `_FAQSectionWidget` StatefulWidget
**Location**: Add as a new class after `_LandingScreenState` class ends (around line 2904)

**Full Implementation**:
```dart
class _FAQSectionWidget extends StatefulWidget {
  const _FAQSectionWidget({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_FAQSectionWidget> createState() => _FAQSectionWidgetState();
}

class _FAQSectionWidgetState extends State<_FAQSectionWidget> {
  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FAQItem(
        question: 'What is NDU Project?',
        answer:
            'NDU Project is a comprehensive project delivery platform that enables organizations to save money on projects through robust planning, integrated design, and flawless execution. It combines front-end planning, risk intelligence, team collaboration, and AI-powered copilot capabilities.',
      ),
      _FAQItem(
        question: 'How does KAZ AI Copilot work?',
        answer:
            'KAZ AI Copilot is an intelligent assistant that helps project teams with real-time insights, risk identification, and decision support. It analyzes project data, identifies potential issues, and provides actionable recommendations to keep projects on track.',
      ),
      _FAQItem(
        question: 'What project methodologies are supported?',
        answer:
            'NDU Project supports multiple project methodologies including Agile, Waterfall, and Hybrid approaches. The platform is flexible and can be adapted to your organization\'s preferred project management framework.',
      ),
      _FAQItem(
        question: 'Is my data secure?',
        answer:
            'Yes, security is a top priority. We implement industry-standard security measures including encryption, secure authentication, and regular security audits. Your project data is protected and only accessible to authorized team members.',
      ),
      _FAQItem(
        question: 'Can I integrate with existing tools?',
        answer:
            'NDU Project is designed to integrate with common project management and collaboration tools. Contact our team to discuss specific integration requirements for your organization.',
      ),
      _FAQItem(
        question: 'What kind of support is available?',
        answer:
            'We offer comprehensive support including expert consultation, customer service, and access to templates and resources. You can book a consultation session with our experts to optimize your project outcomes.',
      ),
    ];

    return Container(
      key: const ValueKey('faq_section'),
      padding: EdgeInsets.symmetric(
          horizontal: widget.isDesktop ? 96 : 28,
          vertical: widget.isDesktop ? 80 : 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: widget.isDesktop ? 48 : 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Find answers to common questions about NDU Project',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 48),
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            final isExpanded = expandedIndex == index;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      expandedIndex = expanded ? index : null;
                    });
                  },
                  children: [
                    Text(
                      faq.answer,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.78),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

**Key Features**:
- Uses `ExpansionTile` for expandable FAQ items
- Tracks `expandedIndex` to show only one expanded item at a time
- Responsive padding based on `isDesktop`
- Dark theme styling matching the landing page
- 6 FAQ items with questions and detailed answers

---

## 3. TERMS AND CONDITIONS - POPUP DIALOG IMPLEMENTATION

### 3.1 Add `_buildTermsContent` Method
**Location**: Add as a new method in `_LandingScreenState` class (around line 2309)

**Full Implementation**:
```dart
Widget _buildTermsContent(bool isDesktop) {
  final terms = [
    _TermsSection(
      title: '1. Acceptance of Terms',
      content:
          'By accessing and using NDU Project, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
    ),
    _TermsSection(
      title: '2. Use License',
      content:
          'Permission is granted to temporarily use NDU Project for personal or commercial project management purposes. This is the grant of a license, not a transfer of title, and under this license you may not: modify or copy the materials; use the materials for any commercial purpose or for any public display; attempt to reverse engineer any software contained in NDU Project; remove any copyright or other proprietary notations from the materials.',
    ),
    _TermsSection(
      title: '3. User Accounts',
      content:
          'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account or password. You must notify us immediately of any unauthorized use of your account.',
    ),
    _TermsSection(
      title: '4. Service Availability',
      content:
          'We strive to ensure that NDU Project is available 24/7, but we do not guarantee uninterrupted access. We reserve the right to modify, suspend, or discontinue any part of the service at any time with or without notice.',
    ),
    _TermsSection(
      title: '5. Data and Privacy',
      content:
          'Your use of NDU Project is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices regarding the collection and use of your data.',
    ),
    _TermsSection(
      title: '6. Intellectual Property',
      content:
          'All content, features, and functionality of NDU Project, including but not limited to text, graphics, logos, and software, are the exclusive property of NDU Project and are protected by international copyright, trademark, and other intellectual property laws.',
    ),
    _TermsSection(
      title: '7. Limitation of Liability',
      content:
          'In no event shall NDU Project or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use NDU Project, even if NDU Project or an authorized representative has been notified orally or in writing of the possibility of such damage.',
    ),
    _TermsSection(
      title: '8. Modifications',
      content:
          'NDU Project may revise these terms of service at any time without notice. By using this service you are agreeing to be bound by the then current version of these terms of service.',
    ),
    _TermsSection(
      title: '9. Contact Information',
      content:
          'If you have any questions about these Terms and Conditions, please contact us at contact@nduproject.com or Phone (US): +1 (832) 228-3510.',
    ),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: terms.map((term) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              term.content,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.78),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
```

### 3.2 Add `_showTermsAndConditionsDialog` Method
**Location**: Add as a new method in `_LandingScreenState` class, before `_buildFooter` method (around line 2751)

**Full Implementation**:
```dart
void _showTermsAndConditionsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF040404),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: ${DateTime.now().year}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildTermsContent(true),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Key Features**:
- Dialog with transparent background
- Max width 800px, max height 600px
- Dark theme (Color(0xFF040404)) matching landing page
- Header with title, "Last updated" date, and close button
- Scrollable content area
- Rounded corners (20px) with subtle border

---

## 4. PRIVACY POLICY - POPUP DIALOG IMPLEMENTATION

### 4.1 Add `_buildPrivacyContent` Method
**Location**: Add as a new method in `_LandingScreenState` class (around line 2390)

**Full Implementation**:
```dart
Widget _buildPrivacyContent(bool isDesktop) {
  final privacySections = [
    _PrivacySection(
      title: '1. Information We Collect',
      content:
          'We collect information that you provide directly to us, including: account registration information (name, email, company), project data and content you create or upload, communication data when you contact us, and usage data about how you interact with our platform.',
    ),
    _PrivacySection(
      title: '2. How We Use Your Information',
      content:
          'We use the information we collect to: provide, maintain, and improve our services, process transactions and send related information, send technical notices and support messages, respond to your comments and questions, monitor and analyze trends and usage, and detect, prevent, and address technical issues.',
    ),
    _PrivacySection(
      title: '3. Information Sharing and Disclosure',
      content:
          'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances: with your consent, to comply with legal obligations, to protect our rights and safety, with service providers who assist us in operating our platform (under strict confidentiality agreements), and in connection with a business transfer or merger.',
    ),
    _PrivacySection(
      title: '4. Data Security',
      content:
          'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. This includes encryption, secure authentication, regular security audits, and access controls. However, no method of transmission over the Internet is 100% secure.',
    ),
    _PrivacySection(
      title: '5. Data Retention',
      content:
          'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law. When you delete your account, we will delete or anonymize your personal information, subject to certain exceptions.',
    ),
    _PrivacySection(
      title: '6. Your Rights and Choices',
      content:
          'You have the right to: access and receive a copy of your personal data, rectify inaccurate or incomplete data, request deletion of your personal data, object to processing of your personal data, request restriction of processing, and data portability. You can exercise these rights by contacting us at contact@nduproject.com.',
    ),
    _PrivacySection(
      title: '7. Cookies and Tracking Technologies',
      content:
          'We use cookies and similar tracking technologies to track activity on our platform and hold certain information. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent. However, if you do not accept cookies, you may not be able to use some portions of our service.',
    ),
    _PrivacySection(
      title: '8. Third-Party Services',
      content:
          'Our platform may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to read the privacy policies of any third-party services you access.',
    ),
    _PrivacySection(
      title: '9. Children\'s Privacy',
      content:
          'NDU Project is not intended for individuals under the age of 18. We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal information, please contact us immediately.',
    ),
    _PrivacySection(
      title: '10. Changes to This Privacy Policy',
      content:
          'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.',
    ),
    _PrivacySection(
      title: '11. Contact Us',
      content:
          'If you have any questions about this Privacy Policy, please contact us at: Email: contact@nduproject.com, Phone (US): +1 (832) 228-3510.',
    ),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: privacySections.map((section) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              section.content,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.78),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
```

### 4.2 Add `_showPrivacyPolicyDialog` Method
**Location**: Add as a new method in `_LandingScreenState` class, right after `_showTermsAndConditionsDialog` (around line 2820)

**Full Implementation**:
```dart
void _showPrivacyPolicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF040404),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: ${DateTime.now().year}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NDU Project ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our platform.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.78),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPrivacyContent(true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Key Features**:
- Same dialog structure as Terms and Conditions
- Includes introductory paragraph before the numbered sections
- 11 privacy policy sections
- Scrollable content
- Close button in header

---

## 5. FOOTER CHANGES - ADD LINKS AND CENTER THEM

### 5.1 Update Footer to Add Terms and Privacy Policy Links
**Location**: In `_buildFooter` method, within the footer's bottom section (around line 2676-2742)

**Find**: The section that contains the copyright text and footer pills (contact info)

**Change**: Add a new section AFTER the copyright text with centered Terms and Privacy Policy links

**Specific Location**: After this Row:
```dart
Row(
  children: [
    Expanded(
      child: Text(
        '© 2025 NDU Project. Engineered for leaders building the next wave of critical programs.',
        style: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 13),
      ),
    ),
  ],
),
```

**Add After** (with `const SizedBox(height: 12)` before it):
```dart
const SizedBox(height: 12),
Center(
  child: Wrap(
    spacing: 16,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => _showTermsAndConditionsDialog(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Terms and Conditions',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withOpacity(0.7),
          ),
        ),
      ),
      Text(
        '•',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
        ),
      ),
      TextButton(
        onPressed: () => _showPrivacyPolicyDialog(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    ],
  ),
),
```

**Key Features**:
- Wrapped in `Center` widget to center horizontally
- Uses `Wrap` with `alignment: WrapAlignment.center` for proper centering
- TextButtons with underline decoration
- Separated by bullet point (•)
- Calls dialog methods on press
- Styled to match footer (white with opacity)

---

## 6. DATA CLASSES - ADD SUPPORTING CLASSES

### 6.1 Add Data Classes at End of File
**Location**: Add at the end of the file, after all other helper classes (around line 3824)

**Add these three classes**:
```dart
class _FAQItem {
  const _FAQItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _TermsSection {
  const _TermsSection({required this.title, required this.content});

  final String title;
  final String content;
}

class _PrivacySection {
  const _PrivacySection({required this.title, required this.content});

  final String title;
  final String content;
}
```

---

## 7. ADDITIONAL FIXES - COMPILATION ERRORS

### 7.1 Fix `lib/screens/cost_analysis_screen.dart`
**Location**: Line 5647 in `_SolutionCostContext` class

**Change**: Initialize `timelineIndex` field
```dart
// Before:
int timelineIndex;

// After:
int timelineIndex = 1;
```

### 7.2 Fix `lib/screens/front_end_planning_risks_screen.dart`
**Location**: Line 995 in `_LabeledField` class constructor

**Change**: Add `hintText` parameter to constructor
```dart
// Before:
const _LabeledField({
  required this.label,
  required this.controller,
  this.autofocus = false,
  this.enabled = true,
});

// After:
const _LabeledField({
  required this.label,
  required this.controller,
  this.hintText,
  this.autofocus = false,
  this.enabled = true,
});
```

### 7.3 Fix `lib/screens/program_basics_screen.dart`
**Location**: Line 331 in `_CircularNavButton` class constructor

**Change**: Add `onTap` parameter to constructor
```dart
// Before:
const _CircularNavButton({
  required this.icon,
  required this.background,
  required this.borderColor,
  required this.iconColor,
});

// After:
const _CircularNavButton({
  required this.icon,
  required this.background,
  required this.borderColor,
  required this.iconColor,
  this.onTap,
});
```

### 7.4 Fix `.github/workflows/azure-static-web-apps-gray-ground-02206d21e.yml`
**Location**: Line 46 in the `close_pull_request_job` step

**Change**: Add `app_location` parameter
```yaml
# Before:
- name: Close Pull Request
  id: closepullrequest
  uses: Azure/static-web-apps-deploy@v1
  with:
    azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_GRAY_GROUND_02206D21E }}
    action: "close"

# After:
- name: Close Pull Request
  id: closepullrequest
  uses: Azure/static-web-apps-deploy@v1
  with:
    azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_GRAY_GROUND_02206D21E }}
    action: "close"
    app_location: "/" # App source code path
```

---

## SUMMARY OF CHANGES

### Landing Page (`lib/screens/landing_screen.dart`):
1. ✅ Added FAQ section with 6 expandable questions (remains on page)
2. ✅ Removed full Terms and Conditions section from main scroll
3. ✅ Removed full Privacy Policy section from main scroll
4. ✅ Added Terms and Conditions popup dialog method
5. ✅ Added Privacy Policy popup dialog method
6. ✅ Added footer links (centered) to open dialogs
7. ✅ Added 3 data classes: `_FAQItem`, `_TermsSection`, `_PrivacySection`
8. ✅ Created `_FAQSectionWidget` StatefulWidget for FAQ state management

### Other Files:
1. ✅ Fixed `cost_analysis_screen.dart` - initialized `timelineIndex = 1`
2. ✅ Fixed `front_end_planning_risks_screen.dart` - added `hintText` parameter
3. ✅ Fixed `program_basics_screen.dart` - added `onTap` parameter
4. ✅ Fixed Azure workflow - added `app_location` parameter

### UI/UX Improvements:
- Cleaner landing page (no long legal text sections)
- FAQ remains visible and accessible
- Terms and Privacy accessible via footer links
- Popup dialogs provide focused reading experience
- Centered footer links for better visual balance
- Responsive design maintained
- Dark theme consistency throughout

---

## IMPLEMENTATION ORDER

1. First, add the data classes at the end of the file
2. Add `_buildFAQSection` method
3. Add `_FAQSectionWidget` StatefulWidget class
4. Add `_buildTermsContent` method
5. Add `_buildPrivacyContent` method
6. Add `_showTermsAndConditionsDialog` method
7. Add `_showPrivacyPolicyDialog` method
8. Update main scroll view to include FAQ section
9. Update footer to add centered links
10. Fix compilation errors in other files
11. Fix Azure workflow file

---

## TESTING CHECKLIST

After implementation, verify:
- [ ] FAQ section appears on landing page after CTA section
- [ ] FAQ items expand/collapse individually
- [ ] Footer shows "Terms and Conditions" and "Privacy Policy" links centered
- [ ] Clicking "Terms and Conditions" opens popup dialog
- [ ] Clicking "Privacy Policy" opens popup dialog
- [ ] Dialogs are scrollable
- [ ] Close button (X) works in both dialogs
- [ ] No compilation errors
- [ ] Responsive on mobile and desktop
- [ ] Dark theme consistency maintained

