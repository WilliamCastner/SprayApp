import 'package:flutter/material.dart';
import 'package:namer_app/auth_gate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:namer_app/data/climb_feed.dart';
import 'package:namer_app/theme.dart';

// Public (anon) project settings. Safe to ship: access is controlled by the
// database's row-level security, not by this key.
const String supabaseUrl = "https://foildoggpbubivuigqmj.supabase.co";
const String supabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvaWxkb2dncGJ1Yml2dWlncW1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM3MTUzNTgsImV4cCI6MjA2OTI5MTM1OH0.f2n8gquVdGel81MyE4dD9M68B-IHk-DIxyWaaunbuIc";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Play is bundled in assets/google_fonts: no download at launch.
  GoogleFonts.config.allowRuntimeFetching = false;

  await Supabase.initialize(
    anonKey: supabaseAnonKey,
    url: supabaseUrl,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Show the saved copy of the climbs right away and start the refresh now,
  // while the first screen is still being built.
  if (Supabase.instance.client.auth.currentSession != null) {
    await ClimbFeed.instance.loadFromDisk();
    ClimbFeed.instance.prefetch();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SprayWall',
      home: const AuthGate(),

      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
    );
  }
}
