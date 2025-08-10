import 'package:flutter/material.dart';
import 'package:namer_app/AuthService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  List<dynamic> climbs = [];

  void logout() async {
    await authService.signOut();
  }

  Future<void> loadClimbs() async {
    try {
      final data = await Supabase.instance.client
          .from('climbs')
          .select('name, grade')
          .limit(10);

      setState(() {
        climbs = data;
      });

      print("✅ Retrieved climbs: $data");
    } catch (e, stack) {
      print("❌ Exception occurred: $e");
      print("📍 Stack trace: $stack");

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // Keeps everything centered
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Vertically centered
            crossAxisAlignment:
                CrossAxisAlignment.center, // Horizontally centered
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 24),
              Text("Username: ", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: logout, child: const Text("Logout")),
              ElevatedButton(
                onPressed: loadClimbs,
                child: const Text("Load First 10 Climbs"),
              ),
              const SizedBox(height: 24),
              if (climbs.isNotEmpty)
                Column(
                  children: climbs.map((climb) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 10,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.terrain),
                        title: Text(climb['name'] ?? 'Unnamed Climb'),
                        subtitle: Text('Grade: ${climb['grade'] ?? 'N/A'}'),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
