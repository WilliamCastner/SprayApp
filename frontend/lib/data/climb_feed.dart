import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../perf.dart';
import 'early_feed_stub.dart' if (dart.library.js_interop) 'early_feed_web.dart';
import '../wall/spray_wall.dart';

/// One shared, cached copy of the climbs table (plus setter likes).
///
/// Speed rules:
/// * One request feeds every screen (profile feed, leaderboard, climb list,
///   logbook, user profiles, climb pages).
/// * The last result is saved on the device. On the next launch screens show
///   it at once and a fresh copy loads in the background (stale while
///   revalidate), so the app opens with data instead of a spinner.
/// * Rows include the hold list, so a climb page can draw from the cache
///   without waiting for its own request.
class ClimbFeed {
  ClimbFeed._();
  static final ClimbFeed instance = ClimbFeed._();

  static const Duration maxAge = Duration(seconds: 60);
  static const String _diskKey = 'climb_feed_v2';

  static const String columns =
      'climbid, name, grade, createdat, displayname, private, id, draft, sends, ascents, holds, notes, wall:holds->0->>wall';

  List<Map<String, dynamic>>? _rows;
  List<String> _setterLikes = const [];
  Map<String, Map<String, dynamic>> _byId = const {};
  DateTime? _fetchedAt;
  Future<List<Map<String, dynamic>>>? _inFlight;

  /// True when this launch began with the copy saved on the device.
  bool startedFromSavedCopy = false;

  /// Fired when the data changes: after [invalidate] (a write happened) and
  /// when a background refresh brings new rows. Screens that stay open
  /// listen and re-read.
  final ValueNotifier<int> changes = ValueNotifier(0);

  bool get _fresh =>
      _rows != null &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < maxAge;

  /// Load the copy saved on this device (call once at startup, before
  /// the first screen). Fast: a local read, no network.
  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw == null || _rows != null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      _setRows(
        List<Map<String, dynamic>>.from(
            (d['rows'] as List).map((r) => Map<String, dynamic>.from(r as Map))),
        List<String>.from(d['likes'] as List),
      );
      // Saved copy: show it, but treat it as stale so it refreshes.
      _fetchedAt = null;
      startedFromSavedCopy = true;
    } catch (e) {
      debugPrint('ClimbFeed: no usable saved copy ($e)');
    }
  }

  /// Start the network refresh early (at startup, before the first frame).
  void prefetch() => unawaited(climbs().catchError((_) => const <Map<String, dynamic>>[]));

  /// All climbs, newest first.
  ///
  /// Fresh cache: returned at once. Stale cache (or the saved copy): returned
  /// at once while a refresh runs; [changes] fires when it lands. No cache, or
  /// [force]: waits for the network.
  Future<List<Map<String, dynamic>>> climbs({bool force = false}) {
    if (!force && _fresh) return Future.value(_rows!);
    if (!force && _rows != null) {
      _refresh(notify: true);
      return Future.value(_rows!);
    }
    return _refresh(notify: false);
  }

  /// Setter name of every like (for the leaderboard).
  Future<List<String>> setterLikes() async {
    if (_rows == null) await climbs();
    return _setterLikes;
  }

  /// The cached row for one climb, if any (includes holds).
  Map<String, dynamic>? cachedClimb(String climbId) => _byId[climbId];

  Future<List<Map<String, dynamic>>> _refresh({required bool notify}) {
    return _inFlight ??= _fetch().then((rows) {
      if (notify) changes.value++;
      return rows;
    }).whenComplete(() => _inFlight = null);
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final client = Supabase.instance.client;
    Perf.mark('feed-request');

    // Web: the page already started this request at load time.
    final early = await takeEarlyFeed();
    if (early != null) {
      final rows = [for (final r in early.$1) Map<String, dynamic>.from(r as Map)];
      final likes = [
        for (final l in early.$2)
          if ((l as Map)['setter_name'] != null) l['setter_name'].toString(),
      ];
      _setRows(rows, likes);
      Perf.mark('feed-response');
      if (client.auth.currentSession != null) {
        // The early request was anonymous: refresh as the signed-in user
        // (adds their private climbs) as soon as this one finishes.
        _fetchedAt = null;
        Future(() => _refresh(notify: true));
      } else {
        _fetchedAt = DateTime.now();
        unawaited(_save());
      }
      return rows;
    }

    // Both requests in parallel: one round trip instead of two.
    final results = await Future.wait([
      client.from('climbs').select(columns).order('createdat', ascending: false),
      client.from('liked_climbs').select('setter_name').then<dynamic>((v) => v,
          onError: (Object e) {
        debugPrint('liked_climbs query failed: $e');
        return const [];
      }),
    ]);
    final rows = List<Map<String, dynamic>>.from(results[0] as List);
    final likes = [
      for (final l in (results[1] as List))
        if ((l as Map)['setter_name'] != null) l['setter_name'].toString(),
    ];
    _setRows(rows, likes);
    _fetchedAt = DateTime.now();
    Perf.mark('feed-response');
    unawaited(_save());
    return rows;
  }

  void _setRows(List<Map<String, dynamic>> rows, List<String> likes) {
    _rows = rows;
    _setterLikes = likes;
    _byId = {for (final r in rows) r['climbid'].toString(): r};
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _diskKey, jsonEncode({'rows': _rows, 'likes': _setterLikes}));
    } catch (e) {
      debugPrint('ClimbFeed: could not save ($e)');
    }
  }

  /// Drop the cache after a write so the next read is fresh.
  void invalidate() {
    _fetchedAt = null;
    changes.value++;
  }

  /// Forget everything (sign-out): the next user must not see a saved copy
  /// that includes the previous user's private climbs.
  Future<void> clear() async {
    _rows = null;
    _setterLikes = const [];
    _byId = const {};
    _fetchedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_diskKey);
    } catch (_) {}
    changes.value++;
  }
}

/// Helpers for rows from [ClimbFeed].
extension ClimbRow on Map<String, dynamic> {
  bool get isDraft => this['draft'] == true;
  bool get isPrivate => this['private'] == true;

  /// Wall the climb was set on (climbs saved before wall versions are wall 1).
  int get wallId => int.tryParse(this['wall']?.toString() ?? '') ?? 1;
  bool get onCurrentWall => wallId == currentWallId;

  List<Map<String, dynamic>> get ascentList => [
        for (final a in (this['ascents'] as List<dynamic>? ?? const []))
          if (a is Map) Map<String, dynamic>.from(a),
      ];

  /// Visible to [userId]: published, and public or set by them.
  bool visibleTo(String? userId) =>
      !isDraft && (!isPrivate || (userId != null && this['id'] == userId));
}
