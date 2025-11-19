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
}
