import 'package:flutter/material.dart';
import 'package:namer_app/AuthService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  String username = "";
  List<Map<String, dynamic>> climbsSentStats = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadClimbsSentStats();
  }

  void logout() async {
    await authService.signOut();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        username = user.userMetadata?['display_name'] ?? '';
      });
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'display_name': newName}),
      );
      setState(() {
        username = newName;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Display name updated")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error updating name: $e")));
      }
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: username);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Display Name"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Display Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _updateDisplayName(controller.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadClimbsSentStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('climbssent')
          .select(''' climbid, climbs(climbid, name, grade) ''')
          .eq('''id''', user.id);

      setState(() {
        climbsSentStats = List<Map<String, dynamic>>.from(data);
      });

      print("Raw climbs data: $climbsSentStats");
    } catch (e) {
      print("❌ Error loading climbs sent stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),

              // Username with settings icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username.isNotEmpty ? username : "No display name set",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: "Edit Display Name",
                    onPressed: _showEditNameDialog,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              ElevatedButton(onPressed: logout, child: const Text("Logout")),
              const SizedBox(height: 24),
              if (climbsSentStats.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    ...climbsSentStats.map((climb) {
                      final climbData = climb['climbs'] ?? {};
                      final name = climbData['name'] ?? 'Unknown Climb';
                      final grade = climbData['grade'] ?? 'N/A';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                // TODO: Handle climb click (e.g., navigate to climb details)
                                print("Clicked climb: $name ($grade)");
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(name),
                                  Text(
                                    grade,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                )
              else
                const Text("No climbs sent yet"),
            ],
          ),
        ),
      ),
    );
  }
}
