import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthApiResult {
  const AuthApiResult({
    required this.response,
    required this.data,
    required this.message,
    required this.details,
    required this.statusCode,
    this.status,
    this.mode,
    this.referenceNo,
    this.setCookie,
  });

  final String? response;
  final Map<String, dynamic>? data;
  final String? message;
  final Map<String, dynamic>? details;
  final String? status;
  final String? mode;
  final String? referenceNo;
  final String? setCookie;
  final int statusCode;

  factory AuthApiResult.fromJson(
    Map<String, dynamic> json, {
    String? setCookie,
    required int statusCode,
  }) {
    final data = json['data'] as Map<String, dynamic>?;
    final referenceNo = json['reference_no'] ??
        json['referenceNo'] ??
        data?['reference_no'] ??
        data?['referenceNo'];

    return AuthApiResult(
      response: json['response'] as String?,
      data: data,
      message: json['message'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      status: json['status'] as String?,
      mode: json['mode'] as String?,
      referenceNo: referenceNo as String?,
      setCookie: setCookie,
      statusCode: statusCode,
    );
  }
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthApiResult> requestOtp(String mobile,
      {String? sessionCookie}) async {
    try {
      final response = await _postWithFallback(
        path: '/auth/request-otp',
        sessionCookie: sessionCookie,
        body: {'mobile': mobile.trim()},
      );

      final payload = _decodeRelaxed(response);
      _debugLog('requestOtp', response.statusCode, payload);
      return AuthApiResult.fromJson(
        payload,
        setCookie: response.headers['set-cookie'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      _debugError('requestOtp', e);
      rethrow;
    }
  }

  Future<AuthApiResult> verifyOtp({
    required String referenceNo,
    required String mobile,
    required String otp,
    String? sessionCookie,
  }) async {
    try {
      final response = await _postWithFallback(
        path: '/auth/verify-otp',
        sessionCookie: sessionCookie,
        body: {
          'reference_no': referenceNo,
          'otp': otp.trim(),
          'mobile': mobile.trim(),
        },
      );

      final payload = _decodeRelaxed(response);
      _debugLog('verifyOtp', response.statusCode, payload);
      return AuthApiResult.fromJson(
        payload,
        setCookie: response.headers['set-cookie'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      _debugError('verifyOtp', e);
      rethrow;
    }
  }

  Map<String, dynamic> _decodeRelaxed(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body;
    } catch (_) {
      return {'message': response.body};
    }
  }

  void _debugLog(String tag, int status, Map<String, dynamic> body) {
    // ignore: avoid_print
    print('[api:$tag] status=$status payload=$body');
  }

  void _debugError(String tag, Object error) {
    // ignore: avoid_print
    print('[api:$tag] error=$error');
  }

  Future<http.Response> _postWithFallback({
    required String path,
    required Map<String, dynamic> body,
    String? sessionCookie,
  }) async {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      if (sessionCookie != null) 'Cookie': sessionCookie,
    };
    final uris = <Uri>[
      Uri.parse('${AppConfig.apiBase}$path'),
      Uri.parse('${AppConfig.apiBase}/index.php$path'),
      Uri.parse('${AppConfig.apiRoot}/index.php$path'),
      Uri.parse('${AppConfig.apiRoot}/api$path'),
    ];

    http.Response? last;
    for (final uri in uris) {
      try {
        final res = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 10));
        last = res;
        if (res.statusCode != 404) return res;
      } catch (e) {
        last = null;
        // try next
      }
    }
    if (last != null) return last;
    throw AuthApiException('All auth endpoints failed');
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
