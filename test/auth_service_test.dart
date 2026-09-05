import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_abap/core/services/auth_service.dart';

class GoogleProfile implements UserInfo {
  @override
  String get providerId => 'google.com';
  @override
  String get photoURL => 'https://lh3.googleusercontent.com/avatar';
  @override
  String get displayName => 'Google User';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProfileUser implements User {
  ProfileUser({this.photoURL, this.displayName});
  @override
  final String? photoURL;
  @override
  final String? displayName;
  @override
  String get uid => 'user-1';
  @override
  String? get email => 'user@example.com';
  @override
  bool get emailVerified => true;
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [GoogleProfile()];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('blank Firebase fields use Google profile', () {
    final result = AuthService().describeUser(
      ProfileUser(photoURL: '  ', displayName: ''),
    );
    expect(result?['photoUrl'], 'https://lh3.googleusercontent.com/avatar');
    expect(result?['displayName'], 'Google User');
  });

  test('custom Firebase photo takes precedence over provider photo', () {
    final result = AuthService().describeUser(
      ProfileUser(photoURL: 'https://example.com/custom.png'),
    );
    expect(result?['photoUrl'], 'https://example.com/custom.png');
  });
}
