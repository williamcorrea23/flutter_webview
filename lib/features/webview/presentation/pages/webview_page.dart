import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
      callback: (args) {
        if (args.isNotEmpty) {
          final location = args[0] as String;
          _launchExternalUrl('maps:$location');
        }
      },
    );
    
    controller.addJavaScriptHandler(
      handlerName: 'share',
      callback: (args) {
        if (args.isNotEmpty) {
          final content = args[0] as String;
          debugPrint('Share request: $content');
        }
      },
    );
    
    controller.addJavaScriptHandler(
      handlerName: 'call',
      callback: (args) {
        if (args.isNotEmpty) {
          final number = args[0] as String;
          _launchExternalUrl('tel:$number');
        }
      },
    );

    // RevenueCat integration
    controller.addJavaScriptHandler(
      handlerName: 'getOfferings',
      callback: (args) async {
        return await purchasesService.getOfferings();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'purchaseProduct',
      callback: (args) async {
        if (args.isEmpty) {
          return {'success': false, 'error': 'Product identifier is required'};
        }
        final packageId = args[0] as String;
        return await purchasesService.purchasePackage(packageId);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'restorePurchases',
      callback: (args) async {
        return await purchasesService.restorePurchases();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'getCustomerInfo',
      callback: (args) async {
        return await purchasesService.getCustomerInfo();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'isPremiumActive',
      callback: (args) async {
        return await purchasesService.isPremiumActive();
      },
    );
  }
  
  bool _handleNavigationRequest(String requestUrl) {
    final url = requestUrl.toLowerCase();
    
    // Check for external link patterns
    for (final pattern in AppConfig.externalLinkPatterns) {
      if (RegExp(pattern).hasMatch(url)) {
        _launchExternalUrl(requestUrl);
        return false; // Prevent navigation
      }
    }
    
    // Check if URL is from allowed domains
    final uri = Uri.tryParse(requestUrl);
    if (uri != null && !_isAllowedDomain(uri.host)) {
      _launchExternalUrl(requestUrl);
      return false; // Prevent navigation
    }
    
    return true; // Allow navigation
  }
  
  bool _isAllowedDomain(String host) {
    for (final domain in AppConfig.allowedDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }
  
  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Failed to launch URL: $url, Error: $e');
    }
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (connectivity) {
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
    setState(() {
      _isOffline = true;
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
    ) ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final bannerPlacement = remoteConfig.bannerPlacement;
    final showBannerAd = remoteConfig.adsEnabled && remoteConfig.bannerAdsEnabled;

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
            if (_isLoading)
              ProgressIndicatorWidget(progress: _loadingProgress),
            
            if (showBannerAd && bannerPlacement == 'top')
              const BannerAdWidget(),
            
            Expanded(
              child: _isOffline
                  ? OfflinePageWidget(onRetry: _reloadPage)
                  : InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(AppConfig.primaryUrl)),
                      initialUserScripts: UnmodifiableListView<UserScript>([
                        UserScript(
                          source: jsBridgeCode,
                          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                        ),
                      ]),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsBackForwardNavigationGestures: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        _setupJavaScriptHandlers();
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _isLoading = true;
                          _loadingProgress = 0.0;
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() {
                          _loadingProgress = progress / 100.0;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        setState(() {
                          _isLoading = false;
                          _loadingProgress = 1.0;
                        });
                        
                        // Update back button state
                        final canGoBack = await controller.canGoBack();
                        setState(() {
                          _canGoBack = canGoBack;
                        });
                        
                        // Notify ads service of navigation
                        ref.read(adsServiceProvider).onPageNavigation();
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        final request = navigationAction.request;
                        final urlString = request.url?.toString() ?? '';
                        final allowed = _handleNavigationRequest(urlString);
                        return allowed 
                            ? NavigationActionPolicy.ALLOW 
                            : NavigationActionPolicy.CANCEL;
                      },
                      onReceivedError: (controller, request, error) {
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
