/* Continuously listens to auth state 
   Auth = user logged in 
   Not auth = display sign in / register page
*/
import 'package:flutter/material.dart';
import 'package:namer_app/home.dart';
import 'package:namer_app/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Listen to auth state
      stream: Supabase.instance.client.auth.onAuthStateChange,

      // Build based on auth state -> if auth then user is signed in
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return HomeWithNav();
        } else {
          return LoginPage();
        }
      },
    );
  }
}
