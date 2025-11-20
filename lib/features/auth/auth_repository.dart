import '../../data/auth_api.dart';
import '../../data/local_storage.dart';

class OtpRequestResult {
  OtpRequestResult({
    required this.mobile,
    this.referenceNo,
    this.userExists = false,
  });

  final String mobile;
  final String? referenceNo;
  final bool userExists;
}

class OtpVerifyResult {
  OtpVerifyResult({required this.mobile, required this.subscriberId});

  final String mobile;
  final String? subscriberId;
}

class AuthRepository {
  AuthRepository({required AuthApi api, required LocalStorage storage})
    : _api = api,
      _storage = storage;

  final AuthApi _api;
  final LocalStorage _storage;

  Future<OtpRequestResult> requestOtp(String input) async {
    final mobile = _normalizeMobile(input);
    if (mobile == null) {
      throw AuthDomainException('Please enter a valid mobile number');
    }

    final apiResult = await _api.requestOtp(
      mobile,
      sessionCookie: await _storage.getSessionCookie(),
    );
    if (apiResult.setCookie != null) {
      await _storage.saveSessionCookie(_extractSession(apiResult.setCookie!));
    }

    final response = apiResult.response?.toLowerCase();
    final status = apiResult.status?.toLowerCase();
    final isHttpSuccess =
        apiResult.statusCode >= 200 && apiResult.statusCode < 300;

    final reference =
        apiResult.referenceNo ?? apiResult.data?['referenceNo'] as String?;

    final isSuccess = response == 'success' || status == 'success';
    final isExist = response == 'exist' || apiResult.mode == 'login';

    if (isExist && isHttpSuccess) {
      await _storage.saveMobile(mobile);
      await _storage.setActive('1');
      return OtpRequestResult(mobile: mobile, userExists: true);
    }

    if (isSuccess && isHttpSuccess) {
      if (reference == null || reference.isEmpty) {
        throw AuthDomainException('Missing reference number from server');
      }
      await _storage.saveReference(reference);
      await _storage.saveMobile(mobile);
      return OtpRequestResult(mobile: mobile, referenceNo: reference);
    }

    if (response == 'exist-non-found') {
      final message =
          apiResult.message ?? apiResult.details?['statusDetail'] as String?;
      throw AuthDomainException(message ?? 'User not found');
    }

    final message =
        apiResult.message ?? apiResult.details?['statusDetail'] as String?;
    throw AuthDomainException(
      message ?? 'Failed to send OTP (${apiResult.statusCode})',
    );
  }

  Future<OtpVerifyResult> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final reference = await _storage.getReference();
    if (reference == null || reference.isEmpty) {
      throw AuthDomainException('Please request a new OTP first');
    }
    if (otp.length != 6) {
      throw AuthDomainException('Please enter the 6-digit code');
    }

    final apiResult = await _api.verifyOtp(
      referenceNo: reference,
      mobile: mobile,
      otp: otp,
      sessionCookie: await _storage.getSessionCookie(),
    );
    if (apiResult.setCookie != null) {
      await _storage.saveSessionCookie(_extractSession(apiResult.setCookie!));
    }
    final response = apiResult.response?.toLowerCase();
    final status = apiResult.status?.toLowerCase();
    final isHttpSuccess =
        apiResult.statusCode >= 200 && apiResult.statusCode < 300;
    final isSuccess = response == 'success' || status == 'success';

    if (isSuccess && isHttpSuccess) {
      final subscriberId = apiResult.data?['subscriberId'] as String?;
      if (subscriberId != null) {
        await _storage.saveMask(subscriberId);
      }
      await _storage.setActive('1');
      await _storage.saveMobile(mobile);

      return OtpVerifyResult(mobile: mobile, subscriberId: subscriberId);
    }

    final errorMessage =
        apiResult.details?['statusDetail'] as String? ??
        apiResult.message ??
        'Invalid code, try again (${apiResult.statusCode})';
    throw AuthDomainException(errorMessage);
  }

  Future<bool> hasActiveSession() async {
    final active = await _storage.getActive();
    final mobile = await _storage.getMobile();
    return (active == '1') && (mobile != null && mobile.isNotEmpty);
  }

  Future<String?> getSavedMobile() => _storage.getMobile();

  Future<void> logout() async {
    await _storage.clear();
  }

  Future<void> unsubscribe() async {
    await _storage.deactivate();
    await _storage.saveMobile('');
  }

  String? _normalizeMobile(String raw) {
    var mobile = raw.replaceAll(' ', '').trim();

    final pattern = RegExp(
      r'((7([0-2]|[5-8])(\d{7}))|(\+947([0-2]|[5-8])(\d{7})))',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(mobile);
    if (match != null) {
      if (match.group(5) != null) {
        mobile = '0${mobile.substring(3)}';
      }
      return mobile;
    }
    if (mobile.length == 10 && mobile.startsWith('07')) {
      return mobile;
    }
    return null;
  }

  String _extractSession(String rawCookie) {
    final parts = rawCookie.split(';');
    return parts.first;
  }
}

class AuthDomainException implements Exception {
  AuthDomainException(this.message);
  final String message;

  @override
  String toString() => message;
}
