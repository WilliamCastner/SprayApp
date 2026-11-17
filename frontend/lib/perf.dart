/// Tiny timing hooks for the benchmark build (lib/dev/bench_main.dart).
///
/// The app calls [Perf.mark] at a few milestones. Normally nothing listens and
/// a mark costs nothing; the benchmark sets [sink] to record timings.
class Perf {
  static void Function(String name)? sink;

  static void mark(String name) => sink?.call(name);
}
