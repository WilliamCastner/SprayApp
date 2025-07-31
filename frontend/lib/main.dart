import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/AuthGate.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'LoginPage.dart';
import 'RegisterPage.dart';
import 'Climbs.dart';
import 'Profile.dart';
import 'Activity.dart';
import 'ClimbList.dart';

void main() async {
  // Supabase setup

  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvaWxkb2dncGJ1Yml2dWlncW1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3MTUzNTgsImV4cCI6MjA2OTI5MTM1OH0.f2n8gquVdGel81MyE4dD9M68B-IHk-DIxyWaaunbuIc",
    url: "https://foildoggpbubivuigqmj.supabase.co",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AuthGate());
  }
}

// New widget that holds the Bottom Navigation and switches pages
class HomeWithBottomNav extends StatefulWidget {
  const HomeWithBottomNav({super.key});

  @override
  State<HomeWithBottomNav> createState() => _HomeWithBottomNavState();
}

class _HomeWithBottomNavState extends State<HomeWithBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ActivityPage(),
    ClimbsPage(),
    ClimbList(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      backgroundColor: Theme.of(context).colorScheme.surface,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Activity',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.terrain), label: 'Climbs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'My Climbs',
          ), // new
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
