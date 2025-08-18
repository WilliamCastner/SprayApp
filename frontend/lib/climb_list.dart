import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "climb_display.dart";

class ClimbList extends StatefulWidget {
  const ClimbList({super.key});

  @override
  State<ClimbList> createState() => _ClimbListState();
}

class _ClimbListState extends State<ClimbList> {
  String searchQuery = '';
  int minGrade = 0;
  int maxGrade = 16;
  bool onlyMine = false; // NEW
  List<Map<String, dynamic>> allClimbs = [];

  @override
  void initState() {
    super.initState();
    _fetchClimbs();
  }

  Future<void> _fetchClimbs() async {
    try {
      final response = await Supabase.instance.client
          .from('climbs')
          .select('climbid, name, grade, id');

      if (!mounted) return; // <-- check widget is still in tree

      setState(() {
        allClimbs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('❌ Error fetching climbs: $e');
    }
  }

  List<Map<String, dynamic>> get filteredClimbs {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return allClimbs.where((climb) {
      final nameMatch = climb['name'].toString().toLowerCase().contains(
        searchQuery.toLowerCase(),
      );

      final gradeStr = climb['grade'] ?? '';
      final gradeNum = _extractGradeNumber(gradeStr);

      final matchesMine =
          !onlyMine || (userId != null && climb['id'] == userId);

      return nameMatch &&
          gradeNum != null &&
          gradeNum >= minGrade &&
          gradeNum <= maxGrade &&
          matchesMine;
    }).toList();
  }

  int? _extractGradeNumber(String grade) {
    final match = RegExp(r'V(\d+)').firstMatch(grade.toUpperCase());
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  void _showFilterDialog() {
    RangeValues selectedRange = RangeValues(
      minGrade.toDouble(),
      maxGrade.toDouble(),
    );
    bool tempOnlyMine = onlyMine;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Grade'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RangeSlider(
                  min: 0,
                  max: 16,
                  divisions: 16,
                  labels: RangeLabels(
                    'V${selectedRange.start.round()}',
                    'V${selectedRange.end.round()}',
                  ),
                  values: selectedRange,
                  onChanged: (newRange) {
                    setStateDialog(() {
                      selectedRange = newRange;
                    });
                  },
                ),
                Text(
                  'From V${selectedRange.start.round()} to V${selectedRange.end.round()}',
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Set By Me'),
                  value: tempOnlyMine,
                  onChanged: (value) {
                    setStateDialog(() {
                      tempOnlyMine = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                minGrade = selectedRange.start.round();
                maxGrade = selectedRange.end.round();
                onlyMine = tempOnlyMine;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final climbs = filteredClimbs;

    return Scaffold(
      body: Column(
        children: [
          // Search + Filter row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search climbs',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter by Grade',
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),

          // List of climbs
          Expanded(
            child: climbs.isEmpty
                ? const Center(child: Text('No climbs found.'))
                : ListView.builder(
                    itemCount: climbs.length,
                    itemBuilder: (context, index) {
                      final climb = climbs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: () {
                              // default fallback
                              final gradeStr = climb['grade'] ?? '';
                              final match = RegExp(
                                r'V(\d+)',
                              ).firstMatch(gradeStr.toUpperCase());
                              final gradeNum = match != null
                                  ? int.tryParse(match.group(1)!) ?? 0
                                  : 0;

                              if (gradeNum <= 4) {
                                return Colors.green;
                              } else if (gradeNum <= 8) {
                                return Colors.blue;
                              }
                              return Colors.red;
                            }(),
                            child: Text(climb['grade'] ?? '?'),
                          ),

                          title: Text(climb['name'] ?? 'Unnamed Climb'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ClimbDisplay(climbId: climb['climbid']),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
