import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'core/config/firebase_options.dart';
import 'core/services/ads_service.dart';
import 'core/services/consent_service.dart';
import 'core/services/identity_sync_service.dart';
import 'core/services/purchases_service.dart';
import 'core/services/remote_config_service.dart';
import 'features/webview/presentation/pages/webview_page.dart';
import 'shared/constants/app_constants.dart';
import 'shared/theme/app_theme.dart';

/// Explicit ProductionFilter, and not for style.
///
/// `Logger()` defaults to `DevelopmentFilter`, whose own doc comment reads "In
/// release mode ALL logs are omitted" — it decides inside an `assert`, so it
/// is hard-wired to false once asserts are off. Every crash funnelled here
/// would therefore have been dropped in exactly the builds that ship, which
/// would have made the error handling below decorative.
final _logger = Logger(filter: ProductionFilter());

void main() {
  // Same trap, everywhere else: every service holds a bare `Logger()`. Their
  // fields are lazy, so raising the default here — before anything constructs
  // one — is what actually makes their warnings survive a release build.
  Logger.defaultFilter = ProductionFilter.new;

  // runZonedGuarded, not a bare await, so that an error thrown out of any
  // async callback the app ever schedules — a bridge handler, an ad listener,
  // a Firebase future nobody awaited — lands in [_reportFatal] instead of
  // vanishing. Before this, release builds reported nothing at all: every
  // failure path in this file logged through debugPrint, which is a no-op once
  // asserts are off.
  runZonedGuarded(
    () async {
      await _initializeApp();
      runApp(
        const ProviderScope(
          child: MasterAbapApp(),
        ),
      );
    },
    (error, stack) => _reportFatal('Uncaught zone error', error, stack),
  );
}

/// The single place crashes are funnelled through.
///
/// Wiring a reporter (Crashlytics, Sentry) means adding the call here and
/// nothing else — every framework, platform and zone error already arrives at
/// this function.
void _reportFatal(String context, Object error, StackTrace stack) {
  _logger.e('$context: $error', error: error, stackTrace: stack);
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build, layout and paint errors. Without this they print to the console in
  // debug and are swallowed in release.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    _reportFatal(
      details.context?.toString() ?? 'Flutter framework error',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  // Async errors that never reach a Flutter callback (platform channels,
  // isolate-level failures).
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportFatal('Unhandled platform error', error, stack);
    return true;
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    // Keep the WebView usable when optional Firebase configuration is absent.
    // Reported rather than printed: on a device where this fails, sign-in and
    // Remote Config are both dead, and that is worth knowing about.
    _reportFatal('Firebase unavailable; using local defaults', error, stack);
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

class MasterAbapApp extends ConsumerStatefulWidget {
  const MasterAbapApp({super.key});

  @override
  ConsumerState<MasterAbapApp> createState() => _MasterAbapAppState();
}

class _MasterAbapAppState extends ConsumerState<MasterAbapApp> {
  @override
  void initState() {
    super.initState();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    // Each service is initialized on its own so that one failure does not skip
    // the rest. A single try/catch around all four meant a consent timeout
    // silently cost the app its Remote Config, its purchases and its ads.
    await _initialize('consent', () => ref.read(consentServiceProvider).initialize());
    await _initialize('remote config', () => ref.read(remoteConfigServiceProvider).initialize());
    await _initialize('purchases', () => ref.read(purchasesServiceProvider).initialize());
    await _initialize('ads', () => ref.read(adsServiceProvider).initialize());

    if (!mounted) return;
    // Reading the provider is what starts it; it listens to authStateChanges
    // for the rest of the session. Last, because it drives Purchases.logIn and
    // wants the purchases service configured first.
    ref.read(identitySyncServiceProvider);
  }

  Future<void> _initialize(String name, Future<void> Function() start) async {
    try {
      await start();
    } catch (error, stack) {
      _reportFatal('Failed to initialize $name service', error, stack);
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
