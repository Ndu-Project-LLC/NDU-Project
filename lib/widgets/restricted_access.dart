import 'package:flutter/material.dart';
import 'package:ndu_project/services/access_policy.dart';
import 'package:ndu_project/services/auth_nav.dart';

/// A themed screen shown when access is restricted based on host/email policy.
class RestrictedAccessScreen extends StatelessWidget {
  const RestrictedAccessScreen({super.key, required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = AccessPolicy.currentHost();
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        top: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: theme.colorScheme.error, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Access restricted',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This environment (${host.isEmpty ? 'admin' : host}) is restricted to nduproject.com accounts or the designated admin.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_circle_outlined),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email == null || email!.isEmpty
                                        ? 'Signed in (no email available)'
                                        : email!,
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.public),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    host.isEmpty
                                        ? 'admin.nduproject.com'
                                        : host,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please sign out and sign back in using your @nduproject.com email, or contact your administrator for access.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => AuthNav.signOutAndExit(context),
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
