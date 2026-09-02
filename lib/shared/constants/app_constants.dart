class AppConstants {
  // App Info
  // Keep the launcher, task switcher, native action bar, and commercial suite
  // aligned on one product identity.
  //
  // There is deliberately no appVersion constant. It used to say '1.0.0' while
  // pubspec.yaml said 1.4.7+3; the About page reads the real value from
  // package_info_plus, and a second, hand-maintained copy is only a way to
  // start disagreeing with it again.
  static const String appName = 'Master ABAP';
  static const String appTitle = appName;
  static const String aboutDescription = 'ABAP microlearning with AI';
  static const String legalNotice =
      '© Master ABAP. All Rights Reserved. Developed by Compilemama.';

  // URLs
  static const String privacyPolicyUrl =
      'https://supabapnew.vercel.app/privacy-policy';
  static const String termsOfServiceUrl =
      'https://supabapnew.vercel.app/terms-of-service';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double bannerAdHeight = 50.0;
}
