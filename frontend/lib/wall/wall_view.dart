import 'package:flutter/material.dart';
import '../perf.dart';

import 'climb_holds.dart';
import 'spray_wall.dart';

Color holdRoleColor(int role) => switch (role) {
      HoldRole.hand => Colors.blue,
      HoldRole.foot => Colors.orange,
      HoldRole.start => Colors.green,
      HoldRole.finish => Colors.purple,
      _ => Colors.transparent,
    };

String holdRoleLabel(int role) => switch (role) {
      HoldRole.hand => 'Hand',
      HoldRole.foot => 'Foot',
      HoldRole.start => 'Start',
      HoldRole.finish => 'Finish',
      _ => '',
    };

/// Zoomable photo of a wall with the holds of one climb drawn on top.
///
/// Fits the photo inside the space it is given. Pinch to zoom up to
/// [maxScale]; taps report the hold under the finger through [onHoldTap].
class WallView extends StatefulWidget {
  final SprayWall wall;
  final Map<int, int> roles;
  final ValueChanged<int>? onHoldTap;
  final ValueChanged<int>? onHoldLongPress;

  /// Draw a faint outline around every hold (helps find small holds).
  final bool showAllHolds;

  /// Darken the photo everywhere except the marked holds.
  final bool dimOthers;
  final double maxScale;

  /// Finger tolerance in screen pixels for taps that land just off a hold.
  final double tapTolerance;

  final TransformationController? controller;

  /// On tall screens, start zoomed in so the photo fills the height.
  final bool fillHeightOnStart;

  const WallView({
    super.key,
    required this.wall,
    required this.roles,
    this.onHoldTap,
    this.onHoldLongPress,
    this.showAllHolds = false,
    this.dimOthers = false,
    this.maxScale = 16,
    this.tapTolerance = 14,
    this.controller,
    this.fillHeightOnStart = false,
  });

  @override
  State<WallView> createState() => _WallViewState();
}

class _WallViewState extends State<WallView> {
  late TransformationController _controller =
      widget.controller ?? TransformationController();
  bool _didInitialZoom = false;
  bool _markedVisible = false;

  /// Full-size photo requested (stays on once needed).
  bool _needFull = false;
  double _fitWidth = 0;
  double _dpr = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkResolution);
  }

  /// Switch to the full-size photo once the screen shows more pixels than
  /// the small photo has.
  void _checkResolution() {
    if (_needFull || _fitWidth == 0) return;
    final zoom = _controller.value.getMaxScaleOnAxis();
    if (_fitWidth * zoom * _dpr > widget.wall.previewWidth * 1.15) {
      setState(() => _needFull = true);
    }
  }

  void _initialZoom(Size viewport, Size photo) {
    if (_didInitialZoom || !widget.fillHeightOnStart) return;
    _didInitialZoom = true;
    final s = (viewport.height / photo.height).clamp(1.0, widget.maxScale);
    if (s < 1.15) return;
    // Scale about the viewport centre so the middle of the wall stays in view.
    final c = viewport.center(Offset.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = Matrix4.identity()
        ..translateByDouble(c.dx * (1 - s), c.dy * (1 - s), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    });
  }

  @override
  void didUpdateWidget(covariant WallView old) {
    super.didUpdateWidget(old);
    if (widget.controller != null && widget.controller != _controller) {
      _controller.removeListener(_checkResolution);
      _controller = widget.controller!;
      _controller.addListener(_checkResolution);
    }
    if (old.wall != widget.wall) _needFull = false;
  }

  @override
  void dispose() {
    _controller.removeListener(_checkResolution);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  int? _hit(Offset local, double fitScale) {
    final zoom = _controller.value.getMaxScaleOnAxis();
    final p = local / fitScale;
    final tol = widget.tapTolerance / (fitScale * zoom);
    return widget.wall.holdAt(p, tolerance: tol);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wall = widget.wall;
      double w = c.maxWidth;
      double h = w / wall.aspectRatio;
      if (c.hasBoundedHeight && h > c.maxHeight) {
        h = c.maxHeight;
        w = h * wall.aspectRatio;
      }
      final fitScale = w / wall.width;
      _fitWidth = w;
      _dpr = MediaQuery.devicePixelRatioOf(context);
      if (!_needFull &&
          w * _controller.value.getMaxScaleOnAxis() * _dpr > wall.previewWidth * 1.15) {
        _needFull = true;
      }
      if (c.hasBoundedHeight) {
        _initialZoom(Size(c.maxWidth, c.maxHeight), Size(w, h));
      }
      final interactive = widget.onHoldTap != null || widget.onHoldLongPress != null;

      Widget map = SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Image.asset(
                wall.previewAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, sync) {
                  if (sync || frame != null) {
                    if (!_markedVisible) {
                      _markedVisible = true;
                      Perf.mark('wall-${wall.id}-visible');
                    }
                    return child;
                  }
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            // Full-size photo on top once it has loaded; until then the small
            // one stays visible underneath.
            if (_needFull)
              RepaintBoundary(
                child: Image.asset(
                  wall.asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  frameBuilder: (context, child, frame, sync) =>
                      (sync || frame != null) ? child : const SizedBox.shrink(),
                ),
              ),
            CustomPaint(
              painter: HoldPainter(
                wall: wall,
                roles: widget.roles,
                scale: fitScale,
                showAll: widget.showAllHolds,
                dim: widget.dimOthers,
                transform: _controller,
              ),
            ),
          ],
        ),
      );

      if (interactive) {
        map = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onHoldTap == null
              ? null
              : (d) {
                  final i = _hit(d.localPosition, fitScale);
                  if (i != null) widget.onHoldTap!(i);
                },
          onLongPressStart: widget.onHoldLongPress == null
              ? null
              : (d) {
                  final i = _hit(d.localPosition, fitScale);
                  if (i != null) widget.onHoldLongPress!(i);
                },
          child: map,
        );
      }

      return ClipRect(
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: widget.maxScale,
          child: SizedBox(
            width: c.maxWidth,
            height: c.hasBoundedHeight ? c.maxHeight : h,
            child: Center(child: map),
          ),
        ),
      );
    });
  }
}

class HoldPainter extends CustomPainter {
  final SprayWall wall;
  final Map<int, int> roles;
  final double scale;
  final bool showAll;
  final bool dim;
  final TransformationController transform;

  HoldPainter({
    required this.wall,
    required this.roles,
    required this.scale,
    required this.showAll,
    this.dim = false,
    required this.transform,
  }) : super(repaint: transform);

  Path _path(List<Offset> pts) =>
      Path()..addPolygon([for (final p in pts) p * scale], true);

  @override
  void paint(Canvas canvas, Size size) {
    // Keep line widths constant on screen at any zoom.
    final zoom = transform.value.getMaxScaleOnAxis();
    final px = 1 / zoom;

    if (showAll) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * px
        ..color = Colors.white.withValues(alpha: 0.75);
      final shadow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * px
        ..color = Colors.black.withValues(alpha: 0.45);
      for (int i = 0; i < wall.holds.length; i++) {
        if (roles.containsKey(i)) continue;
        final path = _path(wall.holds[i]);
        canvas.drawPath(path, shadow);
        canvas.drawPath(path, outline);
      }
    }

    if (dim && roles.isNotEmpty) {
      final shade = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size);
      for (final i in roles.keys) {
        shade.addPath(_path(wall.holds[i]), Offset.zero);
      }
      canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.5));
    }

    // Draw big holds first so small holds on volumes stay visible.
    final selected = roles.keys.toList()
      ..sort((a, b) => wall.areas[b].compareTo(wall.areas[a]));
    for (final i in selected) {
      final color = holdRoleColor(roles[i]!);
      final path = _path(wall.holds[i]);
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: dim ? 0.3 : 0.45),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5 * px
          ..color = Colors.black.withValues(alpha: 0.6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * px
          ..color = color,
      );
      // Tiny holds are only a few pixels wide when zoomed out: ring them so
      // they can be seen.
      final b = wall.bounds[i];
      final onScreen = b.longestSide * scale * zoom;
      if (onScreen < 16) {
        final c = b.center * scale;
        canvas.drawCircle(
          c,
          10 * px,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * px
            ..color = Colors.black.withValues(alpha: 0.6),
        );
        canvas.drawCircle(
          c,
          10 * px,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * px
            ..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HoldPainter old) =>
      old.roles != roles ||
      old.wall != wall ||
      old.scale != scale ||
      old.showAll != showAll ||
      old.dim != dim;
}
