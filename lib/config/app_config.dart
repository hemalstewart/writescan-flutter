class AppConfig {
  const AppConfig._();

  static const String baseUrl =
      'https://lakminiint.com/ideamart/bytehub/ReCon/middleWare/requestManager.php';

  /// Back-end app id used by the Android app.
  // Matches the CodeIgniter backend (see /Applications/MAMP/htdocs/codeigniter-backend/app/Controllers/Api/Auth.php)
  static const String appId = '24';

  /// CodeIgniter backend base URL (public API root).
  static const String apiBase =
      'https://phpstack-1483171-5959376.cloudwaysapps.com/api';

  /// CodeIgniter backend public root (without /api).
  static const String apiRoot =
      'https://phpstack-1483171-5959376.cloudwaysapps.com';

  /// Public pages.
  static const String privacyPolicyLight =
      'https://lakminiint.com/ideamart/bixway/privacy_policy.html';
  static const String privacyPolicyDark =
      'https://lakminiint.com/ideamart/bixway/privacy_policy_dark.html';
  static const String termsLight =
      'https://lakminiint.com/ideamart/bytehub/ReCon/terms_conditions.php?app_id=24&console=Bixway%20International&name=WriteScan';
  static const String termsDark = termsLight;
  static const String moreAppsUrl =
      'https://play.google.com/store/apps/developer?id=AppMixer';
  static const String playStorePackage = 'com.appmixer.writescan';

  static String get playStoreLink =>
      'https://play.google.com/store/apps/details?id=$playStorePackage';
}
