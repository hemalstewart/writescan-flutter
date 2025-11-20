import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../data/auth_api.dart';
import '../../data/local_storage.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final api = AuthApi();
    final storage = LocalStorage();
    final repo = AuthRepository(api: api, storage: storage);
    return AuthController(repo);
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    _bootstrap();
  }

  final AuthRepository _repository;
  bool _bootstrapped = false;

  Future<void> initialize() async {
    await _bootstrap();
  }

  Future<void> sendOtp(String mobile) async {
    // Debug log to help diagnose stuck login flows.
    // ignore: avoid_print
    print('[auth] sendOtp -> $mobile');
    _setLoading(true);
    try {
      final result = await _repository.requestOtp(mobile);
      if (result.userExists) {
        // ignore: avoid_print
        print('[auth] sendOtp result=exist');
        state = state.copyWith(
          stage: AuthStage.loggedIn,
          mobile: result.mobile,
          message: 'Welcome back! You are already registered.',
        );
      } else {
        // ignore: avoid_print
        print('[auth] sendOtp result=otp reference=${result.referenceNo}');
        state = state.copyWith(
          mobile: result.mobile,
          referenceNo: result.referenceNo,
          stage: AuthStage.enterOtp,
          message: 'We sent a code to your phone.',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[auth] sendOtp error: $e');
      state = state.copyWith(message: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (state.mobile.isEmpty) {
      state = state.copyWith(message: 'Please enter your mobile number first.');
      return;
    }
    _setLoading(true);
    try {
      await _repository
          .verifyOtp(mobile: state.mobile, otp: otp)
          .timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('[auth] verifyOtp success');
      state = state.copyWith(stage: AuthStage.loggedIn, message: null);
    } on TimeoutException {
      state = state.copyWith(
        message: 'Verification is taking too long. Try again.',
      );
      // ignore: avoid_print
      print('[auth] verifyOtp timeout');
    } catch (e) {
      // ignore: avoid_print
      print('[auth] verifyOtp error: $e');
      state = state.copyWith(message: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendOtp() async {
    if (state.mobile.isEmpty) {
      state = state.copyWith(message: 'Enter your mobile number first');
      return;
    }
    await sendOtp(state.mobile);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(stage: AuthStage.enterPhone);
  }

  Future<void> unsubscribe() async {
    await _repository.unsubscribe();
    state = const AuthState(stage: AuthStage.enterPhone, mobile: '');
  }

  void editNumber() {
    state = state.copyWith(stage: AuthStage.enterPhone, message: null);
  }

  void clearMessage() {
    state = state.copyWith(message: null);
  }

  void _setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final hasSession = await _repository.hasActiveSession();
    if (hasSession) {
      final mobile = await _repository.getSavedMobile();
      state = state.copyWith(stage: AuthStage.loggedIn, mobile: mobile ?? '');
    }
  }
}
