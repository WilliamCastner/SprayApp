import 'package:flutter/material.dart';
import 'package:namer_app/AuthService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _profilePageState();
}

class _profilePageState extends State<ProfilePage> {
  final authService = AuthService();

  void logout() async {
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 24),
              Text("Username: ", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text("Email: ", style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: logout, child: const Text("Logout")),
            ],
          ),
        ),
      ),
    );
  }
}
