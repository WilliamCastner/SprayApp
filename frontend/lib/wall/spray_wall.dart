import 'dart:ui';

import 'holds_v2.dart';

/// One physical setup of the spray wall: a photo plus the hold outlines
/// traced on it. Hold indices are only meaningful inside one wall, so every
/// climb records which wall it was set on (see climb_holds.dart).
class SprayWall {
  final int id;
  final String name;

  /// Full-size photo, loaded only when zoomed in far enough to need it.
  final String asset;

  /// Small photo (a few hundred KB) shown first and at normal zoom.
  final String previewAsset;
  final double previewWidth;

  /// Coordinate space of [holds] (the size of the original photo).
  final double width;
  final double height;

  final List<List<Offset>> holds;

  /// Precomputed per-hold bounds and areas for fast hit testing.
  late final List<Rect> bounds = [
    for (final h in holds) _boundsOf(h),
  ];
  late final List<double> areas = [
    for (final h in holds) _areaOf(h),
  ];

  SprayWall({
    required this.id,
    required this.name,
    required this.asset,
    required this.previewAsset,
    required this.previewWidth,
    required this.width,
    required this.height,
    required this.holds,
  });

  double get aspectRatio => width / height;

  static Rect _boundsOf(List<Offset> pts) {
    double l = double.infinity, t = double.infinity;
    double r = -double.infinity, b = -double.infinity;
    for (final p in pts) {
      if (p.dx < l) l = p.dx;
      if (p.dx > r) r = p.dx;
      if (p.dy < t) t = p.dy;
      if (p.dy > b) b = p.dy;
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  static double _areaOf(List<Offset> pts) {
    if (pts.length < 3) return 0;
    double a = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i], q = pts[(i + 1) % pts.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    return a.abs() / 2;
  }

  /// Index of the hold at [p] (wall coordinates), or null.
  ///
  /// A hold that contains [p] wins; if several do (a hold sitting on a
  /// volume), the smallest one wins. Otherwise the nearest hold whose edge is
  /// within [tolerance] wall units is returned, so tiny holds can be hit
  /// without pixel-perfect taps.
  int? holdAt(Offset p, {double tolerance = 0}) {
    int? best;
    double bestArea = double.infinity;
    for (int i = 0; i < holds.length; i++) {
      if (!bounds[i].contains(p)) continue;
      if (areas[i] < bestArea && pointInPolygon(p, holds[i])) {
        best = i;
        bestArea = areas[i];
      }
    }
    if (best != null || tolerance <= 0) return best;

    double bestDist = tolerance;
    for (int i = 0; i < holds.length; i++) {
      if (!bounds[i].inflate(tolerance).contains(p)) continue;
      final d = distanceToPolygon(p, holds[i]);
      if (d <= bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }
}

bool pointInPolygon(Offset point, List<Offset> polygon) {
  bool inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i], pj = polygon[j];
    if ((pi.dy > point.dy) != (pj.dy > point.dy)) {
      final x = (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
      if (point.dx < x) inside = !inside;
    }
  }
  return inside;
}

double distanceToPolygon(Offset p, List<Offset> polygon) {
  if (polygon.length == 1) return (p - polygon.first).distance;
  double best = double.infinity;
  for (int i = 0; i < polygon.length; i++) {
    final a = polygon[i], b = polygon[(i + 1) % polygon.length];
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    double t = len2 == 0 ? 0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final d = (p - (a + ab * t)).distance;
    if (d < best) best = d;
  }
  return best;
}

List<Offset> _toOffsets(List<int> flat) => [
      for (int i = 0; i + 1 < flat.length; i += 2)
        Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
    ];

/// Current setup (photo from the July 2026 reset).
final SprayWall wallV2 = SprayWall(
  id: 2,
  name: 'Current wall',
  asset: 'assets/spray_wall_v2.jpg',
  previewAsset: 'assets/spray_wall_v2_preview.jpg',
  previewWidth: 2048,
  width: 5712,
  height: 4284,
  holds: [for (final h in holdsV2Data) _toOffsets(h)],
);

const int currentWallId = 2;

SprayWall get currentWall => wallById(currentWallId);

/// Wall 1 (the setup before the July 2026 reset) was removed along with
/// its climbs on 2026-11-16; every climb is now on wall 2.
SprayWall wallById(int id) => wallV2;
