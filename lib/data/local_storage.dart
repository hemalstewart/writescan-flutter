import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _mobileKey = 'mobile';
  static const _refKey = 'ref';
  static const _maskKey = 'mask';
  static const _activeKey = 'active';
  static const _sessionKey = 'session_cookie';
  static const _onboardingKey = 'onboarding_seen';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveMobile(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_mobileKey, value);
  }

  Future<String?> getMobile() async {
    final prefs = await _prefs;
    return prefs.getString(_mobileKey);
  }

  Future<void> saveReference(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_refKey, value);
  }

  Future<String?> getReference() async {
    final prefs = await _prefs;
    return prefs.getString(_refKey);
  }

  Future<void> saveMask(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_maskKey, value);
  }

  Future<String?> getMask() async {
    final prefs = await _prefs;
    return prefs.getString(_maskKey);
  }

  Future<void> setActive(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_activeKey, value);
  }

  Future<void> saveSessionCookie(String value) async {
    final prefs = await _prefs;
    await prefs.setString(_sessionKey, value);
  }

  Future<String?> getSessionCookie() async {
    final prefs = await _prefs;
    return prefs.getString(_sessionKey);
  }

  Future<void> deactivate() async {
    final prefs = await _prefs;
    await prefs.remove(_activeKey);
    await prefs.remove(_refKey);
    await prefs.remove(_sessionKey);
  }

  Future<String?> getActive() async {
    final prefs = await _prefs;
    return prefs.getString(_activeKey);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_mobileKey);
    await prefs.remove(_refKey);
    await prefs.remove(_maskKey);
    await prefs.remove(_activeKey);
  }

  Future<void> setOnboardingSeen() async {
    final prefs = await _prefs;
    await prefs.setBool(_onboardingKey, true);
  }

  Future<bool> isOnboardingSeen() async {
    final prefs = await _prefs;
    return prefs.getBool(_onboardingKey) ?? false;
  }
}
