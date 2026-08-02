import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/services/purchases_service.dart';
import '../../../../shared/constants/app_constants.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/progress_indicator_widget.dart';
import '../widgets/offline_page_widget.dart';
import '../../../about/presentation/pages/about_page.dart';

class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({super.key});

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  InAppWebViewController? _webViewController;
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool _isLoading = true;
  bool _isOffline = false;
  double _loadingProgress = 0.0;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _setupJavaScriptHandlers() {
    final controller = _webViewController;
    if (controller == null) return;

    final purchasesService = ref.read(purchasesServiceProvider);

    // Legacy app commands
    controller.addJavaScriptHandler(
      handlerName: 'openMaps',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) return;
        final location = _stringArgument(args);
        if (location != null) {
          _launchExternalUrl(Uri(scheme: 'geo', query: location).toString());
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'share',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) return;
        final content = _stringArgument(args);
        if (content != null) {
          await Share.share(content);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'call',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) return;
        final number = _stringArgument(args);
        if (number != null &&
            RegExp(r'^[0-9+()\-\s]{3,32}$').hasMatch(number)) {
          _launchExternalUrl(Uri(scheme: 'tel', path: number).toString());
        }
      },
    );

    // RevenueCat integration
    controller.addJavaScriptHandler(
      handlerName: 'getOfferings',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) return [];
        return await purchasesService.getOfferings();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'purchaseProduct',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) {
          return {'success': false, 'error': 'Untrusted WebView origin'};
        }
        final packageId = _stringArgument(args);
        if (packageId == null) {
          return {'success': false, 'error': 'Product identifier is required'};
        }
        return await purchasesService.purchasePackage(packageId);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'restorePurchases',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) {
          return {'success': false, 'error': 'Untrusted WebView origin'};
        }
        return await purchasesService.restorePurchases();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getCustomerInfo',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) {
          return {'success': false, 'error': 'Untrusted WebView origin'};
        }
        return await purchasesService.getCustomerInfo();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'isPremiumActive',
      callback: (args) async {
        if (!await _isTrustedBridgeContext()) return false;
        return await purchasesService.isPremiumActive();
      },
    );
  }

  String? _stringArgument(List<dynamic> args) {
    if (args.length != 1 || args.first is! String) return null;
    final value = (args.first as String).trim();
    return value.isEmpty || value.length > 512 ? null : value;
  }

  Future<bool> _isTrustedBridgeContext() async {
    final uri = await _webViewController?.getUrl();
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        _isAllowedDomain(uri.host);
  }

  bool _handleNavigationRequest(String requestUrl) {
    final uri = Uri.tryParse(requestUrl);
    if (uri == null || uri.scheme.isEmpty) return false;

    final scheme = uri.scheme.toLowerCase();
    final url = requestUrl.toLowerCase();

    if (scheme == 'https' && _isAllowedDomain(uri.host)) {
      return true;
    }

    if (scheme == 'http' && _isAllowedDomain(uri.host)) {
      _launchExternalUrl(uri.replace(scheme: 'https').toString());
      return false;
    }

    // Check for external link patterns
    for (final pattern in AppConfig.externalLinkPatterns) {
      if (RegExp(pattern).hasMatch(url)) {
        _launchExternalUrl(requestUrl);
        return false; // Prevent navigation
      }
    }

    if (scheme == 'http' || scheme == 'https') {
      _launchExternalUrl(requestUrl);
      return false; // Prevent navigation
    }

    return false;
  }

  bool _isAllowedDomain(String host) {
    final normalizedHost = host.toLowerCase();
    for (final domain in AppConfig.allowedDomains) {
      final normalizedDomain = domain.toLowerCase();
      if (normalizedHost == normalizedDomain ||
          normalizedHost.endsWith('.$normalizedDomain')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('No application can handle URL: $url');
      }
    } catch (e) {
      debugPrint('Failed to launch URL: $url, Error: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (connectivity) {
        if (!mounted) return;
        final isConnected = connectivity != ConnectivityResult.none;

        if (isConnected && _isOffline) {
          _reloadPage();
        }

        setState(() {
          _isOffline = !isConnected;
        });
      },
    );
  }

  void _handleWebViewError() {
    if (!mounted) return;
    setState(() {
      _isOffline = true;
      _isLoading = false;
    });
  }

  Future<void> _reloadPage() async {
    final controller = _webViewController;
    if (controller == null) return;

    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      await controller.reload();
    } catch (e) {
      debugPrint('Failed to reload page: $e');
      if (!mounted) return;
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  Future<bool> _handleBackPress() async {
    final controller = _webViewController;
    if (controller != null && _canGoBack) {
      await controller.goBack();
      return false; // Don't exit app
    }

    // On Android, show exit confirmation
    if (Platform.isAndroid) {
      return await _showExitConfirmation();
    }

    return false; // Don't exit on iOS
  }

  Future<bool> _showExitConfirmation() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final bannerPlacement = remoteConfig.bannerPlacement;
    final showBannerAd =
        remoteConfig.adsEnabled && remoteConfig.bannerAdsEnabled;

    const jsBridgeCode = '''
      window.NativeApp = {
        openMaps: function(location) {
          window.flutter_inappwebview.callHandler('openMaps', location);
        },
        share: function(content) {
          window.flutter_inappwebview.callHandler('share', content);
        },
        call: function(number) {
          window.flutter_inappwebview.callHandler('call', number);
        },
        getOfferings: function() {
          return window.flutter_inappwebview.callHandler('getOfferings');
        },
        purchaseProduct: function(productId) {
          return window.flutter_inappwebview.callHandler('purchaseProduct', productId);
        },
        restorePurchases: function() {
          return window.flutter_inappwebview.callHandler('restorePurchases');
        },
        getCustomerInfo: function() {
          return window.flutter_inappwebview.callHandler('getCustomerInfo');
        },
        isPremiumActive: function() {
          return window.flutter_inappwebview.callHandler('isPremiumActive');
        }
      };
    ''';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleBackPress();
          if (shouldPop && context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadPage,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'about':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                    break;
                  case 'refresh_config':
                    ref.read(remoteConfigServiceProvider).refresh();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'about',
                  child: Text('About'),
                ),
                const PopupMenuItem(
                  value: 'refresh_config',
                  child: Text('Refresh Config'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading) ProgressIndicatorWidget(progress: _loadingProgress),
            if (showBannerAd && bannerPlacement == 'top')
              const BannerAdWidget(),
            Expanded(
              child: _isOffline
                  ? OfflinePageWidget(onRetry: _reloadPage)
                  : InAppWebView(
                      initialUrlRequest:
                          URLRequest(url: WebUri(AppConfig.primaryUrl)),
                      initialUserScripts: UnmodifiableListView<UserScript>([
                        UserScript(
                          source: jsBridgeCode,
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                        ),
                      ]),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        javaScriptCanOpenWindowsAutomatically: false,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsBackForwardNavigationGestures: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        _setupJavaScriptHandlers();
                      },
                      onLoadStart: (controller, url) {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = true;
                          _loadingProgress = 0.0;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() {
                          _loadingProgress = progress / 100.0;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = false;
                          _loadingProgress = 1.0;
                        });

                        // Update back button state
                        final canGoBack = await controller.canGoBack();
                        if (!mounted) return;
                        setState(() {
                          _canGoBack = canGoBack;
                        });

                        // Notify ads service of navigation
                        ref.read(adsServiceProvider).onPageNavigation();
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        if (!navigationAction.isForMainFrame) {
                          return NavigationActionPolicy.ALLOW;
                        }
                        final request = navigationAction.request;
                        final urlString = request.url?.toString() ?? '';
                        final allowed = _handleNavigationRequest(urlString);
                        return allowed
                            ? NavigationActionPolicy.ALLOW
                            : NavigationActionPolicy.CANCEL;
                      },
                      onReceivedError: (controller, request, error) {
                        if (request.isForMainFrame != true) return;
                        debugPrint('WebView error: ${error.description}');
                        _handleWebViewError();
                      },
                    ),
            ),
            if (showBannerAd && bannerPlacement == 'bottom')
              const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
