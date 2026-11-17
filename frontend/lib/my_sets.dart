import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'climb_creation.dart';
import 'climb_display.dart';
import 'data/climb_feed.dart';
import 'widgets/climb_widgets.dart';

/// Published climbs you set on the current wall (drafts live in Drafts).
class MySetsPage extends StatefulWidget {
  const MySetsPage({super.key});

  @override
  State<MySetsPage> createState() => _MySetsPageState();
}

class _MySetsPageState extends State<MySetsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> myClimbs = [];

  @override
  void initState() {
    super.initState();
    _load();
    ClimbFeed.instance.changes.addListener(_load);
  }

  @override
  void dispose() {
    ClimbFeed.instance.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await ClimbFeed.instance.climbs(force: force);
      if (!mounted) return;
      setState(() {
        myClimbs = rows
            .where((c) => c['id'] == userId && !c.isDraft && c.onCurrentWall)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading my sets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Map<String, dynamic> climb) {
    final ids = myClimbs.map((c) => c['climbid'].toString()).toList();
    final idx = ids.indexOf(climb['climbid'].toString());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimbDisplay(
          climbId: climb['climbid'],
          climbIds: ids,
          currentIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Sets')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(force: true),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : myClimbs.isEmpty
                  ? EmptyState(
                      icon: Icons.construction,
                      message: "You haven't set any climbs on the new wall yet.",
                      actionLabel: 'Set a climb',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClimbsPage()),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: myClimbs.length,
                      itemBuilder: (context, index) {
                        final climb = myClimbs[index];
                        return ClimbTile(
                          grade: displayGrade(climb),
                          name: climb['name'] ?? '',
                          isPrivate: climb.isPrivate,
                          details: [
                            sendsLabel(sendCount(climb)),
                            timeAgo(climb['createdat']?.toString()),
                          ],
                          onTap: () => _open(climb),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
