/* Continuously listens to auth state 
   Auth = user logged in 
   Not auth = display sign in / register page
*/
import 'package:flutter/material.dart';
import 'package:namer_app/Activity.dart';
import 'package:namer_app/LoginPage.dart';
import 'package:namer_app/Profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Listen to auth state
      stream: Supabase.instance.client.auth.onAuthStateChange,

      // Build based on auth state
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return ProfilePage();
        } else {
          return LoginPage();
        }
      },
    );
  }
}
