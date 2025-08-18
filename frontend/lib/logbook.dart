import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _fetchUserSends();
  }

  Future<void> _fetchUserSends() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('climbssent')
          .select('grade, is_flash, comment, climbs(name)')
          .eq('id', userId)
          .order('created_at', ascending: false); // latest first

      if (!mounted) return;

      final List<Map<String, dynamic>> fetchedSends =
          List<Map<String, dynamic>>.from(response);

      int maxSend = 0;
      int maxFlash = 0;

      for (final send in fetchedSends) {
        final gradeNum = send['grade'] ?? 0;
        if (gradeNum > maxSend) maxSend = gradeNum;
        if ((send['is_flash'] ?? false) && gradeNum > maxFlash) {
          maxFlash = gradeNum;
        }
      }

      setState(() {
        sendLogs = fetchedSends;
        totalSends = fetchedSends.length;
        hardestSendGrade = maxSend;
        hardestFlashGrade = maxFlash;
        loading = false;
      });
    } catch (e) {
      print("Error fetching sends: $e");
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _formatGrade(int grade) => 'V$grade';

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Logbook")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard("Total Sends", totalSends.toString()),
                _buildStatCard("Hardest Send", _formatGrade(hardestSendGrade)),
                _buildStatCard(
                  "Hardest Flash",
                  _formatGrade(hardestFlashGrade),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              "Send History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: sendLogs.isEmpty
                  ? const Center(child: Text("No sends logged yet."))
                  : ListView.builder(
                      itemCount: sendLogs.length,
                      itemBuilder: (context, index) {
                        final send = sendLogs[index];
                        final grade = send['grade'] ?? 0;
                        final climbName = send['climbs']?['name'] ?? 'Unnamed';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: grade <= 4
                                ? Colors.green
                                : grade <= 8
                                ? Colors.blue
                                : Colors.red,
                            child: Text(
                              _formatGrade(grade),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),

                          title: Text(climbName),
                          subtitle: Text(
                            "${send['comment'] ?? ''} • ${send['is_flash'] == true ? 'Flash' : ''}",
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Tiny helper widget for stat boxes
  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
