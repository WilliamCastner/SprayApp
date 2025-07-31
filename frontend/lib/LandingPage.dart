import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Optional: clear auth/session state
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActivitySection(),
            const SizedBox(height: 24),
            const Text(
              'Popular Setters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPopularSettersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    final activities = [
      'Sent V6 on Spray Wall',
      'Unlocked badge: Dyno Master',
      'Liked “Overhang Madness” by Alex',
    ];

    return Column(
      children: activities.map((activity) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.bolt),
            title: Text(activity),
            subtitle: Text('2 hours ago'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPopularSettersSection() {
    final setters = [
      {'name': 'Alex Johnson', 'routes': 15},
      {'name': 'Maya Smith', 'routes': 12},
      {'name': 'David Kim', 'routes': 10},
    ];

    return Column(
      children: setters.map((setter) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text("setter['name']![0]")),
            title: Text("setter['name']!"),
            subtitle: Text('${setter['routes']} routes set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: navigate to setter profile
            },
          ),
        );
      }).toList(),
    );
  }
}
