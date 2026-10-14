class ApiConstants {
  // Base URL backend Jeda (ngrok tunnel)
  static const String baseUrl = 'https://jeda-backend.vercel.app/api';

  // Google Sign-In Server Client ID
  static const String googleServerClientId = '1015775557122-mdb1logctrin8f1momqhcb0ida08ogeh.apps.googleusercontent.com';

  // Auth endpoints
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String login = '/auth/login';
  static const String loginGoogle = '/auth/google';
  static const String me = '/auth/me';

  // Users endpoints
  static const String updateProfile = '/users/me';
  static const String searchUsers = '/users/search';
  static const String syncLocks = '/users/me/sync-locks';
  static const String reportForcedOpen = '/users/me/report-forced-open';
  static String userProfile(String id) => '/users/$id/profile';

  // Follow endpoints
  static String followUser(String userId) => '/follows/$userId';
  static String unfollowUser(String userId) => '/follows/$userId';
  static const String getFriends = '/follows/friends';
  static const String getFollowers = '/follows/followers';
  static const String getFollowing = '/follows/following';

  // Leaderboard endpoints
  static const String leaderboard = '/leaderboard';

  // Challenge endpoints
  static const String challenges = '/challenges';
  static const String globalChallenges = '/challenges/global';
  static const String myChallenges = '/challenges/my';
  static String challengeDetail(String id) => '/challenges/$id';
  static String joinChallenge(String id) => '/challenges/$id/join';
  static String respondChallenge(String id) => '/challenges/$id/respond';
  static String surrenderChallenge(String id) => '/challenges/$id/surrender';
  static String recordChallengeAttempt(String id) => '/challenges/$id/attempt';

  // Badge endpoints
  static const String badges = '/badges';
  static const String myBadges = '/badges/my';
  static const String checkBadges = '/badges/check';
}
