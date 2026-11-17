import 'package:flutter/material.dart';

import '../data/climb_feed.dart';

/// Shared pieces so every climb list (Climbs, Logbook, My Sets, Drafts,
/// Saved, profiles) looks and reads the same.

int? gradeNumber(String? grade) {
  final m = RegExp(r'V(\d+)').firstMatch((grade ?? '').toUpperCase());
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// One colour scale for grades everywhere.
Color gradeColor(String? grade) {
  final n = gradeNumber(grade);
  if (n == null) return Colors.grey;
  if (n >= 9) return Colors.red;
  if (n >= 7) return Colors.orange;
  if (n >= 4) return Colors.blue;
  if (n >= 3) return Colors.green;
  return Colors.amber;
}

/// Average felt grade from ascents, else the setter's grade.
String displayGrade(Map<String, dynamic> climb) {
  final grades = climb.ascentList
      .map((a) => a['grade_feel'])
      .whereType<num>()
      .map((g) => g.toInt())
      .toList();
  if (grades.isEmpty) {
    final g = (climb['grade'] ?? '').toString();
    return g.isEmpty ? '?' : g;
  }
  return 'V${(grades.reduce((a, b) => a + b) / grades.length).ceil()}';
}

/// Number of climbers who sent it (one per person).
int sendCount(Map<String, dynamic> climb) =>
    climb.ascentList.map((a) => a['user_id'] ?? a['username']).toSet().length;

String sendsLabel(int n) => n == 1 ? '1 send' : '$n sends';

/// "3d ago", "Yesterday", "Just now", or a date.
String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'Yesterday';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// Rounded grade badge, coloured like tape on the wall.
class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge(this.grade, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        grade,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
      ),
    );
  }
}

/// One climb row: grade badge, name, one line of details, and a trailing
/// widget (chevron by default).
class ClimbTile extends StatelessWidget {
  final String grade;
  final String name;

  /// Short facts shown under the name, joined with " · ".
  final List<String> details;
  final bool isPrivate;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ClimbTile({
    super.key,
    required this.grade,
    required this.name,
    this.details = const [],
    this.isPrivate = false,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 12, color: Colors.grey.shade500);
    final facts = details.where((d) => d.isNotEmpty).join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                GradeBadge(grade),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name.isEmpty ? 'Unnamed climb' : name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                          if (isPrivate) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.lock, size: 13, color: Colors.grey.shade600),
                          ],
                        ],
                      ),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(facts, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered icon + message (+ optional button) for empty lists.
/// Scrollable so pull-to-refresh still works.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 44, color: Colors.grey.shade600),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
