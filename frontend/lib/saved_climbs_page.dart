import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'climb_display.dart';
import 'data/climb_feed.dart';
import 'widgets/climb_widgets.dart';

/// Climbs you bookmarked, newest save first.
class SavedClimbsPage extends StatefulWidget {
  const SavedClimbsPage({super.key});

  @override
  State<SavedClimbsPage> createState() => _SavedClimbsPageState();
}

class _SavedClimbsPageState extends State<SavedClimbsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedClimbs = [];

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
      // Only the ids come from saved_climbs; climb details come from the
      // shared cache, so the list matches the rest of the app.
      final results = await Future.wait([
        Supabase.instance.client
            .from('saved_climbs')
            .select('climbid')
            .eq('user_id', userId)
            .order('saved_at', ascending: false),
        ClimbFeed.instance.climbs(force: force),
      ]);
      final ids = [for (final r in results[0] as List) r['climbid'].toString()];
      if (!mounted) return;
      setState(() {
        _savedClimbs = [
          for (final id in ids)
            if (ClimbFeed.instance.cachedClimb(id) case final c?)
              if (!c.isDraft) c,
        ];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading saved climbs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(force: true),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _savedClimbs.isEmpty
                  ? const EmptyState(
                      icon: Icons.bookmark_outline,
                      message: 'Nothing saved yet.\nTap the bookmark on a climb to keep it here.',
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _savedClimbs.length,
                      itemBuilder: (context, index) {
                        final climb = _savedClimbs[index];
                        return ClimbTile(
                          grade: displayGrade(climb),
                          name: climb['name'] ?? '',
                          isPrivate: climb.isPrivate,
                          details: [
                            (climb['displayname'] ?? '').toString(),
                            sendsLabel(sendCount(climb)),
                          ],
                          onTap: () async {
                            final ids = _savedClimbs.map((c) => c['climbid'].toString()).toList();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClimbDisplay(
                                  climbId: climb['climbid'],
                                  climbIds: ids,
                                  currentIndex: index,
                                ),
                              ),
                            );
                            _load(); // a climb may have been unsaved
                          },
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
