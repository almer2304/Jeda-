import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/jeda_card.dart';
import '../../core/widgets/jeda_badge.dart';
import '../../core/widgets/jeda_button.dart';
import '../challenges/create_challenge_screen.dart';
import '../challenges/challenge_detail_screen.dart';

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  List<dynamic> _leaderboard = [];
  final Map<String, List<dynamic>> _leaderboardCache = {};
  List<BadgeModel> _badges = [];
  List<ChallengeModel> _globalChallenges = [];
  List<ChallengeModel> _myChallenges = [];
  List<UserModel> _friends = [];
  List<UserModel> _following = [];
  List<UserModel> _followers = [];
  final Set<String> _followingUserIds = {};
  final Set<String> _loadingActionUserIds = {};

  List<UserModel> _searchResults = [];
  final _searchController = TextEditingController();
  bool _isSearching = false;
  int _friendSubTabIndex = 0; // 0: Saling Follow, 1: Mengikuti, 2: Pengikut

  String _leaderboardType = 'points';
  final String _leaderboardScope = 'global';

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && !_isSearching) {
        _loadAllData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);
      final isLoggedIn = await api.isLoggedIn();

      final results = await Future.wait([
        api.getLeaderboard(type: 'points', scope: _leaderboardScope),
        api.getLeaderboard(type: 'streak', scope: _leaderboardScope),
        api.getAllBadges(),
        api.getGlobalChallenges(),
      ]);
      final pointsLb = results[0];
      final streakLb = results[1];
      final badgesRes = results[2] as List<BadgeModel>;
      final globalChallengesRes = results[3] as List<ChallengeModel>;

      List<ChallengeModel> myChallengesRes = [];
      List<UserModel> friendsRes = [];
      List<UserModel> followingRes = [];
      List<UserModel> followersRes = [];

      if (isLoggedIn) {
        try {
          final res = await Future.wait([
            api.getMyChallenges(),
            api.getFriends(),
            api.getFollowing(),
            api.getFollowers(),
          ]);
          myChallengesRes = res[0] as List<ChallengeModel>;
          friendsRes = res[1] as List<UserModel>;
          followingRes = res[2] as List<UserModel>;
          followersRes = res[3] as List<UserModel>;
        } catch (_) {}
      }

      final followingIds = followingRes.map((u) => u.id).toSet();

      if (mounted) {
        setState(() {
          _leaderboardCache['points'] = pointsLb;
          _leaderboardCache['streak'] = streakLb;
          _leaderboard = _leaderboardCache[_leaderboardType] ?? pointsLb;
          _badges = badgesRes;
          _globalChallenges = globalChallengesRes;
          _myChallenges = myChallengesRes;
          _friends = friendsRes;
          _following = followingRes;
          _followers = followersRes;
          _followingUserIds.clear();
          _followingUserIds.addAll(followingIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final results = await api.searchUsers(query.trim());
      if (mounted) {
        for (var u in results) {
          if (u.isFollowing) {
            _followingUserIds.add(u.id);
          }
        }
        setState(() {
          _searchResults = results;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(UserModel user) async {
    final isFollowing = _followingUserIds.contains(user.id) || user.isFollowing;
    final targetId = user.id;

    setState(() {
      _loadingActionUserIds.add(targetId);
      if (isFollowing) {
        _followingUserIds.remove(targetId);
      } else {
        _followingUserIds.add(targetId);
      }
    });

    try {
      final api = ref.read(apiServiceProvider);
      if (isFollowing) {
        await api.unfollowUser(targetId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Batal mengikuti @${user.username}')),
          );
        }
      } else {
        await api.followUser(targetId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mengikuti @${user.username} 🌱'),
              backgroundColor: JedaColors.primary,
            ),
          );
        }
      }
      ref.read(authStateProvider.notifier).refreshProfile();
      _loadAllData(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isFollowing) {
            _followingUserIds.add(targetId);
          } else {
            _followingUserIds.remove(targetId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: JedaColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingActionUserIds.remove(targetId);
        });
      }
    }
  }

  Future<void> _checkBadgesTrigger() async {
    try {
      final api = ref.read(apiServiceProvider);
      final newBadges = await api.checkBadges();
      if (mounted) {
        if (newBadges.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selamat! Anda mendapatkan ${newBadges.length} Lencana baru 🌱'),
              backgroundColor: JedaColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status lencana sudah yang terbaru.'),
              backgroundColor: JedaColors.primary,
            ),
          );
        }
        _loadAllData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memeriksa lencana: $e'), backgroundColor: JedaColors.error),
        );
      }
    }
  }

  Future<void> _syncChallengeToNative() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final nativeBridge = ref.read(nativeBridgeServiceProvider);
      final api = ref.read(apiServiceProvider);
      if (!await api.isLoggedIn()) return;
      final rules = storage.getActiveRules();
      final myChallenges = await api.getMyChallenges();
      for (final ch in myChallenges) {
        if (ch.status == 'active' && ch.myStatus != 'invited' && ch.myStatus != 'declined' && ch.myStatus != 'surrendered') {
          final endMillis = ch.endTime?.millisecondsSinceEpoch ?? DateTime.now().add(Duration(hours: ch.durationHours)).millisecondsSinceEpoch;
          final already = rules.any((r) => r['packageName'] == ch.packageName);
          if (!already && DateTime.now().millisecondsSinceEpoch < endMillis) {
            rules.add({'packageName': ch.packageName, 'isScheduled': false, 'endTimeMillis': endMillis, 'isChallenge': true, 'challengeId': ch.id});
          }
        }
      }
      if (rules.isNotEmpty) {
        await nativeBridge.startMonitoring(rules);
        await nativeBridge.updateBlockedList(rules);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          'Komunitas & Tantangan',
          style: JedaTypography.heading3.copyWith(
            color: JedaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: JedaColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: JedaColors.textSecondary),
            onPressed: () => _loadAllData(),
            tooltip: 'Segarkan Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: JedaColors.primary,
          unselectedLabelColor: JedaColors.textSecondary,
          indicatorColor: JedaColors.primary,
          indicatorWeight: 2.5,
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: JedaTypography.caption.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: JedaTypography.caption,
          tabs: [
            const Tab(text: 'Peringkat', icon: Icon(Icons.leaderboard_outlined, size: 18)),
            Tab(text: 'Teman (${_following.length})', icon: const Icon(Icons.people_outline, size: 18)),
            Tab(text: 'Tantangan (${_myChallenges.length})', icon: const Icon(Icons.flag_outlined, size: 18)),
            const Tab(text: 'Lencana', icon: Icon(Icons.military_tech_outlined, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: JedaColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48, color: JedaColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: JedaTypography.bodySecondary.copyWith(color: JedaColors.error),
                        ),
                        const SizedBox(height: 16),
                        JedaButton(
                          label: 'Coba Lagi',
                          isFullWidth: false,
                          onPressed: () => _loadAllData(),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: JedaColors.primary,
                      child: _buildLeaderboardTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: JedaColors.primary,
                      child: _buildFriendsTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: JedaColors.primary,
                      child: _buildChallengesTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: JedaColors.primary,
                      child: _buildBadgesTab(),
                    ),
                  ],
                ),
    );
  }

  // =========================================================================
  // TAB 1: PERINGKAT (LEADERBOARD)
  // =========================================================================
  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Poin Tertinggi'),
                selected: _leaderboardType == 'points',
                selectedColor: JedaColors.primary,
                backgroundColor: JedaColors.surface,
                side: BorderSide(
                  color: _leaderboardType == 'points' ? JedaColors.primaryDark : JedaColors.border,
                ),
                labelStyle: JedaTypography.caption.copyWith(
                  color: _leaderboardType == 'points' ? Colors.white : JedaColors.textPrimary,
                  fontWeight: _leaderboardType == 'points' ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (sel) {
                  if (sel && _leaderboardType != 'points') {
                    setState(() {
                      _leaderboardType = 'points';
                      _leaderboard = _leaderboardCache['points'] ?? [];
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Streak Terpanjang'),
                selected: _leaderboardType == 'streak',
                selectedColor: JedaColors.primary,
                backgroundColor: JedaColors.surface,
                side: BorderSide(
                  color: _leaderboardType == 'streak' ? JedaColors.primaryDark : JedaColors.border,
                ),
                labelStyle: JedaTypography.caption.copyWith(
                  color: _leaderboardType == 'streak' ? Colors.white : JedaColors.textPrimary,
                  fontWeight: _leaderboardType == 'streak' ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (sel) {
                  if (sel && _leaderboardType != 'streak') {
                    setState(() {
                      _leaderboardType = 'streak';
                      _leaderboard = _leaderboardCache['streak'] ?? [];
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _leaderboard.isEmpty
              ? const Center(
                  child: Text('Belum ada data peringkat', style: JedaTypography.bodySecondary),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final item = _leaderboard[index];
                    final rank = index + 1;
                    final isTop1 = rank == 1;
                    final isTop3 = rank <= 3;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: JedaCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        backgroundColor: isTop1 ? JedaColors.surface : JedaColors.surface,
                        borderColor: isTop1 ? JedaColors.primary : JedaColors.border,
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isTop1
                                    ? JedaColors.primary
                                    : isTop3
                                        ? JedaColors.primarySoft
                                        : JedaColors.surfaceSecondary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isTop1
                                      ? Colors.white
                                      : isTop3
                                          ? JedaColors.primaryDark
                                          : JedaColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['display_name'] ?? item['username'] ?? 'Pengguna Jeda',
                                    style: JedaTypography.labelBold.copyWith(
                                      fontSize: 14,
                                      color: JedaColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '@${item['username'] ?? 'user'}',
                                        style: JedaTypography.caption.copyWith(
                                          color: JedaColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.local_fire_department_outlined,
                                        size: 13,
                                        color: JedaColors.warning,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${item['current_streak_days'] ?? 0} hari streak',
                                        style: JedaTypography.caption.copyWith(
                                          color: JedaColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item['total_points'] ?? 0}',
                                  style: JedaTypography.labelBold.copyWith(
                                    fontSize: 15,
                                    color: JedaColors.primary,
                                  ),
                                ),
                                Text(
                                  'Poin',
                                  style: JedaTypography.caption.copyWith(
                                    color: JedaColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: TEMAN & PENCARIAN
  // =========================================================================
  Widget _buildFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: JedaTypography.body,
            decoration: InputDecoration(
              hintText: 'Cari nama atau @username...',
              hintStyle: JedaTypography.bodySecondary.copyWith(color: JedaColors.textTertiary),
              prefixIcon: const Icon(Icons.search_rounded, color: JedaColors.primary, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: JedaColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: const OutlineInputBorder(
                borderRadius: JedaRadii.borderR12,
                borderSide: BorderSide(color: JedaColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: JedaRadii.borderR12,
                borderSide: BorderSide(color: JedaColors.primary, width: 1.5),
              ),
            ),
            onChanged: (val) {
              if (val.length >= 2 || val.isEmpty) {
                _searchUsers(val);
              }
            },
          ),
        ),
        if (!_isSearching) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                _buildSubFilterChip('Saling Terhubung (${_friends.length})', 0),
                const SizedBox(width: 8),
                _buildSubFilterChip('Mengikuti (${_following.length})', 1),
                const SizedBox(width: 8),
                _buildSubFilterChip('Pengikut (${_followers.length})', 2),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        Expanded(
          child: _isSearching
              ? _buildSearchResultsView()
              : _friendSubTabIndex == 0
                  ? _buildUserListView(_friends, emptyMsg: 'Belum ada teman saling terhubung.\nCari teman dan mulai saling dukung!')
                  : _friendSubTabIndex == 1
                      ? _buildUserListView(_following, emptyMsg: 'Anda belum mengikuti siapa pun.\nGunakan pencarian di atas untuk menemukan teman.')
                      : _buildUserListView(_followers, emptyMsg: 'Belum ada yang mengikuti Anda saat ini.'),
        ),
      ],
    );
  }

  Widget _buildSubFilterChip(String label, int index) {
    final isSelected = _friendSubTabIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: JedaColors.primary,
      backgroundColor: JedaColors.surface,
      side: BorderSide(
        color: isSelected ? JedaColors.primaryDark : JedaColors.border,
      ),
      labelStyle: JedaTypography.caption.copyWith(
        color: isSelected ? Colors.white : JedaColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (sel) {
        if (sel) setState(() => _friendSubTabIndex = index);
      },
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined, size: 48, color: JedaColors.textTertiary),
              SizedBox(height: 8),
              Text('Pengguna tidak ditemukan', style: JedaTypography.bodySecondary),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isFollowing = _followingUserIds.contains(user.id);
        final isLoadingAction = _loadingActionUserIds.contains(user.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildUserCard(user, isFollowing, isLoadingAction),
        );
      },
    );
  }

  Widget _buildUserListView(List<UserModel> userList, {required String emptyMsg}) {
    if (userList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline_rounded, size: 48, color: JedaColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: JedaTypography.bodySecondary.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: userList.length,
      itemBuilder: (context, index) {
        final user = userList[index];
        final isFollowing = _followingUserIds.contains(user.id);
        final isLoadingAction = _loadingActionUserIds.contains(user.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildUserCard(user, isFollowing, isLoadingAction),
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user, bool isFollowing, bool isLoadingAction) {
    return JedaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: JedaColors.primarySoft,
            child: Text(
              user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
              style: JedaTypography.labelBold.copyWith(
                color: JedaColors.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: JedaTypography.labelBold.copyWith(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username} • ${user.totalPoints} poin • ${user.currentStreakDays}h streak',
                  style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            height: 32,
            child: JedaButton(
              label: isFollowing ? 'Mengikuti' : 'Ikuti',
              variant: isFollowing ? JedaButtonVariant.secondary : JedaButtonVariant.primary,
              height: 32,
              isLoading: isLoadingAction,
              onPressed: () => _toggleFollow(user),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: TANTANGAN (CHALLENGES)
  // =========================================================================
  Widget _buildChallengesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: JedaButton(
            label: 'Buat Tantangan Bersama Teman',
            icon: Icons.add_rounded,
            variant: JedaButtonVariant.primary,
            height: 46,
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateChallengeScreen()),
              );
              if (res == true) _loadAllData();
            },
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final now = DateTime.now();
              final pendingChallenges = _myChallenges.where((c) => c.status == 'pending' || c.myStatus == 'invited').toList();
              final activeChallenges = _myChallenges.where((c) {
                final isExpired = c.endTime != null && now.isAfter(c.endTime!);
                return c.status == 'active' && c.myStatus != 'invited' && !isExpired;
              }).toList();
              final completedChallenges = _myChallenges.where((c) {
                final isExpired = c.endTime != null && now.isAfter(c.endTime!);
                return c.status == 'completed' || isExpired || c.status == 'cancelled';
              }).toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (pendingChallenges.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: JedaColors.warningSoft,
                        borderRadius: JedaRadii.borderR12,
                        border: Border.all(color: JedaColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded, color: JedaColors.warning, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Menunggu persetujuan teman. Tantangan aktif otomatis saat semua menyetujui.',
                              style: JedaTypography.caption.copyWith(
                                color: JedaColors.warning,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Menunggu Konfirmasi',
                      style: JedaTypography.labelBold.copyWith(
                        fontSize: 14,
                        color: JedaColors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...pendingChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                    const SizedBox(height: 16),
                  ],
                  if (activeChallenges.isNotEmpty) ...[
                    Text(
                      'Tantangan Sedang Berjalan',
                      style: JedaTypography.labelBold.copyWith(
                        fontSize: 15,
                        color: JedaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activeChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                    const SizedBox(height: 16),
                  ],
                  if (completedChallenges.isNotEmpty) ...[
                    Text(
                      'Riwayat Tantangan',
                      style: JedaTypography.labelBold.copyWith(
                        fontSize: 15,
                        color: JedaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...completedChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                    const SizedBox(height: 16),
                  ],
                  if (_myChallenges.isEmpty) ...[
                    const JedaCard(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.flag_outlined, size: 36, color: JedaColors.textTertiary),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada tantangan aktif',
                              style: JedaTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Tantangan Komunitas Publik',
                    style: JedaTypography.labelBold.copyWith(
                      fontSize: 15,
                      color: JedaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_globalChallenges.isEmpty)
                    const JedaCard(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.public_outlined, size: 36, color: JedaColors.textTertiary),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada tantangan komunitas aktif saat ini',
                              style: JedaTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._globalChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: false)),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(ChallengeModel item, {required bool isMyChallenge}) {
    final isPending = item.status == 'pending';
    final isCancelled = item.status == 'cancelled';
    final isExpired = item.endTime != null && DateTime.now().isAfter(item.endTime!);
    final isCompleted = item.status == 'completed' || isExpired;

    JedaBadgeVariant badgeVariant;
    String badgeLabel;

    if (isCompleted) {
      badgeVariant = JedaBadgeVariant.neutral;
      badgeLabel = 'Selesai';
    } else if (isPending) {
      badgeVariant = JedaBadgeVariant.warning;
      badgeLabel = 'Menunggu';
    } else if (isCancelled) {
      badgeVariant = JedaBadgeVariant.error;
      badgeLabel = 'Batal';
    } else {
      badgeVariant = JedaBadgeVariant.success;
      badgeLabel = '${item.durationHours} Jam';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: JedaCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengeDetailScreen(challengeId: item.id),
            ),
          ).then((_) => _loadAllData(silent: true));
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: JedaTypography.labelBold.copyWith(
                      fontSize: 14.5,
                      color: JedaColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                JedaBadge(
                  label: badgeLabel,
                  variant: badgeVariant,
                ),
              ],
            ),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.description!,
                style: JedaTypography.bodySecondary.copyWith(fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: JedaColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.appName,
                          style: JedaTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: JedaColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 14, color: JedaColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${item.participantCount} peserta',
                      style: JedaTypography.caption.copyWith(color: JedaColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            if (item.myStatus == 'invited') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: JedaButton(
                      label: 'Tolak',
                      variant: JedaButtonVariant.secondary,
                      height: 36,
                      onPressed: () async {
                        try {
                          await ref.read(apiServiceProvider).respondChallengeInvite(item.id, 'decline');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda menolak tantangan.')));
                          await _loadAllData(silent: true);
                          await _syncChallengeToNative();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: JedaColors.error));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: JedaButton(
                      label: 'Terima',
                      variant: JedaButtonVariant.primary,
                      height: 36,
                      onPressed: () async {
                        try {
                          await ref.read(apiServiceProvider).respondChallengeInvite(item.id, 'accept');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tantangan diterima! 🌱'), backgroundColor: JedaColors.primary));
                          await _loadAllData(silent: true);
                          await _syncChallengeToNative();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: JedaColors.error));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else if (!isMyChallenge && item.challengeType == 'global' && item.status == 'active' && !isCompleted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: _myChallenges.any((c) => c.id == item.id && (c.myStatus == 'accepted' || c.myStatus == null))
                    ? Container(
                        decoration: const BoxDecoration(
                          color: JedaColors.surfaceSecondary,
                          borderRadius: JedaRadii.borderR8,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sudah Diikuti',
                          style: JedaTypography.caption.copyWith(
                            color: JedaColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : JedaButton(
                        label: 'Ikuti Tantangan Komunitas',
                        variant: JedaButtonVariant.primary,
                        height: 34,
                        onPressed: () async {
                          try {
                            await ref.read(apiServiceProvider).joinChallenge(item.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Berhasil bergabung! Mengaktifkan pembatasan...'),
                                backgroundColor: JedaColors.primary,
                              ),
                            );
                            await _loadAllData(silent: true);
                            await _syncChallengeToNative();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal bergabung: $e'), backgroundColor: JedaColors.error),
                            );
                          }
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: LENCANA (BADGES)
  // =========================================================================
  Widget _buildBadgesTab() {
    final earnedCount = _badges.where((b) => b.isEarned).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lencana Tercapai: $earnedCount dari ${_badges.length}',
                style: JedaTypography.labelBold.copyWith(
                  color: JedaColors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
              InkWell(
                onTap: _checkBadgesTrigger,
                borderRadius: JedaRadii.borderR8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_rounded, size: 14, color: JedaColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Periksa Lencana',
                        style: JedaTypography.caption.copyWith(
                          color: JedaColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _badges.isEmpty
              ? const Center(
                  child: Text('Katalog lencana belum tersedia', style: JedaTypography.bodySecondary),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _badges.length,
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    return JedaCard(
                      padding: const EdgeInsets.all(12.0),
                      backgroundColor: badge.isEarned ? JedaColors.surface : JedaColors.surfaceSecondary,
                      borderColor: badge.isEarned ? JedaColors.primary : JedaColors.border,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            badge.iconUrl ?? '🌱',
                            style: TextStyle(
                              fontSize: 32,
                              color: badge.isEarned ? null : JedaColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: JedaTypography.labelBold.copyWith(
                              fontSize: 13,
                              color: badge.isEarned ? JedaColors.textPrimary : JedaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: JedaTypography.caption.copyWith(
                              fontSize: 10.5,
                              color: JedaColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          JedaBadge(
                            label: badge.isEarned ? 'Tercapai' : '+${badge.pointsReward} Pts',
                            variant: badge.isEarned ? JedaBadgeVariant.success : JedaBadgeVariant.neutral,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
