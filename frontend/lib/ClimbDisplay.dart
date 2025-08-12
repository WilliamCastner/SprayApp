import 'dart:convert';
import 'holds.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const double originalImageWidth = 5712;
const double originalImageHeight = 4284;

class ClimbDisplay extends StatefulWidget {
  final String climbId;

  const ClimbDisplay({super.key, required this.climbId});

  @override
  State<ClimbDisplay> createState() => _ClimbDisplayState();
}

class _ClimbDisplayState extends State<ClimbDisplay> {
  late List<HtmlMapHold> holdsList;
  List<Map<String, dynamic>> holdsArray = [];
  bool loading = true;
  String? error;

  String climbName = '';
  String climbGrade = '';

  @override
  void initState() {
    super.initState();
    _fetchClimbData();
    holdsList = holds;
  }

  @override
  void dispose() {
    // Reset all holds to unselected
    for (final hold in holdsList) {
      hold.selected = 0;
    }
    super.dispose();
  }

  Future<void> _fetchClimbData() async {
    try {
      // Fetch holds
      final holdsResponse = await Supabase.instance.client
          .from('climbholds')
          .select()
          .eq('climbid', widget.climbId);

      final fetchedHolds = List<Map<String, dynamic>>.from(holdsResponse);

      // Fetch climb name & grade
      final climbResponse = await Supabase.instance.client
          .from('climbs')
          .select('name, grade')
          .eq('climbid', widget.climbId)
          .maybeSingle();

      if (climbResponse != null) {
        climbName = climbResponse['name'] ?? 'Unnamed Climb';
        climbGrade = climbResponse['grade'] ?? '';
      }

      // Update hold selection states
      for (final holdData in fetchedHolds) {
        final int arrayIndex = holdData['array_index'];
        final int holdState = holdData['holdstate'];

        if (arrayIndex >= 0 && arrayIndex < holdsList.length) {
          holdsList[arrayIndex].selected = holdState;
        }
      }

      setState(() {
        holdsArray = fetchedHolds;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error fetching climb: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageAspectRatio = originalImageWidth / originalImageHeight;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true, // keep back button if any
        title: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final targetRightPos = screenWidth * 0.27;
            final targetLeftPos = screenWidth * 0.225;

            return Stack(
              children: [
                // Centered title
                Center(
                  child: Text(
                    climbName.isEmpty
                        ? 'Loading...'
                        : climbGrade.isEmpty
                        ? climbName
                        : '$climbName $climbGrade',
                    style: const TextStyle(),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Positioned Log button roughly 1/4 from left
                Positioned(
                  right: targetRightPos,
                  top: 0,
                  bottom: 0,
                  child: TextButton.icon(
                    onPressed: () => print("Log button pressed"),
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      'Log',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                Positioned(
                  left: targetLeftPos,
                  top: 0,
                  bottom: 0,
                  child: TextButton.icon(
                    onPressed: () => print("Log button pressed"),
                    icon: const Icon(Icons.info, color: Colors.black),
                    label: const Text(
                      'Info',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          double displayedWidth;
          double displayedHeight;

          if (maxWidth / maxHeight > imageAspectRatio) {
            displayedHeight = maxHeight * 0.75;
            displayedWidth = displayedHeight * imageAspectRatio;
          } else {
            displayedWidth = maxWidth * 0.75;
            displayedHeight = displayedWidth / imageAspectRatio;
          }

          final displayedSize = Size(displayedWidth, displayedHeight);

          return SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: GestureDetector(
                        child: Stack(
                          children: [
                            Image.asset(
                              '../assets/spray_wall.jpeg',
                              width: displayedWidth,
                              height: displayedHeight,
                              fit: BoxFit.fill,
                            ),
                            CustomPaint(
                              size: displayedSize,
                              painter: _HtmlMapPainter(
                                holdsList,
                                displayedWidth / originalImageWidth,
                                displayedHeight / originalImageHeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HtmlMapPainter extends CustomPainter {
  final List<HtmlMapHold> holds;
  final double scaleX;
  final double scaleY;

  _HtmlMapPainter(this.holds, this.scaleX, this.scaleY);

  @override
  void paint(Canvas canvas, Size size) {
    for (final hold in holds) {
      if (hold.selected == 0) continue;

      final scaledPoints = hold.points
          .map((p) => Offset(p.dx * scaleX, p.dy * scaleY))
          .toList();

      final path = Path()..addPolygon(scaledPoints, true);

      final fillPaint = Paint()
        ..color = switch (hold.selected) {
          1 => Colors.blue.withOpacity(0.5),
          2 => Colors.orange.withOpacity(0.5),
          3 => Colors.green.withOpacity(0.5),
          4 => Colors.purple.withOpacity(0.5),
          _ => Colors.transparent,
        }
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HtmlMapPainter oldDelegate) => true;
}
