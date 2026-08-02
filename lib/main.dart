import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'core/config/firebase_options.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/ads_service.dart';
import 'core/services/consent_service.dart';
import 'core/services/purchases_service.dart';
import 'shared/constants/app_constants.dart';
import 'shared/theme/app_theme.dart';
import 'features/webview/presentation/pages/webview_page.dart';

void main() async {
  await _initializeApp();
  runApp(
    const ProviderScope(
      child: UsmanSandaPalaceApp(),
    ),
  );
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: AppConfig.envFileName);
  } catch (error) {
    debugPrint('Environment file unavailable: $error');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // Keep the WebView usable when optional Firebase configuration is absent.
    debugPrint('Firebase unavailable; using local defaults: $error');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}

class UsmanSandaPalaceApp extends ConsumerStatefulWidget {
  const UsmanSandaPalaceApp({super.key});

  @override
  ConsumerState<UsmanSandaPalaceApp> createState() =>
      _UsmanSandaPalaceAppState();
}

class _UsmanSandaPalaceAppState extends ConsumerState<UsmanSandaPalaceApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize consent management
      await ref.read(consentServiceProvider).initialize();

      // Initialize remote config
      await ref.read(remoteConfigServiceProvider).initialize();

      // Initialize purchases service
      await ref.read(purchasesServiceProvider).initialize();

      // Initialize ads service
      await ref.read(adsServiceProvider).initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const WebViewPage(),
    );
  }
}
