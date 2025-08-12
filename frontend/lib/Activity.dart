import 'package:flutter/material.dart';

// Not using page currently

// TODO: Add activity page that displays user sends + climb creation

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example list of mock activities
    final activities = [
      "User1 sent a V5 climb",
      "User2 registered a new route",
      "User3 completed 3 climbs",
      "User4 liked your climb",
    ];

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.timeline),
            title: Text(activities[index]),
            subtitle: Text("Just now"),
          );
        },
      ),
    );
  }
}
