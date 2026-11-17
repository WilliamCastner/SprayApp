import 'package:flutter/material.dart';
import 'perf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'climb_display.dart';
import 'climb_creation.dart';
import 'data/climb_feed.dart';
import 'widgets/climb_widgets.dart';

class ClimbList extends StatefulWidget {
  const ClimbList({super.key});

  @override
  State<ClimbList> createState() => _ClimbListState();
}

enum _SortOption { newest, oldest, mostSends, hardest, easiest }

const _sortLabels = {
  _SortOption.newest: 'Newest',
  _SortOption.oldest: 'Oldest',
  _SortOption.mostSends: 'Most Sends',
  _SortOption.hardest: 'Hardest',
  _SortOption.easiest: 'Easiest',
};

class _ClimbListState extends State<ClimbList>
    with AutomaticKeepAliveClientMixin {
  String searchQuery = '';
  final _searchController = TextEditingController();
  int minGrade = 0;
  int maxGrade = 16;
  _SortOption _sortOption = _SortOption.mostSends;
  String? _selectedSetter;

  bool _isLoading = true;
  String? _error;

  /// Every climb, from the shared cache. Search, filters and sorting all run
  /// on this list, so they are instant and cover every climb (the old paged
  /// list only searched the first 50).
  List<Map<String, dynamic>> allClimbs = [];

  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchClimbs();
    ClimbFeed.instance.changes.addListener(_onFeedChanged);
  }

  void _onFeedChanged() {
    if (mounted) _fetchClimbs();
  }

  @override
  void dispose() {
    ClimbFeed.instance.changes.removeListener(_onFeedChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Setters with at least one published climb on the selected wall.
  List<String> get _setters {
    final names =
        allClimbs
            .where((c) => !c.isDraft && c.onCurrentWall)
            .map((c) => c['displayname']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<void> _fetchClimbs({bool force = false}) async {
    if (allClimbs.isEmpty) setState(() => _isLoading = true);
    try {
      final rows = await ClimbFeed.instance.climbs(force: force);
      if (!mounted) return;
      setState(() {
        allClimbs = rows;
        _isLoading = false;
        _error = null;
      });
      Perf.mark('climbs-loaded');
    } catch (e) {
      debugPrint('Error fetching climbs: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load climbs. Pull down to try again.';
      });
    }
  }

  bool get _filtersActive =>
      minGrade != 0 ||
      maxGrade != 16 ||
      _selectedSetter != null ||
      _sortOption != _SortOption.mostSends;

  void _resetFilters() {
    setState(() {
      minGrade = 0;
      maxGrade = 16;
      _sortOption = _SortOption.mostSends;
      _selectedSetter = null;
    });
  }

  List<Map<String, dynamic>> get filteredClimbs {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final q = searchQuery.trim().toLowerCase();

    return allClimbs.where((climb) {
      if (!climb.visibleTo(userId)) return false;
      // Only the current wall: climbs from before the reset are hidden.
      if (!climb.onCurrentWall) return false;
      if (_selectedSetter != null && climb['displayname'] != _selectedSetter) {
        return false;
      }

      // Search matches the climb name or the setter.
      final nameMatch =
          q.isEmpty ||
          (climb['name'] ?? '').toString().toLowerCase().contains(q) ||
          (climb['displayname'] ?? '').toString().toLowerCase().contains(q);

      final gradeStr = climb['grade'] ?? '';
      final gradeNum = _extractGradeNumber(gradeStr);

      // '?' grade (gradeNum == null) always passes the grade range filter
      final gradeMatch =
          gradeNum == null || (gradeNum >= minGrade && gradeNum <= maxGrade);

      return nameMatch && gradeMatch;
    }).toList()..sort((a, b) {
      switch (_sortOption) {
        case _SortOption.hardest:
        case _SortOption.easiest:
          final diff = _computeGradeValue(a).compareTo(_computeGradeValue(b));
          return _sortOption == _SortOption.hardest ? -diff : diff;
        case _SortOption.mostSends:
          final bySends = sendCount(b).compareTo(sendCount(a));
          if (bySends != 0) return bySends;
          return (b['createdat'] ?? '').toString().compareTo(
            (a['createdat'] ?? '').toString(),
          );
        case _SortOption.newest:
          return (b['createdat'] ?? '').toString().compareTo(
            (a['createdat'] ?? '').toString(),
          );
        case _SortOption.oldest:
          return (a['createdat'] ?? '').toString().compareTo(
            (b['createdat'] ?? '').toString(),
          );
      }
    });
  }


  bool _sentByMe(Map<String, dynamic> climb) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId != null &&
        climb.ascentList.any((a) => a['user_id'] == userId);
  }

  int _computeGradeValue(Map<String, dynamic> climb) {
    final grades = ((climb['ascents'] as List<dynamic>?) ?? [])
        .map((a) => a['grade_feel'])
        .whereType<num>()
        .map((g) => g.toInt())
        .toList();
    if (grades.isEmpty) return _extractGradeNumber(climb['grade'] ?? '') ?? 0;
    return (grades.reduce((a, b) => a + b) / grades.length).ceil();
  }

  int? _extractGradeNumber(String grade) {
    final match = RegExp(r'V(\d+)').firstMatch(grade.toUpperCase());
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  void _showFilterDialog() {
    RangeValues selectedRange = RangeValues(
      minGrade.toDouble(),
      maxGrade.toDouble(),
    );
    _SortOption tempSort = _sortOption;
    String? tempSetter = _selectedSetter;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter & Sort'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grade Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RangeSlider(
                    min: 0,
                    max: 16,
                    divisions: 16,
                    labels: RangeLabels(
                      'V${selectedRange.start.round()}',
                      'V${selectedRange.end.round()}',
                    ),
                    values: selectedRange,
                    onChanged: (newRange) {
                      setStateDialog(() {
                        selectedRange = newRange;
                      });
                    },
                  ),
                  Text(
                    'From V${selectedRange.start.round()} to V${selectedRange.end.round()}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort By',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<_SortOption>(
                    value: tempSort,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: _SortOption.newest,
                        child: Text('Newest'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.oldest,
                        child: Text('Oldest'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.mostSends,
                        child: Text('Most Sends'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.hardest,
                        child: Text('Hardest'),
                      ),
                      DropdownMenuItem(
                        value: _SortOption.easiest,
                        child: Text('Easiest'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() => tempSort = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Set By',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: tempSetter ?? ''),
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.isEmpty) return _setters;
                      return _setters.where(
                        (name) => name.toLowerCase().contains(
                          value.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (String selection) {
                      setStateDialog(() => tempSetter = selection);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'All Setters',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              if (v.isEmpty) {
                                setStateDialog(() => tempSetter = null);
                              }
                            },
                          );
                        },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _resetFilters();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newMin = selectedRange.start.round();
              final newMax = selectedRange.end.round();
              setState(() {
                minGrade = newMin;
                maxGrade = newMax;
                _sortOption = tempSort;
                _selectedSetter = tempSetter;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }



  Future<void> _openClimb(
    List<Map<String, dynamic>> climbs,
    Map<String, dynamic> climb,
  ) async {
    final ids = climbs.map((c) => c['climbid'].toString()).toList();
    final idx = ids.indexOf(climb['climbid'].toString());
    final savedOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimbDisplay(
          climbId: climb['climbid'],
          climbIds: ids,
          currentIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
    // Uses the cache unless something was changed on the climb page.
    await _fetchClimbs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  Widget _filterChips() {
    final chips = <Widget>[];
    if (minGrade != 0 || maxGrade != 16) {
      chips.add(
        InputChip(
          label: Text(
            minGrade == maxGrade ? 'V$minGrade' : 'V$minGrade–V$maxGrade',
          ),
          onDeleted: () => setState(() {
            minGrade = 0;
            maxGrade = 16;
          }),
        ),
      );
    }
    if (_selectedSetter != null) {
      chips.add(
        InputChip(
          label: Text('Set by $_selectedSetter'),
          onDeleted: () => setState(() => _selectedSetter = null),
        ),
      );
    }
    if (_sortOption != _SortOption.mostSends) {
      chips.add(
        InputChip(
          label: Text('Sort: ${_sortLabels[_sortOption]}'),
          onDeleted: () => setState(() => _sortOption = _SortOption.mostSends),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final c in chips)
            Padding(padding: const EdgeInsets.only(right: 6), child: c),
          TextButton(onPressed: _resetFilters, child: const Text('Clear all')),
        ],
      ),
    );
  }

  Widget _climbCard(
    List<Map<String, dynamic>> climbs,
    Map<String, dynamic> climb,
  ) {
    return ClimbTile(
      grade: displayGrade(climb),
      name: climb['name'] ?? '',
      isPrivate: climb.isPrivate,
      details: [
        (climb['displayname'] ?? '').toString(),
        sendsLabel(sendCount(climb)),
      ],
      trailing: _sentByMe(climb)
          ? const Tooltip(
              message: 'You sent this',
              child: Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: Colors.green, size: 22),
              ),
            )
          : null,
      onTap: () => _openClimb(climbs, climb),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final climbs = filteredClimbs;
    final wallCount = allClimbs
        .where(
          (c) =>
              c.visibleTo(Supabase.instance.client.auth.currentUser?.id) &&
              c.onCurrentWall,
        )
        .length;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (climbs.isEmpty) {
      final String message;
      if (_error != null) {
        message = _error!;
      } else if (wallCount == 0) {
        message = 'No climbs on the new wall yet.\nSet the first one!';
      } else {
        message = 'No climbs match your search.';
      }
      // Scrollable so pull-to-refresh still works on an empty list.
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            _error != null
                ? Icons.cloud_off
                : (wallCount == 0
                      ? Icons.landscape_outlined
                      : Icons.search_off),
            size: 40,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (_filtersActive || searchQuery.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => searchQuery = '');
                  _resetFilters();
                },
                child: const Text('Clear search and filters'),
              ),
            ),
        ],
      );
    } else {
      body = ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88), // room for the button
        itemCount: climbs.length,
        itemBuilder: (context, index) => _climbCard(climbs, climbs[index]),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-climb',
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Climb'),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const ClimbsPage()),
          );
          if (created == true) _fetchClimbs();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search climbs or setters',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                },
                              ),
                      ),
                      onChanged: (value) => setState(() => searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _filtersActive,
                      backgroundColor: Colors.deepOrange,
                      smallSize: 8,
                      child: const Icon(Icons.tune),
                    ),
                    tooltip: 'Filter and sort',
                    onPressed: _showFilterDialog,
                  ),
                ],
              ),
            ),
            if (_filtersActive) _filterChips(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
              child: Row(
                children: [
                  Text(
                    _isLoading || climbs.isEmpty
                        ? ''
                        : '${climbs.length} ${climbs.length == 1 ? 'climb' : 'climbs'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchClimbs(force: true),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
