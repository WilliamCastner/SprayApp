// Read-only preview of the whole app with live data and no login.
//
//   flutter run -d chrome -t lib/dev/app_preview_main.dart
//
// Shows the real climbs (public ones) from the database using the public
// key. You are not signed in, so likes, saves, sends and new climbs will not
// save. Use it to look at screens, not to change data.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/climb_feed.dart';
import '../home.dart';
import '../theme.dart';
import '../main.dart' show supabaseAnonKey, supabaseUrl;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Play is bundled in assets/google_fonts: no download at launch.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await ClimbFeed.instance.loadFromDisk();
  ClimbFeed.instance.prefetch();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SprayWall (preview)',
    theme: buildAppTheme(),
    themeMode: ThemeMode.dark,
    home: const Banner(
      message: 'READ-ONLY',
      location: BannerLocation.topEnd,
      color: Colors.deepOrange,
      child: HomeWithNav(),
    ),
  ));
}
