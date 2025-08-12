import 'dart:convert';
import 'holds.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Original image width x height in pixels
const double originalImageWidth = 5712;
const double originalImageHeight = 4284;

class ClimbDisplay extends StatefulWidget {
  // Climb id for database fetching
  final String climbId;

  // Requires climbid to be passed from climbList
  const ClimbDisplay({super.key, required this.climbId});

  @override
  State<ClimbDisplay> createState() => _ClimbDisplayState();
}

class _ClimbDisplayState extends State<ClimbDisplay> {
  int _sliderValue = 0;
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

  Future<void> _insertSend(int grade) async {
    final user = Supabase.instance.client.auth.currentUser;

    try {
      await Supabase.instance.client.from('climbssent').insert({
        'climbid': widget.climbId,
        'id': user?.id, // make sure to get the user's id string
        'grade': grade,
      });
    } catch (e) {
      print("Error inserting send {$e}");
    }
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

  void _sendForm(BuildContext context) {
    final _formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // for keyboard to push sheet up
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: Wrap(
              children: [
                Text('Log send', style: Theme.of(context).textTheme.titleLarge),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _sliderValue.toDouble(),
                          min: 0,
                          max: 17,
                          divisions: 17,
                          label: 'V$_sliderValue',
                          onChanged: (newValue) {
                            setModalState(() {
                              _sliderValue = newValue.round();
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('Selected Grade: V$_sliderValue'),
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      child: const Text('Save'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          Navigator.pop(context);

                          // For now, just print the info and selected holds:
                          // TODO: send it to database
                          _insertSend(_sliderValue);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _infoForm(BuildContext context) async {
    try {
      // Fetch climb creator
      final creatorResponse = await Supabase.instance.client
          .from('climbs')
          .select('id, grade')
          .eq('climbid', widget.climbId)
          .maybeSingle();

      final userResponse = await Supabase.instance.client.auth.getUser();

      final displayName =
          userResponse.user!.userMetadata?['display_name'] ?? 'Unknown';

      String climbGrade = creatorResponse?['grade'] ?? 'N/A';

      // Fetch sends count
      final sendsResponse = await Supabase.instance.client
          .from('climbssent')
          .select()
          .eq('climbid', widget.climbId);

      int sendsCount = sendsResponse.length;

      // Show bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                Text(
                  'Climb Info',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                // Creator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Created By:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(displayName),
                  ],
                ),
                const Divider(),

                // Grade
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grade:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(climbGrade),
                  ],
                ),
                const Divider(),

                // Sends
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Sends:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(sendsCount.toString()),
                  ],
                ),
                const Divider(),

                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error fetching climb info: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading climb info')));
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
            final targetRightPos = screenWidth * 0.265;
            final targetLeftPos = screenWidth * 0.215;

            return Stack(
              children: [
                // Title
                Center(
                  child: Text(
                    climbName.isEmpty
                        ? 'Loading...'
                        : climbGrade.isEmpty
                        ? climbName
                        : '$climbName |  $climbGrade',
                    style: TextStyle(fontSize: screenWidth / 65),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Log button
                Positioned(
                  right: targetRightPos,
                  top: 0,
                  bottom: 0,
                  child: TextButton.icon(
                    onPressed: () => _sendForm(context),
                    icon: Icon(
                      Icons.add,
                      color: Colors.black,
                      size: screenWidth / 100,
                    ),
                    label: Text(
                      'Log',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth / 100,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),

                // Info button
                Positioned(
                  left: targetLeftPos,
                  top: 0,
                  bottom: 0,
                  child: TextButton.icon(
                    onPressed: () => _infoForm(context),
                    icon: Icon(
                      Icons.info,
                      color: Colors.black,
                      size: screenWidth / 100,
                    ),
                    label: Text(
                      'Info',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth / 100,
                      ),
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
            displayedHeight = maxHeight * 0.9;
            displayedWidth = displayedHeight * imageAspectRatio;
          } else {
            displayedWidth = maxWidth * 0.9;
            displayedHeight = displayedWidth / imageAspectRatio;
          }

          final displayedSize = Size(displayedWidth, displayedHeight);

          return SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 16),
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
