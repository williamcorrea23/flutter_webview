import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/consent_service.dart';
import '../../../../core/services/purchases_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../shared/constants/app_constants.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  /// Opens [url] outside the app, and says so when it cannot.
  ///
  /// This used to gate on `canLaunchUrl` and do nothing when it returned
  /// false, which is exactly what happened on every Android 11+ device:
  /// package visibility makes `canLaunchUrl` report false for `https` unless
  /// the manifest declares an `https` intent in <queries>, and the manifest
  /// declared tel/mailto/sms/geo/whatsapp but not https. All three links on
  /// this page were dead, silently, because the `catch` only fires on a throw.
  ///
  /// The manifest now declares https. Belt and braces, the launch is attempted
  /// unconditionally and the failure is reported from `launchUrl`'s own return
  /// value, so a future gap in <queries> is visible instead of mute.
  Future<void> _launchUrl(String url) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Name
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.aboutDescription,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version ${_packageInfo?.version ?? 'Unknown'}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Legal Notice
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legal Notice',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.legalNotice,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Links Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading:
                        Icon(Icons.privacy_tip, color: colorScheme.primary),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(AppConstants.privacyPolicyUrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.description, color: colorScheme.primary),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(AppConstants.termsOfServiceUrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.language, color: colorScheme.primary),
                    title: const Text('Visit Website'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(AppConfig.primaryUrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Privacy Controls
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.ads_click, color: colorScheme.primary),
                    title: const Text('Ad Preferences'),
                    subtitle: const Text('Manage your ad consent'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ref.read(consentServiceProvider).showPrivacyOptionsForm();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.refresh, color: colorScheme.primary),
                    title: const Text('Refresh Settings'),
                    subtitle: const Text('Update app configuration'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      await ref.read(remoteConfigServiceProvider).refresh();
                      await ref.read(adsServiceProvider).refreshAds();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings refreshed'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Master ABAP is supported by advertising and subscriptions. '
                    'Advertisements do not unlock rewards or Premium access.'),
              ),
            ),
            // Explicit diagnostic builds only; Play tracks are not detectable
            // from kReleaseMode. Never promote a diagnostic AAB to production.
            if (AppConfig.diagnosticsEnabled) ...[
              Card(
                child: ExpansionTile(
                  leading: Icon(Icons.bug_report, color: colorScheme.primary),
                  title: const Text('Diagnostics'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDebugInfo(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Footer
            Center(
              child: Text(
                'Made with ❤️ for ${AppConstants.appName}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    final adsService = ref.watch(adsServiceProvider);
    final consentService = ref.read(consentServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Environment: ${AppConfig.isDevelopment ? 'Development' : 'Production'}'),
        Text('Package: ${_packageInfo?.packageName ?? 'Unknown'}'),
        Text('Build: ${_packageInfo?.buildNumber ?? 'Unknown'}'),
        const Text('Internal diagnostic build — do not promote to production.'),
        const SizedBox(height: 8),
        const Text('Ads Service:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...adsService.getDebugInfo().entries.map(
              (entry) => SelectableText('${entry.key}: ${entry.value}'),
            ),
        const Text(
            'Test ads do not generate revenue. Do not click live ads during testing.'),
        TextButton(
          onPressed: adsService.bannerDiagnostics.state == 'loading'
              ? null
              : () => adsService.retryBanner(),
          child: const Text('Retry configured banner'),
        ),
        TextButton(
          onPressed: adsService.bannerDiagnostics.state == 'loading'
              ? null
              : () => adsService.retryBanner(useGoogleTestAd: true),
          child: const Text('Compare with Google test banner'),
        ),
        const SizedBox(height: 8),
        const Text('Consent:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Status: ${consentService.consentStatus}'),
        Text('Can Request Ads: ${consentService.canRequestAds}'),
        Text('Personalized Ads: ${consentService.isPersonalizedAdsAllowed}'),
        const SizedBox(height: 8),
        // Premium suppresses every ad (webview_page.dart). Without it here,
        // "Premium resolved true" and "ads are broken" look identical.
        const Text('Premium:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(switch (ref.watch(isPremiumProvider)) {
          AsyncData(:final value) => 'Active: $value  (ads hidden: $value)',
          AsyncError() => 'Lookup failed',
          _ => 'Checking… (ads shown until this resolves)',
        }),
      ],
    );
  }
}
