enum AuthStage { enterPhone, enterOtp, loggedIn }

class AuthState {
  const AuthState({
    this.mobile = '',
    this.referenceNo,
    this.stage = AuthStage.enterPhone,
    this.message,
    this.isLoading = false,
  });

  final String mobile;
  final String? referenceNo;
  final AuthStage stage;
  final String? message;
  final bool isLoading;

  AuthState copyWith({
    String? mobile,
    String? referenceNo,
    AuthStage? stage,
    String? message,
    bool? isLoading,
  }) {
    return AuthState(
      mobile: mobile ?? this.mobile,
      referenceNo: referenceNo ?? this.referenceNo,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
