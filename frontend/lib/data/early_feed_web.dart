import 'dart:convert';
import 'dart:js_interop';

/// The climbs request web/index.html starts at page load (before the app's
/// code has even downloaded). Returns its rows once, or null.
@JS('__sprayEarlyFeed')
external JSPromise<JSAny?>? get _earlyFeed;

@JS('__sprayEarlyFeed')
external set _earlyFeed(JSPromise<JSAny?>? value);

Future<(List<dynamic>, List<dynamic>)?> takeEarlyFeed() async {
  final p = _earlyFeed;
  if (p == null) return null;
  _earlyFeed = null; // use it once; later refreshes go through Supabase
  try {
    final result = (await p.toDart)?.dartify();
    if (result is! List || result.isEmpty || result[0] is! String) return null;
    final climbs = jsonDecode(result[0] as String) as List<dynamic>;
    final likes = result.length > 1 && result[1] is String
        ? jsonDecode(result[1] as String) as List<dynamic>
        : const <dynamic>[];
    return (climbs, likes);
  } catch (_) {
    return null;
  }
}
