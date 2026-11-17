import 'package:flutter/material.dart';
import 'package:namer_app/profile.dart';
import 'package:namer_app/climb_list.dart';
import 'package:namer_app/wall/spray_wall.dart';

class HomeWithNav extends StatefulWidget {
  const HomeWithNav({super.key});

  @override
  State<HomeWithNav> createState() => _HomeWithNavState();
}

class _HomeWithNavState extends State<HomeWithNav> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The small photo is enough for the first look at any climb; the full
    // one loads only when someone zooms in.
    precacheImage(AssetImage(currentWall.previewAsset), context);
  }

  // Both tabs stay alive (IndexedStack), so switching tabs keeps your
  // scroll position and search and does not reload anything.
  final List<Widget> _pages = const [
    ProfilePage(),
    ClimbList(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.terrain_outlined),
            selectedIcon: Icon(Icons.terrain),
            label: 'Climbs',
          ),
        ],
      ),
    );
  }
}
