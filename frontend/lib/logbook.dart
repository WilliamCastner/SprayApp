import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/climb_feed.dart';
import 'widgets/climb_widgets.dart';
import 'climb_display.dart';

class LogbookPage extends StatefulWidget {
  const LogbookPage({super.key});

  @override
  State<LogbookPage> createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage> {
  List<Map<String, dynamic>> sendLogs = [];
  bool loading = true;

  int totalSends = 0;
  int hardestSendGrade = 0;
  int hardestFlashGrade = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserLogbook();
  }

  int _parseGrade(String? grade) {
    if (grade == null) return 0;
    return int.tryParse(grade.toUpperCase().replaceAll('V', '')) ?? 0;
  }

  Future<void> _fetchUserLogbook({bool force = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = (await ClimbFeed.instance.climbs(force: force))
          .where((c) => c['ascents'] != null);

      final List<Map<String, dynamic>> logs = [];
      int maxSend = 0;
      int maxFlash = 0;

      for (final climb in response) {
        final ascents = climb['ascents'] as List<dynamic>? ?? [];
        final gradeStr = climb['grade'] as String?;
        final gradeNum = _parseGrade(gradeStr);
        final climbId = climb['climbid'] as String;

        for (final ascent in ascents) {
          if (ascent['user_id'] != user.id) continue;

          final isFlash = ascent['is_flash'] ?? false;
          final attempts = ascent['attempts'];
          final gradeFeel = ascent['grade_feel'];

          logs.add({
            'climbid': climbId,
            'climb_name': climb['name'] ?? 'Unnamed',
            'grade': gradeStr ?? '',
            'grade_num': gradeNum,
            'is_flash': isFlash,
            'attempts': attempts,
            'grade_feel': gradeFeel,
            'timestamp': ascent['timestamp'],
          });

          final effectiveFlash = isFlash || (attempts as int?) == 1;
          if (gradeNum > maxSend) maxSend = gradeNum;
          if (effectiveFlash && gradeNum > maxFlash) maxFlash = gradeNum;
        }
      }

      logs.sort((a, b) {
        final aTime = a['timestamp'] ?? '';
        final bTime = b['timestamp'] ?? '';
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        sendLogs = logs;
        totalSends = logs.length;
        hardestSendGrade = maxSend;
        hardestFlashGrade = maxFlash;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching logbook: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  /// Delete a log entry by matching user_id + timestamp in the climb's ascents array.
  Future<void> _deleteLog(int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final log = sendLogs[index];
    final climbId = log['climbid'] as String;
    final timestamp = log['timestamp'];

    try {
      final climbResponse = await Supabase.instance.client
          .from('climbs')
          .select('ascents')
          .eq('climbid', climbId)
          .maybeSingle();
      if (climbResponse == null) return;

      final List<dynamic> currentAscents =
          List<dynamic>.from(climbResponse['ascents'] ?? []);
      currentAscents.removeWhere(
          (a) => a['user_id'] == user.id && a['timestamp'] == timestamp);

      final uniqueSends =
          currentAscents.map((a) => a['user_id']).toSet().length;

      await Supabase.instance.client
          .from('climbs')
          .update({'ascents': currentAscents, 'sends': uniqueSends})
          .eq('climbid', climbId);

      ClimbFeed.instance.invalidate();
      await _fetchUserLogbook(force: true);
    } catch (e) {
      debugPrint('Error deleting log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Update an existing ascent in place (matched by user_id + timestamp).
  Future<void> _updateLog(
      int index, int? newAttempts, int? newGradeFeel) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final log = sendLogs[index];
    final climbId = log['climbid'] as String;
    final timestamp = log['timestamp'];

    try {
      final climbResponse = await Supabase.instance.client
          .from('climbs')
          .select('ascents')
          .eq('climbid', climbId)
          .maybeSingle();
      if (climbResponse == null) return;

      final List<dynamic> currentAscents =
          List<dynamic>.from(climbResponse['ascents'] ?? []);

      for (int i = 0; i < currentAscents.length; i++) {
        final a = currentAscents[i];
        if (a['user_id'] == user.id && a['timestamp'] == timestamp) {
          currentAscents[i] = {
            ...Map<String, dynamic>.from(a),
            'attempts': newAttempts,
            'grade_feel': newGradeFeel,
            'is_flash': newAttempts == 0 || newAttempts == 1,
          };
          break;
        }
      }

      await Supabase.instance.client
          .from('climbs')
          .update({'ascents': currentAscents})
          .eq('climbid', climbId);

      ClimbFeed.instance.invalidate();
      await _fetchUserLogbook(force: true);
    } catch (e) {
      debugPrint('Error updating log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditSheet(int index) {
    final log = sendLogs[index];

    // Map stored attempts back to slider value (0 = Flash, 31 = 30+)
    int attemptsSlider = (log['attempts'] as int?) ?? 1;
    if (attemptsSlider > 31) attemptsSlider = 31;

    int gradeSlider = (log['grade_feel'] as int?) ?? -1;
    if (gradeSlider < -1) gradeSlider = -1;
    if (gradeSlider > 17) gradeSlider = 17;

    final List<String> attemptLabels = [
      'Flash',
      ...List.generate(30, (i) => '${i + 1}'),
      '30+',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Wrap(
            children: [
              Text(
                'Edit Ascent — ${log['climb_name']}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16, width: double.infinity),
              StatefulBuilder(
                builder: (ctx, setModal) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Number of Attempts',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: attemptsSlider.toDouble(),
                        min: 0,
                        max: 31,
                        divisions: 31,
                        label: attemptLabels[attemptsSlider],
                        onChanged: (v) =>
                            setModal(() => attemptsSlider = v.round()),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child:
                            Text('Attempts: ${attemptLabels[attemptsSlider]}'),
                      ),
                      const Text('Grade Feel',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: gradeSlider.toDouble(),
                        min: -1,
                        max: 17,
                        divisions: 18,
                        label:
                            gradeSlider == -1 ? '?' : 'V$gradeSlider',
                        onChanged: (v) =>
                            setModal(() => gradeSlider = v.round()),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            'Grade: ${gradeSlider == -1 ? '?' : 'V$gradeSlider'}'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  ElevatedButton(
                    child: const Text('Save'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateLog(
                        index,
                        attemptsSlider,
                        gradeSlider == -1 ? null : gradeSlider,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16, width: double.infinity),
            ],
          ),
        );
      },
    );
  }

  String _formatGrade(int grade) => grade > 0 ? 'V$grade' : '-';

  String _subtitleText(Map<String, dynamic> send) {
    final isFlash = send['is_flash'] == true;
    final attempts = send['attempts'] as int?;
    final effectiveFlash = isFlash || attempts == 1;
    if (effectiveFlash) return 'Flash';
    if (attempts == null) return 'Send';
    if (attempts >= 31) return 'Send · 30+ attempts';
    return 'Send · $attempts attempts';
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicated, ordered climb ids for the arrows on the climb page.
    final climbIds = <String>[];
    for (final log in sendLogs) {
      final id = log['climbid'] as String;
      if (!climbIds.contains(id)) climbIds.add(id);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Logbook')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _fetchUserLogbook(force: true),
                child: sendLogs.isEmpty
                    ? const EmptyState(
                        icon: Icons.menu_book_outlined,
                        message: 'No sends yet.\nTap "Log Ascent" on a climb after you send it.',
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                          for (int index = 0; index < sendLogs.length; index++)
                            _logTile(index, climbIds),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _logTile(int index, List<String> climbIds) {
    final send = sendLogs[index];
    final climbId = send['climbid'] as String;
    return ClimbTile(
      grade: (send['grade'] as String?)?.isNotEmpty == true ? send['grade'] as String : '?',
      name: send['climb_name'] as String,
      details: [_subtitleText(send), timeAgo(send['timestamp']?.toString())],
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClimbDisplay(
            climbId: climbId,
            climbIds: climbIds,
            currentIndex: climbIds.indexOf(climbId),
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, color: Colors.grey.shade500),
        tooltip: 'Edit or delete',
        onSelected: (v) => v == 'edit' ? _showEditSheet(index) : _confirmDelete(index),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit send')),
          PopupMenuItem(value: 'delete', child: Text('Delete send')),
        ],
      ),
    );
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

  Future<void> _confirmDelete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ascent?'),
        content: Text(
            'Remove "${sendLogs[index]['climb_name']}" from your logbook?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteLog(index);
  }

}
