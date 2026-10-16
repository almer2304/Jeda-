import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/jeda_colors.dart';
import '../../core/theme/jeda_radii.dart';
import '../../core/theme/jeda_typography.dart';
import '../../core/widgets/jeda_card.dart';
import '../../core/widgets/jeda_button.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<UserModel> _mutualFriends = [];
  List<UserModel> _following = [];
  List<UserModel> _followers = [];
  final Set<String> _followingUserIds = {};

  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  String? _error;
  final Set<String> _loadingActionUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllSocialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSocialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getFriends(),
        api.getFollowing(),
        api.getFollowers(),
      ]);
      final friends = results[0];
      final following = results[1];
      final followers = results[2];

      final followingIds = following.map((u) => u.id).toSet();

      if (mounted) {
        setState(() {
          _mutualFriends = friends;
          _following = following;
          _followers = followers;
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
      _isLoading = true;
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
      _loadAllSocialData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JedaColors.background,
      appBar: AppBar(
        title: Text(
          'Teman & Pengguna',
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
            onPressed: _loadAllSocialData,
            tooltip: 'Segarkan',
          ),
        ],
        bottom: !_isSearching
            ? TabBar(
                controller: _tabController,
                labelColor: JedaColors.primary,
                unselectedLabelColor: JedaColors.textSecondary,
                indicatorColor: JedaColors.primary,
                indicatorWeight: 2.5,
                tabs: [
                  Tab(text: 'Saling Terhubung (${_mutualFriends.length})'),
                  Tab(text: 'Mengikuti (${_following.length})'),
                  Tab(text: 'Pengikut (${_followers.length})'),
                ],
              )
            : null,
      ),
      body: Column(
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
          Expanded(
            child: _isLoading && _searchResults.isEmpty && _following.isEmpty
                ? const Center(child: CircularProgressIndicator(color: JedaColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: JedaTypography.bodySecondary.copyWith(color: JedaColors.error)))
                    : _isSearching
                        ? _buildSearchResultsView()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildUserListView(_mutualFriends, emptyMsg: 'Belum ada teman saling terhubung.\nCari teman dan mulai saling dukung!'),
                              _buildUserListView(_following, emptyMsg: 'Anda belum mengikuti siapa pun.\nGunakan pencarian di atas untuk follow!'),
                              _buildUserListView(_followers, emptyMsg: 'Belum ada yang mengikuti Anda.'),
                            ],
                          ),
          ),
        ],
      ),
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
              SizedBox(height: 12),
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
              const Icon(Icons.people_outline_rounded, size: 54, color: JedaColors.textTertiary),
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
}
