import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'auth_service.dart';
import 'purchases_service.dart';

/// Keeps the RevenueCat app user in step with the Firebase session.
///
/// ## Why this exists rather than the RevenueCat Firebase integration
///
/// RevenueCat ships a first-party Firebase integration that mirrors
/// entitlements into Firestore and keeps identities aligned server-side. It
/// sits behind a paid plan, and this project is on the free one — so the link
/// is made here instead, on the client, with nothing but the public SDK:
/// `Purchases.logIn(uid)` after a sign-in, `Purchases.logOut()` after a sign
/// out. App-user-id aliasing is core SDK behaviour on every plan.
///
/// The trade against the paid integration is worth stating plainly, because it
/// shapes what the rest of the app may assume:
///
/// * The alias is established by the CLIENT, so it only happens while the app
///   is running and reachable. A purchase made while signed out stays on the
///   anonymous user until the next `logIn` transfers it.
/// * There is no server-side mirror of the entitlement. The web layer must
///   keep asking the bridge (`isPremiumActive`) rather than reading Premium
///   out of Firestore, because nothing writes it there.
/// * RevenueCat remains the source of truth for entitlements, and Firebase
///   remains the source of truth for identity. This class is the only seam
///   between them.
///
/// ## Why a listener rather than a call inside AuthService
///
/// Doing it inside [AuthService] would make auth depend on purchases, and
/// would silently miss every sign-in the shell did not initiate itself — a
/// token expiry, a session restored on launch, a sign-out triggered from the
/// Firebase console. Listening to `authStateChanges` catches all of them, and
/// keeps [AuthService] free of any knowledge that billing exists.
class IdentitySyncService {
  static final Logger _logger = Logger();

  final AuthService _authService;
  final PurchasesService _purchasesService;
  final void Function() _onIdentityChanged;

  StreamSubscription<User?>? _subscription;
  String? _lastSyncedUid;
  bool _hasSynced = false;
  bool _disposed = false;

  /// Incremented per auth event. `Stream.listen` does not await an async
  /// handler, so two events overlap freely — and on a cold start with a
  /// persisted session firebase_auth emits null and then the restored user in
  /// quick succession. Their RevenueCat calls can complete out of order (logIn
  /// for a known user may be served from cache while logOut has to mint a new
  /// anonymous id over the network), and whichever RETURNED last would
  /// otherwise write the latch — leaving the SDK anonymous for a signed-in
  /// subscriber, with no further auth event coming to correct it.
  int _generation = 0;

  /// Serialises the RevenueCat calls themselves, so logIn and logOut are never
  /// in flight against the SDK at the same time.
  Future<void> _pending = Future<void>.value();

  IdentitySyncService({
    required AuthService authService,
    required PurchasesService purchasesService,
    required void Function() onIdentityChanged,
  })  : _authService = authService,
        _purchasesService = purchasesService,
        _onIdentityChanged = onIdentityChanged;

  void start() {
    _subscription ??= _authService.authStateChanges.listen(
      _handleAuthState,
      onError: (Object error) => _logger.e('Auth state stream failed: $error'),
    );
  }

  Future<void> _handleAuthState(User? user) async {
    final uid = user?.uid;

    // authStateChanges also fires on token refresh, which re-emits the SAME
    // user. Re-running logIn there would be a wasted round trip on a timer for
    // the entire life of the session; worse, each one invalidates the premium
    // provider and so rebuilds the WebView's banner region.
    if (_hasSynced && uid == _lastSyncedUid) return;

    final generation = ++_generation;

    var synced = false;
    final call = _pending.then((_) async {
      synced = uid == null
          ? await _purchasesService.logOut()
          : await _purchasesService.logIn(uid);
    });
    _pending = call.catchError((Object _) {});
    await call;

    // A newer auth event started while this one was in flight, so this result
    // describes a session that is already over. Writing the latch here would
    // record the stale identity.
    if (generation != _generation) return;

    // Latched only on success. Recording the attempt up front would mean a
    // single failed identify — RevenueCat unreachable for a moment, or not
    // configured yet — is remembered as done, and the guard above then blocks
    // every later emission for this uid for the rest of the session. That is
    // the account-switch leak this class exists to close, so it must not be
    // possible to enter it through a swallowed error.
    if (synced) {
      _hasSynced = true;
      _lastSyncedUid = uid;
    } else {
      _logger.w('RevenueCat identity not synced for ${uid ?? "signed-out"}; '
          'will retry on the next auth event');
    }

    // The RevenueCat round trip above is an await, and the ProviderContainer
    // can be torn down across it. _onIdentityChanged closes over `ref`, and
    // using a disposed ref throws — so check on the far side of the await, not
    // just at the top.
    if (_disposed) return;

    // Premium is now being read against a different RevenueCat user, so
    // whatever the app last computed is stale. This is the other half of the
    // account-switch fix: without it the banner and the web layer's
    // entitlement answer both keep describing the previous account.
    _onIdentityChanged();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}

/// Instantiating this provider starts the sync. Nothing reads its value.
///
/// It is a plain (non-autoDispose) provider deliberately: it must outlive
/// every widget, since a sign-out that happens while no page is watching still
/// has to reach RevenueCat.
final identitySyncServiceProvider = Provider<IdentitySyncService>((ref) {
  final service = IdentitySyncService(
    authService: ref.read(authServiceProvider),
    purchasesService: ref.read(purchasesServiceProvider),
    onIdentityChanged: () => ref.invalidate(isPremiumProvider),
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});
