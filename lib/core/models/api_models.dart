class UserModel {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isEmailVerified;
  final int totalPoints;
  final int totalForcedOpens;
  final int longestStreakDays;
  final int currentStreakDays;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isFollower;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.isEmailVerified = false,
    this.totalPoints = 0,
    this.totalForcedOpens = 0,
    this.longestStreakDays = 0,
    this.currentStreakDays = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isFollower = false,
    this.createdAt,
  });

  String get name => displayName ?? username;

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isEmailVerified,
    int? totalPoints,
    int? totalForcedOpens,
    int? longestStreakDays,
    int? currentStreakDays,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? isFollower,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      totalPoints: totalPoints ?? this.totalPoints,
      totalForcedOpens: totalForcedOpens ?? this.totalForcedOpens,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      totalPoints: json['total_points'] as int? ?? 0,
      totalForcedOpens: json['total_forced_opens'] as int? ?? 0,
      longestStreakDays: json['longest_streak_days'] as int? ?? 0,
      currentStreakDays: json['current_streak_days'] as int? ?? 0,
      followersCount: json['followers_count'] != null
          ? int.tryParse(json['followers_count'].toString()) ?? 0
          : 0,
      followingCount: json['following_count'] != null
          ? int.tryParse(json['following_count'].toString()) ?? 0
          : 0,
      isFollowing: json['is_following'] as bool? ?? false,
      isFollower: json['is_follower'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_email_verified': isEmailVerified,
      'total_points': totalPoints,
      'total_forced_opens': totalForcedOpens,
      'longest_streak_days': longestStreakDays,
      'current_streak_days': currentStreakDays,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_following': isFollowing,
      'is_follower': isFollower,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class BadgeModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final String? iconUrl;
  final String? category;
  final int pointsReward;
  final String rarity;
  final bool isEarned;
  final DateTime? earnedAt;

  BadgeModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.iconUrl,
    this.category,
    this.pointsReward = 0,
    this.rarity = 'common',
    this.isEarned = false,
    this.earnedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String?,
      pointsReward: json['points_reward'] as int? ?? 0,
      rarity: json['rarity'] as String? ?? 'common',
      isEarned: json['is_earned'] as bool? ?? false,
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'].toString())
          : null,
    );
  }
}

class ChallengeParticipantModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status; // 'accepted', 'invited', 'declined', 'surrendered'
  final int forcedOpenCount;
  final DateTime? surrenderedAt;
  final DateTime? joinedAt;
  final int totalPoints;
  final int currentStreakDays;

  ChallengeParticipantModel({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.forcedOpenCount = 0,
    this.surrenderedAt,
    this.joinedAt,
    this.totalPoints = 0,
    this.currentStreakDays = 0,
  });

  String get name => displayName ?? username;
  bool get isSurrendered => status == 'surrendered';

  factory ChallengeParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipantModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'User',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'accepted',
      forcedOpenCount: json['forced_open_count'] as int? ?? 0,
      surrenderedAt: json['surrendered_at'] != null
          ? DateTime.tryParse(json['surrendered_at'].toString())
          : null,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
      totalPoints: json['total_points'] as int? ?? 0,
      currentStreakDays: json['current_streak_days'] as int? ?? 0,
    );
  }
}

class ChallengeAttemptModel {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime openedAt;

  ChallengeAttemptModel({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.openedAt,
  });

  String get name => displayName ?? username;

  factory ChallengeAttemptModel.fromJson(Map<String, dynamic> json) {
    return ChallengeAttemptModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'User',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChallengeModel {
  final String id;
  final String creatorId;
  final String? creatorUsername;
  final String? creatorName;
  final String? creatorAvatar;
  final String title;
  final String? description;
  final String packageName;
  final String appName;
  final int durationHours;
  final int maxForcedOpens;
  final String challengeType;
  final String status;
  final int participantCount;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<ChallengeParticipantModel> participants;
  final List<ChallengeAttemptModel> attempts;
  final String? myStatus;

  ChallengeModel({
    required this.id,
    required this.creatorId,
    this.creatorUsername,
    this.creatorName,
    this.creatorAvatar,
    required this.title,
    this.description,
    required this.packageName,
    required this.appName,
    required this.durationHours,
    this.maxForcedOpens = 0,
    this.challengeType = 'global',
    this.status = 'active',
    this.participantCount = 1,
    this.startTime,
    this.endTime,
    this.participants = const [],
    this.attempts = const [],
    this.myStatus,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    List<ChallengeParticipantModel> parsedParticipants = [];
    if (json['participants'] != null && json['participants'] is List) {
      parsedParticipants = (json['participants'] as List)
          .map((p) => ChallengeParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    List<ChallengeAttemptModel> parsedAttempts = [];
    if (json['attempts'] != null && json['attempts'] is List) {
      parsedAttempts = (json['attempts'] as List)
          .map((a) => ChallengeAttemptModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    return ChallengeModel(
      id: json['id'] as String? ?? '',
      creatorId: json['creator_id'] as String? ?? '',
      creatorUsername: json['creator_username'] as String?,
      creatorName: json['creator_name'] as String?,
      creatorAvatar: json['creator_avatar'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      packageName: json['package_name'] as String? ?? '',
      appName: json['app_name'] as String? ?? '',
      durationHours: json['duration_hours'] as int? ?? 24,
      maxForcedOpens: json['max_forced_opens'] as int? ?? 0,
      challengeType: json['challenge_type'] as String? ?? 'global',
      status: json['status'] as String? ?? 'active',
      participantCount: json['participant_count'] != null
          ? int.tryParse(json['participant_count'].toString()) ?? 1
          : 1,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'].toString())
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'].toString())
          : null,
      participants: parsedParticipants,
      attempts: parsedAttempts,
      myStatus: json['my_status'] as String?,
    );
  }
}
