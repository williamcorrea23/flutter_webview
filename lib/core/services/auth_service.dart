import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Firebase Auth, driven natively.
///
/// Sign-in CANNOT live in the WebView: Google rejects OAuth from an embedded
/// user agent with `403 disallowed_useragent`, and this site only ever runs
/// inside the shell (components/AppGate.tsx in the supabapnew repo blocks
/// everything else). So the shell authenticates natively and hands the web
/// layer a Firebase ID token over the existing window.NativeApp bridge, which
/// the site then verifies server-side. Email/password would work in the WebView
/// directly, but is routed through here too so there is one session, one
/// current user, and one place that refreshes tokens.
class AuthService {
  static final Logger _logger = Logger();

  // A GETTER, not a field. main.dart wraps Firebase.initializeApp in a
  // try/catch and carries on when it fails, so a field initialiser here would
  // throw while CONSTRUCTING this service — and the first construction happens
  // inside _setupJavaScriptHandlers(), which would abort before registering a
  // single handler. That would take the purchase and entitlement bridge down
  // with it. As a getter, the failure is contained to whichever auth method
  // was called, each of which already catches.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static String? _nonEmpty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// Refresh persisted Firebase profile fields without losing the offline user.
  Future<Map<String, dynamic>?> getAuthUser() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      await user.reload().timeout(const Duration(seconds: 5));
    } catch (error) {
      _logger.w('Could not refresh profile: ${error.runtimeType}');
    }
    return describeUser();
  }

  /// Emits on sign-in, sign-out and token refresh.
  ///
  /// Guarded for the same reason [currentUser] is: main.dart carries on when
  /// `Firebase.initializeApp` fails, so touching `FirebaseAuth.instance` can
  /// throw. A listener that only wants to know who is signed in should see
  /// "nobody" rather than an exception it has no way to act on — the caller
  /// here is the RevenueCat identity sync, and it must not bring the app down
  /// on a device where Firebase never came up.
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      _logger.e('Firebase Auth unavailable, no auth stream: $e');
      return const Stream<User?>.empty();
    }
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      _logger.e('Firebase Auth unavailable: $e');
      return null;
    }
  }

  /// Shape returned to JS for the signed-in user, or `null` when signed out.
  Map<String, dynamic>? describeUser([User? user]) {
    final u = user ?? currentUser;
    if (u == null) return null;
    UserInfo? googleProfile;
    for (final provider in u.providerData) {
      if (provider.providerId == 'google.com') {
        googleProfile = provider;
        break;
      }
    }
    return {
      'uid': u.uid,
      'email': u.email,
      // Older or linked Firebase accounts can keep these fields only on the
      // Google provider record instead of copying them to the root user.
      'displayName':
          _nonEmpty(u.displayName) ?? _nonEmpty(googleProfile?.displayName),
      'photoUrl': _nonEmpty(u.photoURL) ?? _nonEmpty(googleProfile?.photoURL),
      'emailVerified': u.emailVerified,
      'providers': u.providerData.map((p) => p.providerId).toList(),
      'isAnonymous': u.isAnonymous,
    };
  }

  /// The ID token the site sends to its own API for verification.
  ///
  /// Firebase caches this and auto-refreshes about five minutes before expiry,
  /// so callers may request it freely; pass [forceRefresh] only after a claims
  /// change. Returns null when signed out rather than throwing, so a caller can
  /// treat "no session" and "no token" as the same thing.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      _logger.e('Failed to get ID token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Sign the Google account out first so the picker always appears.
      // Without this a second sign-in silently reuses the cached account, and
      // a user who wants to switch accounts has no way to.
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        // Not an error: the user dismissed the picker.
        return {'success': false, 'cancelled': true};
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      // Persist the account photo so later getAuthUser calls and restored
      // sessions receive it too, even when Firebase omitted the root field.
      final user = result.user;
      final photo = _nonEmpty(account.photoUrl);
      if (user != null && photo != null && _nonEmpty(user.photoURL) == null) {
        try {
          await user.updatePhotoURL(photo).timeout(const Duration(seconds: 5));
        } catch (error) {
          _logger.w('Could not persist Google photo: ${error.runtimeType}');
        }
      }
      _logger.i('Google sign-in succeeded');
      return {'success': true, 'user': describeUser(result.user)};
    } on FirebaseAuthException catch (e) {
      _logger.e('Google sign-in failed: ${e.code}');
      return {'success': false, 'code': e.code, 'error': _messageFor(e)};
    } catch (e) {
      _logger.e('Google sign-in failed: $e');
      return {'success': false, 'error': 'Could not sign in with Google.'};
    }
  }

  Future<Map<String, dynamic>> signInWithEmail(
      String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return {'success': true, 'user': describeUser(result.user)};
    } on FirebaseAuthException catch (e) {
      _logger.w('Email sign-in failed: ${e.code}');
      return {'success': false, 'code': e.code, 'error': _messageFor(e)};
    } catch (e) {
      _logger.e('Email sign-in failed: $e');
      return {'success': false, 'error': 'Could not sign in.'};
    }
  }

  Future<Map<String, dynamic>> createAccountWithEmail(
      String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Best effort: the account already exists at this point, so a failure to
      // send the verification email must not fail the signup.
      try {
        await result.user?.sendEmailVerification();
      } catch (e) {
        _logger.w('Could not send verification email: $e');
      }
      return {'success': true, 'user': describeUser(result.user)};
    } on FirebaseAuthException catch (e) {
      _logger.w('Account creation failed: ${e.code}');
      return {'success': false, 'code': e.code, 'error': _messageFor(e)};
    } catch (e) {
      _logger.e('Account creation failed: $e');
      return {'success': false, 'error': 'Could not create the account.'};
    }
  }

  /// Always reports success. Firebase distinguishes "no such user" from a real
  /// send, and surfacing that difference turns this into an oracle for which
  /// email addresses hold accounts. Failures are logged, never returned.
  Future<Map<String, dynamic>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      _logger.w('Password reset not sent: ${e.code}');
    } catch (e) {
      _logger.e('Password reset failed: $e');
    }
    return {
      'success': true,
      'message': 'If that address has an account, a reset link is on its way.',
    };
  }

  Future<Map<String, dynamic>> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      return {'success': true};
    } catch (e) {
      _logger.e('Sign out failed: $e');
      return {'success': false, 'error': 'Could not sign out.'};
    }
  }

  String _messageFor(FirebaseAuthException e) {
    return switch (e.code) {
      // Modern Firebase deliberately returns invalid-credential for both a
      // wrong password and an unknown email, so this copy must not imply which.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Incorrect email or password.',
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'email-already-in-use' =>
        'That email already has an account. Try signing in.',
      'weak-password' => 'Choose a password of at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'No connection. Check your internet and try again.',
      'account-exists-with-different-credential' =>
        'That email is already registered with a different sign-in method.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
