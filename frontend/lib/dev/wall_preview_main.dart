// Local preview of the wall map, with no login and no database.
//
//   flutter run -d chrome -t lib/dev/wall_preview_main.dart
//
// Pick holds on the current wall, then switch to "View" to see how the climb
// looks on the climb page. Nothing is saved.
import 'package:flutter/material.dart';

import '../wall/climb_holds.dart';
import '../wall/hold_picker.dart';
import '../wall/spray_wall.dart';
import '../wall/wall_view.dart';

void main() => runApp(const WallPreviewApp());

class WallPreviewApp extends StatelessWidget {
  const WallPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spray Wall preview',
      theme: ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.deepOrange),
      home: const _PreviewPage(),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage();

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  int _tab = 0;
  final _holds = ClimbHolds(currentWallId);

  @override
  Widget build(BuildContext context) {
    final wall = currentWall;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'New Climb (preview)',
          1 => 'Climb view (preview)',
          _ => 'All ${wall.holds.length} holds',
        }),
      ),
      body: SafeArea(
        child: switch (_tab) {
          0 => HoldPicker(holds: _holds, onChanged: () => setState(() {})),
          1 => Center(
              child: AspectRatio(
                aspectRatio: wall.aspectRatio,
                child: WallView(wall: wall, roles: _holds.roles, dimOthers: true),
              ),
            ),
          _ => WallView(
              wall: wall,
              roles: const {},
              showAllHolds: true,
              onHoldTap: (i) => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('Hold #$i'),
                  duration: const Duration(milliseconds: 800),
                )),
            ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'Pick'),
          NavigationDestination(icon: Icon(Icons.visibility), label: 'View'),
          NavigationDestination(icon: Icon(Icons.grid_on), label: 'All holds'),
        ],
      ),
    );
  }
}
