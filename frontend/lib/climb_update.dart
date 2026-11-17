import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/climb_feed.dart';

import 'wall/climb_holds.dart';
import 'wall/hold_picker.dart';

class ClimbUpdatePage extends StatefulWidget {
  final String climbId;
  final bool isDraft;

  const ClimbUpdatePage({
    super.key,
    required this.climbId,
    this.isDraft = false,
  });

  @override
  State<ClimbUpdatePage> createState() => _ClimbUpdatePageState();
}

class _ClimbUpdatePageState extends State<ClimbUpdatePage> {
  ClimbHolds _holds = ClimbHolds(1);
  bool loading = true;
  String? error;

  String climbName = '';
  String climbGrade = '';
  String notes = '';
  bool isPrivate = false;
  int gradeValue = 0;

  @override
  void initState() {
    super.initState();
    _fetchClimbData();
  }

  Future<void> _fetchClimbData() async {
    try {
      final response = await Supabase.instance.client
          .from('climbs')
          .select('name, grade, holds, notes, private')
          .eq('climbid', widget.climbId)
          .maybeSingle();

      if (response != null) {
        climbName = response['name'] ?? '';
        climbGrade = response['grade'] ?? '';
        notes = response['notes'] ?? '';
        isPrivate = response['private'] == true;
        gradeValue = climbGrade == '?'
            ? -1
            : int.tryParse(climbGrade.replaceAll(RegExp(r'[vV]'), '')) ?? 0;

        // Keep the climb on the wall it was set on.
        _holds = ClimbHolds.fromJson(response['holds']);
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        error = 'Error fetching climb: $e';
        loading = false;
      });
    }
  }

  Future<void> _save({bool publish = false}) async {
    try {
      final Map<String, dynamic> update = {
        'name': climbName,
        'grade': climbGrade,
        'notes': notes.isEmpty ? null : notes,
        'holds': _holds.toJson(),
        'private': isPrivate,
      };
      if (widget.isDraft) update['draft'] = publish ? false : true;

      await Supabase.instance.client
          .from('climbs')
          .update(update)
          .eq('climbid', widget.climbId);
      ClimbFeed.instance.invalidate();

      if (mounted) {
        final message = widget.isDraft
            ? (publish ? 'Climb published!' : 'Draft saved!')
            : 'Climb updated successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, widget.isDraft ? (publish ? 'published' : 'saved') : true);
      }
    } catch (e) {
      debugPrint('Error saving climb: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String updatedName = climbName;
    String updatedNotes = notes;
    int updatedGradeValue = gradeValue;
    bool updatedPrivate = isPrivate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Wrap(
              children: [
                Text(
                  widget.isDraft ? 'Edit Draft' : 'Update Climb',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16, width: double.infinity),
                TextFormField(
                  initialValue: climbName,
                  decoration: const InputDecoration(labelText: 'Climb Name'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter a name' : null,
                  onSaved: (v) => updatedName = v ?? '',
                ),
                TextFormField(
                  initialValue: notes,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 1,
                  onSaved: (v) => updatedNotes = v ?? '',
                ),
                StatefulBuilder(
                  builder: (ctx, setModalState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Grade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: updatedGradeValue.toDouble(),
                          min: -1,
                          max: 17,
                          divisions: 18,
                          label: updatedGradeValue == -1
                              ? '?'
                              : 'V$updatedGradeValue',
                          onChanged: (v) => setModalState(
                              () => updatedGradeValue = v.round()),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Selected Grade: ${updatedGradeValue == -1 ? '?' : 'V$updatedGradeValue'}',
                          ),
                        ),
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          title: const Text('Private'),
                          subtitle: const Text(
                            'Only you can see this climb',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: updatedPrivate,
                          onChanged: (v) => setModalState(
                              () => updatedPrivate = v ?? false),
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    if (widget.isDraft) ...[
                      OutlinedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          formKey.currentState!.save();
                          climbName = updatedName;
                          notes = updatedNotes;
                          climbGrade = updatedGradeValue == -1 ? '?' : 'V$updatedGradeValue';
                          gradeValue = updatedGradeValue;
                          isPrivate = updatedPrivate;
                          Navigator.pop(ctx);
                          _save(publish: false);
                        },
                        child: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          formKey.currentState!.save();
                          climbName = updatedName;
                          notes = updatedNotes;
                          climbGrade = updatedGradeValue == -1 ? '?' : 'V$updatedGradeValue';
                          gradeValue = updatedGradeValue;
                          isPrivate = updatedPrivate;
                          Navigator.pop(ctx);
                          _save(publish: true);
                        },
                        child: const Text('Publish'),
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          formKey.currentState!.save();
                          climbName = updatedName;
                          notes = updatedNotes;
                          climbGrade = updatedGradeValue == -1 ? '?' : 'V$updatedGradeValue';
                          gradeValue = updatedGradeValue;
                          isPrivate = updatedPrivate;
                          Navigator.pop(ctx);
                          _save();
                        },
                        child: const Text('Save'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDraft
            ? (climbName.isEmpty ? 'Edit Draft' : climbName)
            : 'Update Climb'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: HoldPicker(
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
                                      'Select at least one START and one FINISH hold.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _openForm(context);
                            },
                            icon: Icon(widget.isDraft ? Icons.arrow_forward : Icons.save),
                            label: Text(widget.isDraft ? 'Next' : 'Save Changes'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
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
}
