import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/AuthService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  String username = "";
  List<Map<String, dynamic>> climbsSentStats = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadClimbsSentStats();
  }

  void logout() async {
    await authService.signOut();
  }

  void openLogbook() {
    // TODO: Navigator.push to your Logbook screen
    print("Logbook tapped");
  }

  List<BarChartGroupData> _buildBarChartGroups() {
    final Map<int, int> gradeCounts = {};

    for (final climb in climbsSentStats) {
      final climbData = climb['climbs'] ?? {};
      final dynamic gradeValue = climbData['grade'];

      int gradeNum;
      if (gradeValue is String && gradeValue.toLowerCase().startsWith('v')) {
        gradeNum = int.tryParse(gradeValue.substring(1)) ?? 0;
      } else if (gradeValue is int) {
        gradeNum = gradeValue;
      } else {
        continue;
      }

      gradeCounts[gradeNum] = (gradeCounts[gradeNum] ?? 0) + 1;
    }

    return List.generate(11, (i) {
      final count = gradeCounts[i] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            width: 15,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });
  }

  Map<String, double> _getNiceYAxis() {
    final counts = List<int>.generate(11, (i) {
      int count = 0;
      for (final climb in climbsSentStats) {
        final climbData = climb['climbs'] ?? {};
        final dynamic gradeValue = climbData['grade'];

        int gradeNum;
        if (gradeValue is String && gradeValue.toLowerCase().startsWith('v')) {
          gradeNum = int.tryParse(gradeValue.substring(1)) ?? 0;
        } else if (gradeValue is int) {
          gradeNum = gradeValue;
        } else {
          continue;
        }

        if (gradeNum == i) count++;
      }
      return count;
    });

    int maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return {'maxY': 1, 'interval': 1};

    double magnitude = (maxCount / 10).ceilToDouble();
    double niceInterval;
    if (magnitude <= 1) {
      niceInterval = 1;
    } else if (magnitude <= 2) {
      niceInterval = 2;
    } else if (magnitude <= 5) {
      niceInterval = 5;
    } else {
      niceInterval = 10;
    }
    double niceMaxY = (maxCount / niceInterval).ceil() * niceInterval;
    return {'maxY': niceMaxY, 'interval': niceInterval};
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        username = user.userMetadata?['display_name'] ?? '';
      });
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );
      setState(() => username = newName);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Display name updated")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error updating name: $e")));
      }
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: username);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Display Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Display Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateDisplayName(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadClimbsSentStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('climbssent')
          .select(''' climbid, climbs(climbid, name, grade) ''')
          .eq('''id''', user.id);

      setState(() {
        climbsSentStats = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print("❌ Error loading climbs sent stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final yAxis = _getNiceYAxis();

    return Scaffold(
      appBar: AppBar(
        title: Text("FA Spray Wall"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      username.isNotEmpty
                          ? username
                          : "No display name set, please tap the settings icon to set name.",
                      style: Theme.of(context).textTheme.titleLarge,
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: "Edit Display Name",
                    onPressed: _showEditNameDialog,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openLogbook,
                child: const Text("Logbook"),
              ),
              const SizedBox(height: 10),
              if (climbsSentStats.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text("Sends", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: _buildBarChartGroups(),
                      maxY: yAxis['maxY'],
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: false,
                        drawVerticalLine: true,
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int grade = value.toInt();
                              if (grade >= 0 && grade <= 10) {
                                return Text(
                                  'v$grade',
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: yAxis['interval'],
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value % 1 == 0 && value > 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      alignment: BarChartAlignment.spaceAround,
                    ),
                  ),
                ),
              ] else
                const Text("No climbs sent yet"),
            ],
          ),
        ),
      ),
    );
  }
}
