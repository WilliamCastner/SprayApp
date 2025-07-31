import 'package:flutter/material.dart';

class ClimbList extends StatelessWidget {
  const ClimbList({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> mockClimbs = [
      {
        'name': 'Campus Burner',
        'grade': 'V5',
        'description': 'Powerful roof sequence',
      },
      {'name': 'Slab Tech', 'grade': 'V2', 'description': 'Thin techy slab'},
      {
        'name': 'Dyno King',
        'grade': 'V8',
        'description': 'Big explosive moves',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('My Climbs')),
      body: ListView.builder(
        itemCount: mockClimbs.length,
        itemBuilder: (context, index) {
          final climb = mockClimbs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: Text(climb['grade']!),
              ),
              title: Text(climb['name']!),
              subtitle: Text(climb['description']!),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // You could navigate to climb detail page here
              },
            ),
          );
        },
      ),
    );
  }
}
