import 'package:flutter/material.dart';
import 'package:namer_app/Profile.dart';
import 'package:namer_app/ClimbList.dart';
import 'package:namer_app/Climbs.dart'; // This is assumed to be the climb creation page

class HomeWithNav extends StatefulWidget {
  const HomeWithNav({super.key});

  @override
  State<HomeWithNav> createState() => _HomeWithNavState();
}

class _HomeWithNavState extends State<HomeWithNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ProfilePage(),
    ClimbList(),
    ClimbsPage(), // assumed to be the create climb page
  ];

  final List<String> _titles = ['Profile', 'Problems', 'New Climb'];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Climbs'),

          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Create'),
        ],
      ),
    );
  }
}
