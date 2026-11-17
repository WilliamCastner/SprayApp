import 'package:flutter/material.dart';
import 'package:namer_app/auth_service.dart';
import 'package:namer_app/my_sets.dart';
import 'package:namer_app/climb_display.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/climb_feed.dart';
import 'perf.dart';
import 'widgets/climb_widgets.dart';
import 'logbook.dart';
import 'drafts.dart';
import 'saved_climbs_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  String username = "";
  List<Map<String, dynamic>> recentActivity = [];
  bool loadingActivity = true;
  List<Map<String, dynamic>> setterLeaderboard = [];
  List<Map<String, dynamic>> sendLeaderboard = [];
  bool leaderboardLoading = true;
  bool _setterTab = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentActivity();
    _loadLeaderboard();
    ClimbFeed.instance.changes.addListener(_onFeedChanged);
  }

  void _onFeedChanged() {
    if (!mounted) return;
    _loadRecentActivity();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    ClimbFeed.instance.changes.removeListener(_onFeedChanged);
    super.dispose();
  }

  /// Pull to refresh: reload activity and leaderboard with one new request.
  Future<void> _refreshFeed() async {
    ClimbFeed.instance.invalidate();
    await Future.wait([_loadRecentActivity(force: true), _loadLeaderboard()]);
  }

  void logout() async {
    await authService.signOut();
  }

  void openLogbook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogbookPage()),
    );
  }

  void openMySets() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MySetsPage()),
    );
  }

  void openDrafts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DraftsPage()),
    );
  }

  void openSaved() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedClimbsPage()),
    );
  }

  void openAllActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllActivityPage()),
    );
  }

  void _openClimb(BuildContext context, String climbId) {
    final seenIds = <String>{};
    final climbIds = <String>[];
    for (final a in recentActivity) {
      final id = a['climb_id']?.toString() ?? '';
      if (id.isNotEmpty && seenIds.add(id)) climbIds.add(id);
    }
    final index = climbIds.indexOf(climbId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClimbDisplay(
          climbId: climbId,
          climbIds: climbIds,
          currentIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        username = user.userMetadata?['display_name'] ?? '';
      });
    }
  }

  Future<void> _deleteAccount() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Deleting account..."),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    await authService.deleteAccount();

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      // Close the loading dialog and anything above the home screen; the
      // sign-out makes AuthGate show the login page by itself.
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text("Account deleted")),
      );
    }
  } catch (e) {
    debugPrint("Error deleting account: $e");
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error deleting account: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  Future<void> _loadRecentActivity({bool force = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Not signed in (read-only preview): stop the spinner.
      if (mounted) setState(() => loadingActivity = false);
      return;
    }

    final currentUserId = user.id;

    try {
      List<Map<String, dynamic>> activities = [];

      // One shared request for every screen (see ClimbFeed).
      final published = (await ClimbFeed.instance.climbs(force: force))
          .where((c) => !c.isDraft)
          .toList();
      final createdClimbs = published;
      final climbsWithAscents =
          published.where((c) => c['ascents'] != null).toList();

      for (final climb in createdClimbs) {
        final isPrivate = climb['private'] == true;
        final creatorId = climb['id'];

        if (isPrivate && creatorId != currentUserId) {
          continue;
        }

        activities.add({
          'type': 'created',
          'climb_id': climb['climbid'].toString(),
          'climb_name': climb['name'] ?? 'Unknown',
          'grade': climb['grade'] ?? '',
          'timestamp': climb['createdat'],
          'display_name': climb['displayname'] ?? '',
          'is_private': isPrivate,
        });
      }

      for (final climb in climbsWithAscents) {
        final isPrivate = climb['private'] == true;
        final creatorId = climb['id'];

        if (isPrivate && creatorId != currentUserId) {
          continue;
        }

        final ascents = climb['ascents'] as List<dynamic>? ?? [];
        for (final ascent in ascents) {
          activities.add({
            'type': 'sent',
            'climb_id': climb['climbid'].toString(),
            'climb_name': climb['name'] ?? 'Unknown',
            'grade': climb['grade'] ?? '',
            'timestamp': ascent['timestamp'],
            'is_flash': ascent['is_flash'] ?? false,
            'attempts': ascent['attempts'],
            'display_name': ascent['username'] ?? '',
            'is_private': isPrivate,
          });
        }
      }

      activities.sort((a, b) {
        final timestampA = a['timestamp'] ?? '';
        final timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        recentActivity = activities.take(5).toList();
        loadingActivity = false;
      });
    } catch (e) {
      debugPrint("Error loading recent activity: $e");
      setState(() {
        loadingActivity = false;
      });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) return 'Just now';
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  /// Check if a username is already taken by another user
  Future<bool> _isUsernameTaken(String newName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return true;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('display_name', newName)
          .neq('id', user.id) // Exclude current user
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint("Error checking username: $e");
      return false; // Allow attempt if check fails
    }
  }

  /// Validate username format
  String? _validateUsername(String name) {
    if (name.isEmpty) {
      return 'Username cannot be empty';
    }
    if (name.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (name.length > 20) {
      return 'Username must be 20 characters or less';
    }
    // Only allow letters, numbers, underscores, and hyphens
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
      return 'Username can only contain letters, numbers, _ and -';
    }
    return null;
  }

void _showDeleteAccountDialog() {
  final confirmController = TextEditingController();
  String? errorText;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Delete Account"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This action cannot be undone. All your data will be permanently deleted:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text("• Your profile"),
              const Text("• All climbs you've created"),
              const Text("• Your logbook entries"),
              const Text("• All activity history"),
              const SizedBox(height: 16),
              Text(
                'Type "DELETE" to confirm:',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: "DELETE",
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final confirmation = confirmController.text.trim();
                if (confirmation != "DELETE") {
                  setDialogState(() {
                    errorText = 'Please type DELETE to confirm';
                  });
                  return;
                }

                Navigator.of(context).pop();
                _deleteAccount();
              },
              child: const Text("Delete Account"),
            ),
          ],
        );
      },
    ),
  );
}

  void _showEditNameDialog() {
    final controller = TextEditingController(text: username);
    String? errorText;
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Edit Display Name"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Display Name",
                    errorText: errorText,
                    helperText: "3-20 characters, letters, numbers, _ or -",
                    suffixIcon: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    // Clear error when user types
                    if (errorText != null) {
                      setDialogState(() {
                        errorText = null;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        final newName = controller.text.trim();

                        // Validate format first
                        final validationError = _validateUsername(newName);
                        if (validationError != null) {
                          setDialogState(() {
                            errorText = validationError;
                          });
                          return;
                        }

                        // Check if same as current username
                        if (newName.toLowerCase() == username.toLowerCase()) {
                          Navigator.of(context).pop();
                          return;
                        }

                        // Check if username is taken
                        setDialogState(() {
                          isChecking = true;
                          errorText = null;
                        });

                        final isTaken = await _isUsernameTaken(newName);

                        if (isTaken) {
                          setDialogState(() {
                            isChecking = false;
                            errorText = 'Username is already taken';
                          });
                          return;
                        }

                        setDialogState(() {
                          isChecking = false;
                        });

                        // Update username
                        Navigator.of(context).pop();
                        _updateDisplayName(newName);
                      },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateDisplayName(String newName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await authService.renameUser(newName);
      ClimbFeed.instance.invalidate();

      setState(() => username = newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Display name updated"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint("Postgrest error: ${e.code} - ${e.message}");

      String errorMessage = "Error updating name";
      if (e.code == '23505') {
        // Unique constraint violation
        errorMessage = "Username is already taken";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ $errorMessage"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating display name: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error updating name: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Change Display Name'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditNameDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () {
                  Navigator.pop(context);
                  logout();
                },
              ),
              const Divider(),
ListTile(
  leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
  title: Text(
    'Delete Account',
    style: TextStyle(color: Colors.red.shade700),
  ),
  onTap: () {
    Navigator.pop(context);
    _showDeleteAccountDialog();
  },
),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final climbId = activity['climb_id'] as String?;
    final type = activity['type'];
    final climbName = activity['climb_name'] ?? 'Unknown';
    final grade = activity['grade'] ?? '';
    final timestamp = _formatTimestamp(activity['timestamp']);
    final isFlash = (activity['is_flash'] ?? false) || (activity['attempts'] as int?) == 1;
    final userName = activity['display_name'] ?? 'User';
    final isPrivate = activity['is_private'] ?? false;

    IconData icon;
    Color iconColor;
    String actionText;

    if (type == 'created') {
      icon = Icons.add_circle_outline;
      iconColor = Colors.green;
      actionText = 'created';
    } else {
      icon = isFlash ? Icons.bolt : Icons.check_circle_outline;
      iconColor = isFlash ? Colors.yellow.shade600 : Colors.blue;
      actionText = isFlash ? 'flashed' : 'sent';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: climbId == null ? null : () => _openClimb(context, climbId),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Text(
              "$userName ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              actionText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                climbName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (grade.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (isPrivate) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock,
                size: 14,
                color: Colors.grey.shade600,
              ),
            ],
          ],
        ),
        subtitle: Text(
          timestamp,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _loadLeaderboard() async {
    try {
      final all = await ClimbFeed.instance.climbs();

      // Fetched together with the climbs (one round trip) and cached.
      final likedNames = await ClimbFeed.instance.setterLikes();

      final climbsForSetters = all;
      final climbsForSends = all.where((c) => c['ascents'] != null).toList();

      // climb count per setter (non-drafts only)
      final setterClimbCounts = <String, int>{};
      for (final c in climbsForSetters) {
        final name = c['displayname']?.toString() ?? '';
        final isDraft = c['draft'] as bool? ?? false;
        if (name.isNotEmpty && !isDraft) {
          setterClimbCounts[name] = (setterClimbCounts[name] ?? 0) + 1;
        }
      }

      // likes per setter — read directly from stored setter_name
      final setterLikeCounts = <String, int>{};
      for (final setter in likedNames) {
        if (setter.isNotEmpty) {
          setterLikeCounts[setter] = (setterLikeCounts[setter] ?? 0) + 1;
        }
      }

      final allSetters = {...setterClimbCounts.keys, ...setterLikeCounts.keys};

      double setterScore(int likes, int climbs) {
        if (climbs == 0) return 0;
        return likes * 2 + (likes / climbs) * 10;
      }

      final setterList = allSetters.map<Map<String, dynamic>>((name) {
        final likes = setterLikeCounts[name] ?? 0;
        final climbs = setterClimbCounts[name] ?? 0;
        return <String, dynamic>{
          'name': name,
          'likes': likes,
          'climbs': climbs,
          'score': setterScore(likes, climbs),
        };
      }).toList()
        ..sort((a, b) =>
            (b['score'] as double).compareTo(a['score'] as double));
      final setterEntries = setterList.take(10).toList();

      // sends: count and hardest grade per climber
      final sendCounts = <String, int>{};
      final hardestGrades = <String, int>{};
      for (final c in climbsForSends) {
        final gradeStr = (c['grade'] as String? ?? '');
        final gradeNum =
            int.tryParse(gradeStr.toUpperCase().replaceAll('V', '')) ?? 0;
        for (final a in (c['ascents'] as List<dynamic>? ?? [])) {
          final name = a['username']?.toString() ?? '';
          if (name.isNotEmpty) {
            sendCounts[name] = (sendCounts[name] ?? 0) + 1;
            if (gradeNum > (hardestGrades[name] ?? 0)) {
              hardestGrades[name] = gradeNum;
            }
          }
        }
      }

      final sendEntries = (sendCounts.entries.map<Map<String, dynamic>>((e) => <String, dynamic>{
        'name': e.key,
        'hardest': hardestGrades[e.key] ?? 0,
        'sends': e.value,
      }).toList()
        ..sort((a, b) => (b['sends'] as int).compareTo(a['sends'] as int)))
        .take(10)
        .toList();

      if (!mounted) return;
      setState(() {
        setterLeaderboard = setterEntries;
        sendLeaderboard = sendEntries;
        leaderboardLoading = false;
      });
      Perf.mark('profile-loaded');
    } catch (e, st) {
      debugPrint('Error loading leaderboard: $e\n$st');
      if (mounted) setState(() => leaderboardLoading = false);
    }
  }

  Widget _buildSetterLeaderboard() {
    if (leaderboardLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (setterLeaderboard.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No data yet.')),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text('Setter',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('Likes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('Climbs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: setterLeaderboard.length,
          itemBuilder: (context, index) {
            final entry = setterLeaderboard[index];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(
                                    displayName: entry['name']),
                              ),
                            ),
                            child: Text(
                              entry['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${entry['likes']}',
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${entry['climbs']}',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSendLeaderboard() {
    if (leaderboardLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (sendLeaderboard.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No data yet.')),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text('Climber',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('Hardest',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text('Sends',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sendLeaderboard.length,
          itemBuilder: (context, index) {
            final entry = sendLeaderboard[index];
            final hardest = entry['hardest'] as int;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(
                                    displayName: entry['name']),
                              ),
                            ),
                            child: Text(
                              entry['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(hardest > 0 ? 'V$hardest' : '-',
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${entry['sends']}',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/FA_logo.png',
          height: 60,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    username.isNotEmpty
                        ? username
                        : "Tap settings to set name",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: openLogbook,
                          icon: const Icon(Icons.book, size: 18),
                          label: const Text("Logbook"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: openMySets,
                          icon: const Icon(Icons.construction, size: 18),
                          label: const Text("My Sets"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: openDrafts,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text("Drafts"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: openSaved,
                          icon: const Icon(Icons.bookmark_outline, size: 18),
                          label: const Text("Saved"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshFeed,
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Activity
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Recent Activity",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (loadingActivity)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (recentActivity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "No recent activity yet.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentActivity.length,
                        itemBuilder: (context, index) =>
                            _buildActivityItem(recentActivity[index]),
                      ),
                    if (!loadingActivity && recentActivity.isNotEmpty)
                      Center(
                        child: TextButton.icon(
                          onPressed: openAllActivity,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text("View All Activity"),
                        ),
                      ),
                    const Divider(height: 1, thickness: 1),
                    // Leaderboard
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Leaderboard",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Manual tab toggle
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _setterTab = true),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _setterTab
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Setters',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: _setterTab
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _setterTab = false),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: !_setterTab
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Sends',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: !_setterTab
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    _setterTab
                        ? _buildSetterLeaderboard()
                        : _buildSendLeaderboard(),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------
/// USER PROFILE PAGE
/// -------------------------
class UserProfilePage extends StatefulWidget {
  final String displayName;
  const UserProfilePage({super.key, required this.displayName});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool loading = true;
  int setCount = 0;
  List<Map<String, dynamic>> sendLogs = [];
  int totalSends = 0;
  int hardestSendGrade = 0;
  int hardestFlashGrade = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  int _parseGrade(String? grade) {
    if (grade == null) return 0;
    return int.tryParse(grade.toUpperCase().replaceAll('V', '')) ?? 0;
  }

  String _formatGrade(int grade) => grade > 0 ? 'V$grade' : '-';

  Future<void> _fetchData() async {
    try {
      final all = await ClimbFeed.instance.climbs();
      final sets = all
          .where((c) => c['displayname'] == widget.displayName && !c.isDraft)
          .toList();
      final climbsWithAscents = all.where((c) => c['ascents'] != null).toList();

      final logs = <Map<String, dynamic>>[];
      int maxSend = 0;
      int maxFlash = 0;

      for (final climb in climbsWithAscents) {
        final ascents = climb['ascents'] as List<dynamic>? ?? [];
        final gradeStr = climb['grade'] as String?;
        final gradeNum = _parseGrade(gradeStr);

        for (final ascent in ascents) {
          if (ascent['username'] != widget.displayName) continue;
          final isFlash = (ascent['is_flash'] ?? false) || (ascent['attempts'] as int?) == 1;
          logs.add({
            'climbid': climb['climbid'].toString(),
            'climb_name': climb['name'] ?? 'Unnamed',
            'grade': gradeStr ?? '',
            'grade_num': gradeNum,
            'is_flash': isFlash,
            'timestamp': ascent['timestamp'],
          });
          if (gradeNum > maxSend) maxSend = gradeNum;
          if (isFlash && gradeNum > maxFlash) maxFlash = gradeNum;
        }
      }

      logs.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

      if (!mounted) return;
      setState(() {
        setCount = sets.length;
        sendLogs = logs;
        totalSends = logs.length;
        hardestSendGrade = maxSend;
        hardestFlashGrade = maxFlash;
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Same layout as your own Logbook: stats, then sends.
    final climbIds = <String>[];
    for (final log in sendLogs) {
      final id = log['climbid']?.toString() ?? '';
      if (id.isNotEmpty && !climbIds.contains(id)) climbIds.add(id);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      _stat('Sends', totalSends.toString()),
                      const SizedBox(width: 8),
                      _stat('Hardest', _formatGrade(hardestSendGrade)),
                      const SizedBox(width: 8),
                      _stat('Best flash', _formatGrade(hardestFlashGrade)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.construction),
                      title: Text('Climbs set  ·  $setCount'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserSetsPage(displayName: widget.displayName),
                        ),
                      ),
                    ),
                  ),
                ),
                if (sendLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No sends yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  for (final send in sendLogs)
                    ClimbTile(
                      grade: (send['grade'] as String?)?.isNotEmpty == true ? send['grade'] as String : '?',
                      name: send['climb_name'] ?? '',
                      details: [
                        send['is_flash'] == true ? 'Flash' : 'Send',
                        timeAgo(send['timestamp']?.toString()),
                      ],
                      onTap: send['climbid'] == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClimbDisplay(
                                    climbId: send['climbid'],
                                    climbIds: climbIds,
                                    currentIndex: climbIds.indexOf(send['climbid']),
                                  ),
                                ),
                              ),
                    ),
              ],
            ),
    );
  }
}

class UserSetsPage extends StatefulWidget {
  final String displayName;
  const UserSetsPage({super.key, required this.displayName});

  @override
  State<UserSetsPage> createState() => _UserSetsPageState();
}

class _UserSetsPageState extends State<UserSetsPage> {
  List<Map<String, dynamic>> climbs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSets();
  }

  Future<void> _fetchSets() async {
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      final rows = await ClimbFeed.instance.climbs();
      if (!mounted) return;
      setState(() {
        climbs = rows
            .where((c) => c['displayname'] == widget.displayName && c.visibleTo(me))
            .toList();
        loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sets: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sets by ${widget.displayName}'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : climbs.isEmpty
              ? const EmptyState(icon: Icons.construction, message: 'No climbs set yet.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: climbs.length,
                  itemBuilder: (context, index) {
                    final climb = climbs[index];
                    return ClimbTile(
                      grade: displayGrade(climb),
                      name: climb['name'] ?? '',
                      details: [sendsLabel(sendCount(climb))],
                      onTap: () {
                        final ids = climbs.map((c) => c['climbid'].toString()).toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClimbDisplay(
                              climbId: climb['climbid'],
                              climbIds: ids,
                              currentIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

/// -------------------------
/// ALL ACTIVITY PAGE
/// -------------------------
class AllActivityPage extends StatefulWidget {
  const AllActivityPage({super.key});

  @override
  State<AllActivityPage> createState() => _AllActivityPageState();
}

class _AllActivityPageState extends State<AllActivityPage> {
  List<Map<String, dynamic>> allActivity = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllActivity();
  }

  void _openClimb(BuildContext context, String climbId) {
    final seenIds = <String>{};
    final climbIds = <String>[];
    for (final a in allActivity) {
      final id = a['climb_id']?.toString() ?? '';
      if (id.isNotEmpty && seenIds.add(id)) climbIds.add(id);
    }
    final index = climbIds.indexOf(climbId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClimbDisplay(
          climbId: climbId,
          climbIds: climbIds,
          currentIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  Future<void> _loadAllActivity({bool force = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final currentUserId = user.id;

    try {
      List<Map<String, dynamic>> activities = [];

      // One shared request for every screen (see ClimbFeed).
      final published = (await ClimbFeed.instance.climbs(force: force))
          .where((c) => !c.isDraft)
          .toList();
      final createdClimbs = published;
      final climbsWithAscents =
          published.where((c) => c['ascents'] != null).toList();

      for (final climb in createdClimbs) {
        final isPrivate = climb['private'] == true;
        final creatorId = climb['id'];

        if (isPrivate && creatorId != currentUserId) {
          continue;
        }

        activities.add({
          'type': 'created',
          'climb_id': climb['climbid'].toString(),
          'climb_name': climb['name'] ?? 'Unknown',
          'grade': climb['grade'] ?? '',
          'timestamp': climb['createdat'],
          'display_name': climb['displayname'] ?? '',
          'is_private': isPrivate,
        });
      }

      for (final climb in climbsWithAscents) {
        final isPrivate = climb['private'] == true;
        final creatorId = climb['id'];

        if (isPrivate && creatorId != currentUserId) {
          continue;
        }

        final ascents = climb['ascents'] as List<dynamic>? ?? [];
        for (final ascent in ascents) {
          activities.add({
            'type': 'sent',
            'climb_id': climb['climbid'].toString(),
            'climb_name': climb['name'] ?? 'Unknown',
            'grade': climb['grade'] ?? '',
            'timestamp': ascent['timestamp'],
            'is_flash': ascent['is_flash'] ?? false,
            'attempts': ascent['attempts'],
            'display_name': ascent['username'] ?? '',
            'is_private': isPrivate,
          });
        }
      }

      activities.sort((a, b) {
        final timestampA = a['timestamp'] ?? '';
        final timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        allActivity = activities;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error loading all activity: $e");
      setState(() {
        loading = false;
      });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) return 'Just now';
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final climbId = activity['climb_id'] as String?;
    final displayName = activity['display_name'] ?? 'User';
    final type = activity['type'];
    final climbName = activity['climb_name'] ?? 'Unknown';
    final grade = activity['grade'] ?? '';
    final timestamp = _formatTimestamp(activity['timestamp']);
    final isFlash = (activity['is_flash'] ?? false) || (activity['attempts'] as int?) == 1;
    final isPrivate = activity['is_private'] ?? false;

    IconData icon;
    Color iconColor;
    String actionText;

    if (type == 'created') {
      icon = Icons.add_circle_outline;
      iconColor = Colors.green;
      actionText = 'Created';
    } else {
      icon = isFlash ? Icons.bolt : Icons.check_circle_outline;
      iconColor = isFlash ? Colors.yellow.shade600 : Colors.blue;
      actionText = isFlash ? 'Flashed' : 'Sent';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: ListTile(
        onTap: climbId == null ? null : () => _openClimb(context, climbId),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Text(
              "$displayName ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              actionText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                climbName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (grade.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (isPrivate) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock,
                size: 14,
                color: Colors.grey.shade600,
              ),
            ],
          ],
        ),
        subtitle: Text(
          timestamp,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Activity"),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : allActivity.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No activity yet",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: allActivity.length,
                  itemBuilder: (context, index) =>
                      _buildActivityItem(allActivity[index]),
                ),
    );
  }
}