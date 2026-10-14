import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(const AsyncValue.loading()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    try {
      final isLoggedIn = await _apiService.isLoggedIn();
      if (!isLoggedIn) {
        state = const AsyncValue.data(null);
        return;
      }
      final user = await _apiService.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loginManual(String identifier, String password) async {
    state = const AsyncValue.loading();
    try {
      await _apiService.loginManual(identifier: identifier, password: password);
      final user = await _apiService.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginGoogle(String idToken) async {
    state = const AsyncValue.loading();
    try {
      await _apiService.loginGoogle(idToken);
      final user = await _apiService.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyOtpAndLogin(String email, String otpCode) async {
    state = const AsyncValue.loading();
    try {
      await _apiService.verifyOtp(email: email, otpCode: otpCode);
      final user = await _apiService.getMe();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _apiService.getMe();
      state = AsyncValue.data(user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }
}
