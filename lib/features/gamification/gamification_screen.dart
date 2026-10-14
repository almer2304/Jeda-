import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_bridge_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';
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
  int _friendSubTabIndex = 0; // 0: Mutual, 1: Following, 2: Followers

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

      // Parallel fetch 3 endpoint utama (sebelumnya sequential → lambat)
      final results = await Future.wait([
        api.getLeaderboard(type: _leaderboardType, scope: _leaderboardScope),
        api.getAllBadges(),
        api.getGlobalChallenges(),
      ]);
      final leaderboardRes = results[0] as List<dynamic>;
      final badgesRes = results[1] as List<BadgeModel>;
      final globalChallengesRes = results[2] as List<ChallengeModel>;

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
          _leaderboard = leaderboardRes;
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
              backgroundColor: const Color(0xFF87A878),
            ),
          );
        }
      }
      ref.read(authStateProvider.notifier).refreshProfile();
      _loadAllData();
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
            backgroundColor: Colors.redAccent,
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
              content: Text('🎉 Selamat! Kamu mendapatkan ${newBadges.length} Badge baru!'),
              backgroundColor: const Color(0xFF87A878),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status badge sudah yang terbaru 🌱'),
              backgroundColor: Color(0xFF87A878),
            ),
          );
        }
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cek badge: $e'), backgroundColor: Colors.redAccent),
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
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Komunitas & Tantangan 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF87A878),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF87A878),
          indicatorWeight: 3,
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: [
            const Tab(text: 'Peringkat', icon: Icon(Icons.leaderboard_outlined, size: 18)),
            Tab(text: 'Teman (${_following.length})', icon: const Icon(Icons.people_outline, size: 18)),
            Tab(text: 'Tantangan (${_myChallenges.length})', icon: const Icon(Icons.flag_outlined, size: 18)),
            const Tab(text: 'Lencana', icon: Icon(Icons.military_tech_outlined, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAllData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF87A878),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Coba Lagi'),
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
                      color: const Color(0xFF87A878),
                      child: _buildLeaderboardTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: const Color(0xFF87A878),
                      child: _buildFriendsTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: const Color(0xFF87A878),
                      child: _buildChallengesTab(),
                    ),
                    RefreshIndicator(
                      onRefresh: () => _loadAllData(),
                      color: const Color(0xFF87A878),
                      child: _buildBadgesTab(),
                    ),
                  ],
                ),
    );
  }

  // =========================================================================
  // TAB 1: LEADERBOARD
  // =========================================================================
  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Top Poin 🌟'),
                selected: _leaderboardType == 'points',
                selectedColor: const Color(0xFF87A878),
                labelStyle: TextStyle(
                  color: _leaderboardType == 'points' ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _leaderboardType = 'points');
                    _loadAllData();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Top Streak 🔥'),
                selected: _leaderboardType == 'streak',
                selectedColor: const Color(0xFF87A878),
                labelStyle: TextStyle(
                  color: _leaderboardType == 'streak' ? Colors.white : Colors.black,
                  fontSize: 12,
                ),
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _leaderboardType = 'streak');
                    _loadAllData();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _leaderboard.isEmpty
              ? const Center(child: Text('Belum ada data peringkat', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final item = _leaderboard[index];
                    final rank = index + 1;
                    final isTop3 = rank <= 3;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTop3 ? const Color(0xFFEAF2E8) : Colors.grey[100],
                          child: Text(
                            rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTop3 ? 18 : 14,
                              color: const Color(0xFF87A878),
                            ),
                          ),
                        ),
                        title: Text(
                          item['display_name'] ?? item['username'] ?? 'User Jeda',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '@${item['username'] ?? 'user'} • 🔥 ${item['current_streak_days'] ?? 0} hari streak',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(
                          '${item['total_points'] ?? 0} Poin',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF87A878),
                          ),
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
  // TAB 2: TEMAN & CARI PENGGUNA
  // =========================================================================
  Widget _buildFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari username atau nama pengguna...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF87A878)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
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
                _buildSubFilterChip('Saling Follow (${_friends.length})', 0),
                const SizedBox(width: 8),
                _buildSubFilterChip('Mengikuti (${_following.length})', 1),
                const SizedBox(width: 8),
                _buildSubFilterChip('Pengikut (${_followers.length})', 2),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        Expanded(
          child: _isSearching
              ? _buildSearchResultsView()
              : _friendSubTabIndex == 0
                  ? _buildUserListView(_friends, emptyMsg: 'Belum ada teman saling follow.\nCari teman dan ajak saling follow!')
                  : _friendSubTabIndex == 1
                      ? _buildUserListView(_following, emptyMsg: 'Kamu belum mengikuti siapapun.\nGunakan pencarian di atas untuk follow!')
                      : _buildUserListView(_followers, emptyMsg: 'Belum ada yang mengikutimu.'),
        ),
      ],
    );
  }

  Widget _buildSubFilterChip(String label, int index) {
    final isSelected = _friendSubTabIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF87A878),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (sel) {
        if (sel) setState(() => _friendSubTabIndex = index);
      },
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Pengguna tidak ditemukan', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isFollowing = _followingUserIds.contains(user.id);
        final isLoadingAction = _loadingActionUserIds.contains(user.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEAF2E8),
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
              ),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('@${user.username} • 🌟 ${user.totalPoints} • 🔥 ${user.currentStreakDays}h', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: SizedBox(
              width: 90,
              height: 34,
              child: ElevatedButton(
                onPressed: isLoadingAction ? null : () => _toggleFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? const Color(0xFFEAF2E8) : const Color(0xFF87A878),
                  foregroundColor: isFollowing ? const Color(0xFF87A878) : Colors.white,
                  elevation: 0,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: isFollowing ? const BorderSide(color: Color(0xFF87A878)) : BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: isLoadingAction
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? const Color(0xFF87A878) : Colors.white,
                        ),
                      )
                    : FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isFollowing ? Icons.check : Icons.add, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              isFollowing ? 'Mengikuti' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
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
              const Icon(Icons.people_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: userList.length,
      itemBuilder: (context, index) {
        final user = userList[index];
        final isFollowing = _followingUserIds.contains(user.id);
        final isLoadingAction = _loadingActionUserIds.contains(user.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEAF2E8),
              child: Text(
                user.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF87A878)),
              ),
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('@${user.username} • 🌟 ${user.totalPoints} • 🔥 ${user.currentStreakDays}h', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: SizedBox(
              width: 90,
              height: 34,
              child: ElevatedButton(
                onPressed: isLoadingAction ? null : () => _toggleFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? const Color(0xFFEAF2E8) : const Color(0xFF87A878),
                  foregroundColor: isFollowing ? const Color(0xFF87A878) : Colors.white,
                  elevation: 0,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: isFollowing ? const BorderSide(color: Color(0xFF87A878)) : BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: isLoadingAction
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? const Color(0xFF87A878) : Colors.white,
                        ),
                      )
                    : FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isFollowing ? Icons.check : Icons.add, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              isFollowing ? 'Mengikuti' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 3: TANTANGAN (CHALLENGES)
  // =========================================================================
  Widget _buildChallengesTab() {
    return Column(
      children: [
        // Create Challenge Action Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateChallengeScreen()),
                );
                if (res == true) _loadAllData();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Buat Tantangan Bareng Teman ⚔️',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87A878),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),

        Expanded(
          child: Builder(builder: (context) {
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
                  child: Row(children: [Icon(Icons.hourglass_top, color: Colors.orange[800], size: 18), const SizedBox(width: 8), const Expanded(child: Text('Menunggu persetujuan semua teman — tantangan akan terkunci otomatis setelah semua menerima.', style: TextStyle(fontSize: 11, height: 1.3)))]),
                ),
                const SizedBox(height: 8),
                const Text('Menunggu Persetujuan ⏳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8D6E00))),
                const SizedBox(height: 8),
                ...pendingChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                const SizedBox(height: 16),
              ],
              if (activeChallenges.isNotEmpty) ...[
                const Text('Tantangan Saya & Teman 👥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...activeChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                const SizedBox(height: 16),
              ],
              if (completedChallenges.isNotEmpty) ...[
                const Text('Riwayat Tantangan Selesai 📜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...completedChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: true)),
                const SizedBox(height: 16),
              ],
              if (_myChallenges.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Column(children: [Icon(Icons.flag_outlined, size: 32, color: Colors.grey), SizedBox(height: 6), Text('Belum ada tantangan pribadi', style: TextStyle(color: Colors.grey, fontSize: 12))]),
                ),
                const SizedBox(height: 16),
              ],

              // Tantangan Global — ditaruh vertikal di bawah, bukan di samping
              const Text(
                'Tantangan Komunitas Jeda 🌐',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (_globalChallenges.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0D9C8)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada tantangan komunitas aktif',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Jadilah yang pertama buat tantangan publik!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                ..._globalChallenges.map((item) => _buildChallengeCard(item, isMyChallenge: false)),
              const SizedBox(height: 24),
            ],
          );
          }),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(ChallengeModel item, {required bool isMyChallenge}) {
    final isPending = item.status == 'pending';
    final isCancelled = item.status == 'cancelled';
    final isExpired = item.endTime != null && DateTime.now().isAfter(item.endTime!);
    final isCompleted = item.status == 'completed' || isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isCompleted
          ? const Color(0xFFF9FBF8)
          : isCancelled
              ? Colors.grey[100]!
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPending
            ? BorderSide(color: Colors.orange[200]!)
            : isCompleted
                ? const BorderSide(color: Color(0xFFCBE3C3))
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengeDetailScreen(challengeId: item.id),
            ),
          ).then((_) => _loadAllData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFEAF2E8)
                          : isPending
                              ? Colors.orange[50]
                              : isCancelled
                                  ? Colors.red[50]
                                  : const Color(0xFFEAF2E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted
                          ? '🏆 Selesai'
                          : isPending
                              ? '⏳ Menunggu'
                              : isCancelled
                                  ? '✕ Batal'
                                  : '${item.durationHours} Jam',
                      style: TextStyle(
                        color: isCompleted
                            ? const Color(0xFF486B3A)
                            : isPending
                                ? Colors.orange[800]
                                : isCancelled
                                    ? Colors.redAccent
                                    : const Color(0xFF87A878),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description!, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Color(0xFF87A878)),
                        const SizedBox(width: 4),
                        Flexible(child: Text('App: ${item.appName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  Text('👥 ${item.participantCount} →', style: const TextStyle(fontSize: 12, color: Color(0xFF87A878), fontWeight: FontWeight.bold)),
                ],
              ),
              // Tombol persetujuan langsung di card — untuk penerima invited (cek myStatus, fallback untuk data lama yang status masih active)
              if (item.myStatus == 'invited') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref.read(apiServiceProvider).respondChallengeInvite(item.id, 'decline');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamu menolak tantangan.')));
                            await _loadAllData();
                            await _syncChallengeToNative();
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.redAccent));
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
                        child: const Text('Tolak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref.read(apiServiceProvider).respondChallengeInvite(item.id, 'accept');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tantangan diterima! 🌱'), backgroundColor: Color(0xFF87A878)));
                            await _loadAllData();
                            await _syncChallengeToNative();
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.redAccent));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF87A878), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8), elevation: 0),
                        child: const Text('Setuju? ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ] else if (isPending && isMyChallenge) ...[
                const SizedBox(height: 8),
                const Text('⏳ Menunggu teman menyetujui...', style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
              ] else if (!isMyChallenge && item.challengeType == 'global' && item.status == 'active' && !isCompleted) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: _myChallenges.any((c) => c.id == item.id && (c.myStatus == 'accepted' || c.myStatus == null))
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_circle, size: 14, color: Color(0xFF87A878)),
                          label: const Text('Sudah Diikuti', style: TextStyle(fontSize: 12, color: Color(0xFF87A878), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF87A878)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await ref.read(apiServiceProvider).joinChallenge(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎉 Berhasil bergabung! Mengaktifkan penguncian...'),
                                    backgroundColor: Color(0xFF87A878),
                                  ),
                                );
                              }
                              await _loadAllData();
                              await _syncChallengeToNative();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal bergabung: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: const Text('Ikuti Tantangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF87A878),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: BADGES (LENCANA)
  // =========================================================================
  Widget _buildBadgesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Koleksi Lencana (${_badges.where((b) => b.isEarned).length}/${_badges.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton.icon(
                onPressed: _checkBadgesTrigger,
                icon: const Icon(Icons.sync, size: 16, color: Color(0xFF87A878)),
                label: const Text('Cek Lencana', style: TextStyle(color: Color(0xFF87A878), fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _badges.isEmpty
              ? const Center(child: Text('Katalog badge belum tersedia'))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _badges.length,
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    return Card(
                      elevation: 0,
                      color: badge.isEarned ? Colors.white : Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: badge.isEarned
                            ? const BorderSide(color: Color(0xFF87A878), width: 1.5)
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              badge.iconUrl ?? '🏅',
                              style: TextStyle(
                                fontSize: 36,
                                color: badge.isEarned ? null : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              badge.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: badge.isEarned ? const Color(0xFF2D2D2D) : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badge.description,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: badge.isEarned ? const Color(0xFFEAF2E8) : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge.isEarned ? 'Tercapai ✅' : '+${badge.pointsReward} Pts',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badge.isEarned ? const Color(0xFF87A878) : Colors.grey[700],
                                ),
                              ),
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
}
