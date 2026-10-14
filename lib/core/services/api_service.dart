import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../models/api_models.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class ApiService {
  late final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'jeda_jwt_token';

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true', // Skip ngrok landing page
        },
      ),
    );

    // Add interceptor to inject Bearer Token automatically
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Log or handle errors globally if needed
          return handler.next(error);
        },
      ),
    );
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // =========================================================================
  // AUTH METHODS
  // =========================================================================

  Future<Map<String, dynamic>> registerManual({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'username': username,
          'password': password,
          'display_name': displayName ?? username,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.verifyOtp,
        data: {
          'email': email,
          'otp_code': otpCode,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['token'] != null) {
        await saveToken(data['token'].toString());
      }
      return data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final res = await _dio.post(
        ApiConstants.resendOtp,
        data: {'email': email},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginManual({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.login,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['token'] != null) {
        await saveToken(data['token'].toString());
      }
      return data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginGoogle(String idToken) async {
    try {
      final res = await _dio.post(
        ApiConstants.loginGoogle,
        data: {'id_token': idToken},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['token'] != null) {
        await saveToken(data['token'].toString());
      }
      return data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final res = await _dio.get(ApiConstants.me);
      if (res.data != null && res.data['user'] != null) {
        return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearToken();
        return null;
      }
      throw _handleError(e);
    }
  }

  // =========================================================================
  // USER & PROFILE METHODS
  // =========================================================================

  Future<UserModel?> updateProfile({String? displayName, String? bio}) async {
    try {
      final res = await _dio.put(
        ApiConstants.updateProfile,
        data: {
          if (displayName != null) 'display_name': displayName,
          if (bio != null) 'bio': bio,
        },
      );
      if (res.data != null && res.data['user'] != null) {
        return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final res = await _dio.get(
        ApiConstants.searchUsers,
        queryParameters: {'q': query},
      );
      if (res.data != null && res.data['users'] != null) {
        final list = res.data['users'] as List;
        return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final res = await _dio.get(ApiConstants.userProfile(userId));
      return res.data?['profile'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> syncLocks(List<Map<String, dynamic>> locks) async {
    try {
      await _dio.post(
        ApiConstants.syncLocks,
        data: {'locks': locks},
      );
    } on DioException catch (e) {
      // Non-blocking sync error
      print("Sync locks API error: ${e.message}");
    }
  }

  Future<Map<String, dynamic>> reportForcedOpen(String packageName, {String? lockedAppId}) async {
    try {
      final res = await _dio.post(
        ApiConstants.reportForcedOpen,
        data: {
          'package_name': packageName,
          if (lockedAppId != null) 'locked_app_id': lockedAppId,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // =========================================================================
  // SOCIAL & FOLLOW METHODS
  // =========================================================================

  Future<void> followUser(String userId) async {
    try {
      await _dio.post(ApiConstants.followUser(userId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unfollowUser(String userId) async {
    try {
      await _dio.delete(ApiConstants.unfollowUser(userId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserModel>> getFriends() async {
    try {
      final res = await _dio.get(ApiConstants.getFriends);
      if (res.data != null && res.data['friends'] != null) {
        final list = res.data['friends'] as List;
        return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserModel>> getFollowers() async {
    try {
      final res = await _dio.get(ApiConstants.getFollowers);
      if (res.data != null && res.data['followers'] != null) {
        final list = res.data['followers'] as List;
        return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserModel>> getFollowing() async {
    try {
      final res = await _dio.get(ApiConstants.getFollowing);
      if (res.data != null && res.data['following'] != null) {
        final list = res.data['following'] as List;
        return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // =========================================================================
  // LEADERBOARD METHODS
  // =========================================================================

  Future<List<dynamic>> getLeaderboard({
    String type = 'points', // 'points', 'streak', 'forced_open_lowest'
    String scope = 'global', // 'global', 'friends'
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.leaderboard,
        queryParameters: {
          'type': type,
          'scope': scope,
          'limit': limit,
        },
      );
      if (res.data != null && res.data['leaderboard'] != null) {
        return res.data['leaderboard'] as List<dynamic>;
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // =========================================================================
  // BADGES METHODS
  // =========================================================================

  Future<List<BadgeModel>> getAllBadges() async {
    try {
      final res = await _dio.get(ApiConstants.badges);
      if (res.data != null && res.data['badges'] != null) {
        final list = res.data['badges'] as List;
        return list.map((e) => BadgeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> checkBadges() async {
    try {
      final res = await _dio.post(ApiConstants.checkBadges);
      return res.data?['new_badges'] as List<dynamic>? ?? [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // =========================================================================
  // CHALLENGE METHODS
  // =========================================================================

  Future<List<ChallengeModel>> getGlobalChallenges() async {
    try {
      final res = await _dio.get(ApiConstants.globalChallenges);
      if (res.data != null && res.data['challenges'] != null) {
        final list = res.data['challenges'] as List;
        return list.map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<ChallengeModel>> getMyChallenges() async {
    try {
      final res = await _dio.get(ApiConstants.myChallenges);
      if (res.data != null && res.data['challenges'] != null) {
        final list = res.data['challenges'] as List;
        return list.map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ChallengeModel?> getChallengeDetail(String challengeId) async {
    try {
      final res = await _dio.get(ApiConstants.challengeDetail(challengeId));
      if (res.data != null && res.data['challenge'] != null) {
        return ChallengeModel.fromJson(res.data['challenge'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> respondChallengeInvite(String challengeId, String action) async {
    try {
      await _dio.post(
        ApiConstants.respondChallenge(challengeId),
        data: {'action': action},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> joinChallenge(String challengeId) async {
    try {
      await _dio.post(ApiConstants.joinChallenge(challengeId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> surrenderChallenge(String challengeId) async {
    try {
      await _dio.post(ApiConstants.surrenderChallenge(challengeId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> recordChallengeAttempt(String challengeId) async {
    try {
      await _dio.post(ApiConstants.recordChallengeAttempt(challengeId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ChallengeModel?> createChallenge({
    required String title,
    String? description,
    required String packageName,
    required String appName,
    required int durationHours,
    int maxForcedOpens = 0,
    String challengeType = 'global',
    List<String> inviteUserIds = const [],
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.challenges,
        data: {
          'title': title,
          'description': description,
          'package_name': packageName,
          'app_name': appName,
          'duration_hours': durationHours,
          'max_forced_opens': maxForcedOpens,
          'challenge_type': challengeType,
          if (inviteUserIds.isNotEmpty) 'invite_user_ids': inviteUserIds,
        },
      );
      if (res.data != null && res.data['challenge'] != null) {
        return ChallengeModel.fromJson(res.data['challenge'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error parser helper
  String _handleError(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        return data['error'].toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi ke server timeout. Periksa internet atau backend.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Gagal terhubung ke server backend Jeda.';
    }
    return e.message ?? 'Terjadi kesalahan pada jaringan';
  }
}
