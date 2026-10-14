import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../core/providers/auth_provider.dart';

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
      final friends = results[0] as List<UserModel>;
      final following = results[1] as List<UserModel>;
      final followers = results[2] as List<UserModel>;

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
        // Update local following ids from results
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
      // Optimistic UI update
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
      _loadAllSocialData();
    } catch (e) {
      // Revert optimistic update on error
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Teman & Pengguna 🤝', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllSocialData,
          ),
        ],
        bottom: !_isSearching
            ? TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF87A878),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF87A878),
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Saling Follow (${_mutualFriends.length})'),
                  Tab(text: 'Mengikuti (${_following.length})'),
                  Tab(text: 'Pengikut (${_followers.length})'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
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

          Expanded(
            child: _isLoading && _searchResults.isEmpty && _following.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF87A878)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                    : _isSearching
                        ? _buildSearchResultsView()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildUserListView(_mutualFriends, emptyMsg: 'Belum ada teman saling follow.\nCari teman dan ajak saling follow!'),
                              _buildUserListView(_following, emptyMsg: 'Kamu belum mengikuti siapapun.\nGunakan pencarian di atas untuk follow!'),
                              _buildUserListView(_followers, emptyMsg: 'Belum ada yang mengikutimu.'),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search_outlined, size: 54, color: Colors.grey),
            SizedBox(height: 12),
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
          margin: const EdgeInsets.only(bottom: 10),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                ),
                child: isLoadingAction
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? const Color(0xFF87A878) : Colors.white,
                        ),
                      )
                    : FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isFollowing ? Icons.check : Icons.add, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              isFollowing ? 'Mengikuti' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
              const Icon(Icons.people_outline, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                ),
                child: isLoadingAction
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? const Color(0xFF87A878) : Colors.white,
                        ),
                      )
                    : FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isFollowing ? Icons.check : Icons.add, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              isFollowing ? 'Mengikuti' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
}
