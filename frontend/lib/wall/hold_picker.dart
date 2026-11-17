import 'package:flutter/material.dart';

import 'climb_holds.dart';
import 'wall_view.dart';

/// Wall map plus controls for choosing the holds of a climb.
///
/// Pick a role (Hand / Foot / Start / Finish), then tap holds. Tapping a
/// hold that already has that role clears it; long-press clears any hold.
/// Edits [holds] in place and calls [onChanged] after each change.
class HoldPicker extends StatefulWidget {
  final ClimbHolds holds;
  final VoidCallback? onChanged;

  const HoldPicker({super.key, required this.holds, this.onChanged});

  @override
  State<HoldPicker> createState() => _HoldPickerState();
}

class _HoldPickerState extends State<HoldPicker> {
  int _role = HoldRole.start;

  @override
  void initState() {
    super.initState();
    // Begin with hands once the climb already has a start hold.
    if (widget.holds.count(HoldRole.start) > 0) _role = HoldRole.hand;
  }

  void _change(void Function(Map<int, int> roles) edit) {
    setState(() => edit(widget.holds.roles));
    widget.onChanged?.call();
  }

  void _tap(int i) {
    _change((roles) {
      if (roles[i] == _role) {
        roles.remove(i);
      } else {
        roles[i] = _role;
      }
    });
    // After two start holds, the next pick is almost always a hand.
    if (_role == HoldRole.start && widget.holds.count(HoldRole.start) >= 2) {
      setState(() => _role = HoldRole.hand);
    }
  }

  void _clearHold(int i) {
    if (!widget.holds.roles.containsKey(i)) return;
    _change((roles) => roles.remove(i));
  }

  @override
  Widget build(BuildContext context) {
    final holds = widget.holds;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: WallView(
            wall: holds.wall,
            roles: holds.roles,
            // Opens with the whole wall visible; pinch to zoom in.
            onHoldTap: _tap,
            onHoldLongPress: _clearHold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              for (final role in const [
                HoldRole.start,
                HoldRole.hand,
                HoldRole.foot,
                HoldRole.finish,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _RoleButton(
                      role: role,
                      count: holds.count(role),
                      selected: _role == role,
                      onTap: () => setState(() => _role = role),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Tap a hold to mark it ${holdRoleLabel(_role).toLowerCase()}. '
            'Tap again or long-press to clear. Pinch to zoom.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  final int role;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.role,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = holdRoleColor(role);
    return Material(
      color: selected ? color.withValues(alpha: 0.28) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? color : Colors.grey.shade700,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  count > 0
                      ? '${holdRoleLabel(role)} $count'
                      : holdRoleLabel(role),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
