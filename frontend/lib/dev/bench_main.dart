// Speed benchmark (web only). Read-only: uses the public key, no login.
//
//   flutter build web -t lib/dev/bench_main.dart -o build/web_bench
//
// Opens the app the way a climber does and logs, to the browser console:
//   start      page load -> profile and climb list loaded
//   newClimb   tap "New Climb" -> wall photo visible
//   climbPage  open a climb -> climb data and wall photo visible
// as one line: [bench] {"start":..,"newClimb":..,"climbPage":..} (ms).
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../climb_creation.dart';
import '../climb_display.dart';
import '../data/climb_feed.dart';
import '../home.dart';
import '../main.dart' show supabaseAnonKey, supabaseUrl;
import '../perf.dart';
import '../theme.dart';

@JS('performance.now')
external double _now();

@JS('console.log')
external void _log(JSString s);


final _marks = <String, double>{};
final _waiters = <String, Completer<double>>{};

Future<double> _waitFor(String name) {
  if (_marks.containsKey(name)) return Future.value(_marks[name]!);
  return (_waiters[name] ??= Completer<double>()).future;
}

void _record(String name) {
  final t = _now();
  _marks.putIfAbsent(name, () => t);
  _waiters.remove(name)?.complete(t);
}

final _nav = GlobalKey<NavigatorState>();

Future<void> main() async {
  Perf.sink = _record;
  _record('main-start');
  WidgetsFlutterBinding.ensureInitialized();
  // Play is bundled in assets/google_fonts: no download at launch.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await ClimbFeed.instance.loadFromDisk();
  ClimbFeed.instance.prefetch();
  runApp(MaterialApp(
    navigatorKey: _nav,
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    themeMode: ThemeMode.dark,
    home: const HomeWithNav(),
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) => _record('first-frame'));
  unawaited(_run());
}

Future<void> _run() async {
  final firstFrame = await _waitFor('first-frame');
  final profile = await _waitFor('profile-loaded');
  final climbs = await _waitFor('climbs-loaded');
  final start = profile > climbs ? profile : climbs;
  await Future<void>.delayed(const Duration(milliseconds: 500));

  // New Climb page: wall photo of the current wall.
  final t1 = _now();
  _nav.currentState!.push(MaterialPageRoute(builder: (_) => const ClimbsPage()));
  final newClimbDone = await _waitFor('wall-$currentWallBenchId-visible');
  final newClimb = newClimbDone - t1;
  _nav.currentState!.pop();
  await Future<void>.delayed(const Duration(milliseconds: 800));

  // Climb page: the newest climb, if there is one yet.
  double? climbPage;
  final rows = await ClimbFeed.instance.climbs();
  if (rows.isNotEmpty) {
    final t2 = _now();
    _nav.currentState!.push(MaterialPageRoute(
        builder: (_) => ClimbDisplay(climbId: rows.first['climbid'].toString())));
    final data = await _waitFor('climb-data-loaded');
    final wall = await _waitFor('wall-$currentWallBenchId-visible');
    climbPage = (data > wall ? data : wall) - t2;
  }

  _log(('[bench] ${jsonEncode({
    'firstFrame': firstFrame.round(),
    'start': start.round(),
    'newClimb': newClimb.round(),
    'climbPage': climbPage?.round(),
    'savedCopy': ClimbFeed.instance.startedFromSavedCopy,
    'mainStart': (_marks['main-start'] ?? 0).round(),
    'feedReq': (_marks['feed-request'] ?? 0).round(),
    'feedRes': (_marks['feed-response'] ?? 0).round(),
  })}').toJS);
}

const currentWallBenchId = 2;
