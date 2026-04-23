import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Terms of Service & Privacy Policy screen.
/// Required by Apple App Store and Google Play Store.
class TermsScreen extends StatelessWidget {
  final bool isPrivacy;
  const TermsScreen({super.key, this.isPrivacy = false});

  static const _privacyUrl =
      'https://tinscars.com/privacy'; // Update with real URL
  static const _termsUrl = 'https://tinscars.com/terms'; // Update with real URL

  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Acceptance of Terms',
              'By using Ryder, you agree to these Terms of Service. If you do not agree, please do not use the app.',
            ),
            _buildSection(
              '2. Service Description',
              'Ryder is a transportation network that connects passengers with independent drivers. We do not provide transportation services directly.',
            ),
            _buildSection(
              '3. Driver Requirements',
              'Drivers must be at least 21 years old, hold a valid US driver\'s license, pass a background check, and maintain valid vehicle insurance.',
            ),
            _buildSection(
              '4. Payments',
              'Passengers pay for rides through the app. Drivers receive payment minus a service commission. Payment processing is handled by Stripe.',
            ),
            _buildSection(
              '5. Privacy',
              'We collect location data, personal information, and payment details to provide our services. See our Privacy Policy for details.',
            ),
            _buildSection(
              '6. Prohibited Activities',
              'Users may not use the app for illegal purposes, harass other users, or misrepresent their identity.',
            ),
            _buildSection(
              '7. Limitation of Liability',
              'Ryder is not liable for damages resulting from your use of the service beyond the amount you paid for the trip.',
            ),
            _buildSection(
              '8. Contact',
              'For questions about these terms, contact us at support@tinscars.com',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: Text(
                  'View Full ${isPrivacy ? 'Privacy Policy' : 'Terms'} Online',
                ),
                onPressed: () async {
                  final url = Uri.parse(isPrivacy ? _privacyUrl : _termsUrl);
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
