import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'climb_update.dart';
import 'data/climb_feed.dart';
import 'widgets/climb_widgets.dart';

/// Climbs you saved as drafts: finish and publish them from here.
class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> drafts = [];

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
        drafts = rows.where((c) => c['id'] == userId && c.isDraft).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading drafts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drafts')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(force: true),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : drafts.isEmpty
                  ? const EmptyState(
                      icon: Icons.edit_note,
                      message: 'No drafts.\nTick "Save as Draft" when creating a climb to finish it later.',
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) {
                        final draft = drafts[index];
                        return ClimbTile(
                          grade: displayGrade(draft),
                          name: draft['name'] ?? '',
                          details: ['Started ${timeAgo(draft['createdat']?.toString())}'],
                          trailing: Icon(Icons.edit_outlined, color: Colors.grey.shade500),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClimbUpdatePage(
                                climbId: draft['climbid'],
                                isDraft: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
