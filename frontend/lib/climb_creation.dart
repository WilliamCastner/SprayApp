import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/climb_feed.dart';
import 'package:uuid/uuid.dart';

import 'wall/climb_holds.dart';
import 'wall/hold_picker.dart';
import 'wall/spray_wall.dart';
import 'wall/wall_view.dart';

class ClimbsPage extends StatefulWidget {
  const ClimbsPage({super.key});

  @override
  State<ClimbsPage> createState() => _ClimbsPageState();
}

class _ClimbsPageState extends State<ClimbsPage> {
  ClimbHolds _holds = ClimbHolds(currentWallId);
  int _pickerKey = 0;
  int _sliderValue = 0;
  bool _isPrivate = false;

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How to Set Holds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pick a hold type below the wall, then tap holds.\n'),
              for (final r in const [HoldRole.start, HoldRole.hand, HoldRole.foot, HoldRole.finish])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: holdRoleColor(r), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(holdRoleLabel(r)),
                  ]),
                ),
              const Text(
                '\nTap a marked hold again, or long-press it, to clear it. '
                'Pinch to zoom in on small holds.\n\n'
                'A climb needs at least 1 start and 1 finish hold.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _insertClimbs(
    String name,
    String grade,
    List<Map<String, dynamic>> holds,
    String climbDescription,
    bool isPrivate,
    bool isDraft,
    bool isSent,
  ) async {
    final climbId = const Uuid().v4();
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['display_name'] ?? 'Unknown';

    final List<Map<String, dynamic>> ascents = isSent
        ? [
            {
              'user_id': user?.id,
              'username': displayName,
              'attempts': null,
              'grade_feel': null,
              'is_flash': false,
              'timestamp': DateTime.now().toIso8601String(),
            }
          ]
        : [];

    try {
      await Supabase.instance.client.from('climbs').insert({
        'climbid': climbId,
        'id': user?.id,
        'name': name,
        'grade': grade,
        'notes': climbDescription.isEmpty ? null : climbDescription,
        'displayname': displayName,
        'holds': holds,
        'private': isPrivate,
        'draft': isDraft,
        'createdat': DateTime.now().toIso8601String(),
        if (isSent) 'ascents': ascents,
        if (isSent) 'sends': 1,
      });
      ClimbFeed.instance.invalidate();
    } catch (e) {
      debugPrint("Error inserting climb: $e");
      return false;
    }

    if (!mounted) return true;
    setState(() {
      _holds = ClimbHolds(currentWallId);
      _pickerKey++;
      _isPrivate = false;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Climb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: HoldPicker(
                key: ValueKey(_pickerKey),
                holds: _holds,
                onChanged: () => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (!_holds.hasStartAndFinish) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Select at least one START and one FINISH hold before creating a climb.',
                          ),
                        ),
                      );
                      return;
                    }
                    _openCreateClimbForm(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Climb'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _holds.hasStartAndFinish ? Colors.deepOrange : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateClimbForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String climbName = '';
    String climbDescription = '';
    String climbGrade = '';
    bool isPrivate = _isPrivate;
    bool isDraft = false;
    bool isSent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Wrap(
              children: [
                Text(
                  'Create New Climb',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16, width: double.infinity),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Climb Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter a name' : null,
                  onSaved: (value) => climbName = value ?? '',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 1,
                  onSaved: (value) => climbDescription = value ?? '',
                ),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Grade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _sliderValue.toDouble(),
                          min: -1,
                          max: 17,
                          divisions: 18,
                          label: _sliderValue == -1 ? '?' : 'V$_sliderValue',
                          onChanged: (newValue) {
                            setModalState(() {
                              _sliderValue = newValue.round();
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Selected Grade: ${_sliderValue == -1 ? '?' : 'V$_sliderValue'}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('Private'),
                          subtitle: const Text(
                            'Only you can see this climb',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: isPrivate,
                          onChanged: (value) {
                            setModalState(() {
                              isPrivate = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Sent'),
                          subtitle: const Text(
                            'Mark that you have sent this climb',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: isSent,
                          onChanged: (value) {
                            setModalState(() {
                              isSent = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Save as Draft'),
                          subtitle: const Text(
                            'Save without publishing — edit and publish later',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: isDraft,
                          onChanged: (value) {
                            setModalState(() {
                              isDraft = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
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
                        if (!formKey.currentState!.validate()) return;

                        formKey.currentState!.save();
                        climbGrade = _sliderValue == -1 ? '?' : 'V$_sliderValue';

                        if (!_holds.hasStartAndFinish) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select at least one START and one FINISH hold.',
                              ),
                            ),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        _insertClimbs(
                          climbName,
                          climbGrade,
                          _holds.toJson(),
                          climbDescription,
                          isPrivate,
                          isDraft,
                          isSent,
                        ).then((ok) {
                          // Opened from the climb list: go back to it so the
                          // new climb shows up there.
                          if (ok && !isDraft && mounted && Navigator.canPop(this.context)) {
                            Navigator.pop(this.context, true);
                          }
                          messenger.showSnackBar(SnackBar(
                            content: Text(ok
                                ? (isDraft ? 'Draft saved' : 'Climb "$climbName" created')
                                : 'Could not save the climb. Check your connection and try again.'),
                          ));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16, width: double.infinity),
              ],
            ),
          ),
        );
      },
    );
  }
}
