import 'spray_wall.dart';

/// Hold roles stored in the `holds` JSONB column.
class HoldRole {
  static const int none = 0;
  static const int hand = 1;
  static const int foot = 2;
  static const int start = 3;
  static const int finish = 4;
}

/// The holds of one climb: which wall it is on, and the role of each hold
/// (hold index -> role).
///
/// Stored as `[{array_index, holdstate, wall}, ...]`. Climbs saved before
/// wall versions existed have no `wall` key and belong to wall 1.
class ClimbHolds {
  final int wallId;
  final Map<int, int> roles;

  ClimbHolds(this.wallId, [Map<int, int>? roles]) : roles = roles ?? {};

  SprayWall get wall => wallById(wallId);

  bool get isCurrentWall => wallId == currentWallId;

  factory ClimbHolds.fromJson(dynamic json) {
    final list = json is List ? json : const [];
    int wallId = 1;
    final roles = <int, int>{};
    for (final e in list) {
      if (e is! Map) continue;
      final w = e['wall'];
      if (w is int) wallId = w;
      final i = e['array_index'];
      final s = e['holdstate'];
      if (i is int && s is int && s > 0) roles[i] = s;
    }
    final count = wallById(wallId).holds.length;
    roles.removeWhere((i, _) => i < 0 || i >= count);
    return ClimbHolds(wallId, roles);
  }

  List<Map<String, dynamic>> toJson() {
    final keys = roles.keys.toList()..sort();
    return [
      for (final i in keys)
        {'array_index': i, 'holdstate': roles[i], 'wall': wallId},
    ];
  }

  int count(int role) => roles.values.where((r) => r == role).length;

  bool get hasStartAndFinish =>
      roles.containsValue(HoldRole.start) && roles.containsValue(HoldRole.finish);
}
