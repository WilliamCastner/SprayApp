import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/wall/climb_holds.dart';
import 'package:namer_app/wall/spray_wall.dart';
import 'package:namer_app/wall/wall_view.dart';

/// A point inside hold [i] where a tap selects hold [i] (not a neighbour or
/// a smaller hold on top of it). Null if no such point exists.
Offset? tapPointFor(SprayWall wall, int i) {
  final poly = wall.holds[i];
  final b = wall.bounds[i];
  // Centroid first, then a fine grid over the bounds, most central first.
  var cx = 0.0, cy = 0.0;
  for (final p in poly) {
    cx += p.dx;
    cy += p.dy;
  }
  final c = Offset(cx / poly.length, cy / poly.length);
  if (wall.holdAt(c) == i) return c;
  final pts = <Offset>[];
  const n = 24;
  for (int y = 0; y <= n; y++) {
    for (int x = 0; x <= n; x++) {
      pts.add(Offset(b.left + b.width * x / n, b.top + b.height * y / n));
    }
  }
  pts.sort((a, b) => (a - c).distance.compareTo((b - c).distance));
  for (final p in pts) {
    if (wall.holdAt(p) == i) return p;
  }
  return null;
}

void main() {
  for (final wall in [wallV2]) {
    group('wall ${wall.id}', () {
      test('has holds inside the photo', () {
        expect(wall.holds, isNotEmpty);
        final frame = Rect.fromLTWH(0, 0, wall.width, wall.height).inflate(1);
        for (int i = 0; i < wall.holds.length; i++) {
          expect(wall.holds[i].length, greaterThanOrEqualTo(3), reason: 'hold $i');
          for (final p in wall.holds[i]) {
            expect(frame.contains(p), isTrue, reason: 'hold $i point $p');
          }
        }
      });
    });
  }

  test('every current-wall hold has a spot that selects it', () {
    final wall = wallV2;
    final unreachable = <int>[];
    for (int i = 0; i < wall.holds.length; i++) {
      if (tapPointFor(wall, i) == null) unreachable.add(i);
    }
    expect(unreachable, isEmpty, reason: 'holds with no tappable spot: $unreachable');
  });

  test('taps just off a small hold still select it', () {
    final wall = wallV2;
    // Smallest hold: tap 1 wall pixel outside its bounds, with tolerance.
    int smallest = 0;
    for (int i = 1; i < wall.holds.length; i++) {
      if (wall.areas[i] < wall.areas[smallest]) smallest = i;
    }
    final b = wall.bounds[smallest];
    final p = Offset(b.right + 1, b.center.dy);
    if (wall.holdAt(p) == null) {
      expect(wall.holdAt(p, tolerance: 12), smallest);
    }
  });

  group('ClimbHolds', () {
    test('legacy JSON (no wall key) is wall 1', () {
      final h = ClimbHolds.fromJson([
        {'array_index': 5, 'holdstate': 3},
        {'array_index': 9, 'holdstate': 4},
      ]);
      expect(h.wallId, 1);
      expect(h.roles, {5: 3, 9: 4});
      expect(h.hasStartAndFinish, isTrue);
    });

    test('round trip keeps wall and roles', () {
      final h = ClimbHolds(2, {3: HoldRole.start, 1: HoldRole.hand, 7: HoldRole.finish});
      final back = ClimbHolds.fromJson(h.toJson());
      expect(back.wallId, 2);
      expect(back.roles, h.roles);
      expect(h.toJson().every((e) => e['wall'] == 2), isTrue);
    });

    test('drops indices outside the wall', () {
      final h = ClimbHolds.fromJson([
        {'array_index': 999999, 'holdstate': 1, 'wall': 2},
        {'array_index': -1, 'holdstate': 1, 'wall': 2},
      ]);
      expect(h.roles, isEmpty);
    });
  });

  testWidgets('every current-wall hold can be tapped in the map at phone zoom',
      (tester) async {
    // iPhone-sized map area.
    tester.view.physicalSize = const Size(390 * 3, 520 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final wall = wallV2;
    final controller = TransformationController();
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 520,
          child: WallView(
            wall: wall,
            roles: const {},
            controller: controller,
            onHoldTap: (i) => tapped = i,
          ),
        ),
      ),
    ));

    const zoom = 8.0; // a comfortable pinch, well under the 16x maximum
    const viewport = Size(390, 520);
    final fit = viewport.width / wall.width; // photo is wider than tall
    final top = (viewport.height - wall.height * fit) / 2;
    final origin = tester.getTopLeft(find.byType(WallView));
    final failures = <int>[];

    for (int i = 0; i < wall.holds.length; i++) {
      final p = tapPointFor(wall, i)!;
      // Point in the un-zoomed child, then zoom so it sits mid-screen.
      final child = Offset(p.dx * fit, top + p.dy * fit);
      final center = viewport.center(Offset.zero);
      controller.value = Matrix4.identity()
        ..translateByDouble(center.dx - child.dx * zoom, center.dy - child.dy * zoom, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1);
      await tester.pump();
      tapped = null;
      await tester.tapAt(origin + center);
      await tester.pump(const Duration(milliseconds: 600));
      if (tapped != i) failures.add(i);
    }
    expect(failures, isEmpty, reason: 'holds not selected by a tap: $failures');
  });
}
