// ui/player_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/home_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/search_controller.dart';
import '../services/home_service.dart';
import '../services/library_service.dart';
import '../services/search_service.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'playlist_screen.dart';
import 'widgets/mini_player_bar.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlayerController _pc = Get.find();
  final SongSearchController _sc = Get.put(SongSearchController());
  final HomeController _hc = Get.put(HomeController());

  int _currentIndex = 0;
  late final PageController _pages;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search helpers ────────────────────────────────────────────────────────

  void _play(SearchResult r) {
    // Save to search history
    _pc.addToSearchHistory(LibraryTrack(
      videoId: r.videoId,
      title: r.title,
      artist: r.artistLine,
      thumbnail: r.thumbnail,
      duration: r.duration,
    ));
    _pc.playWithRecommendations(r.videoId,
        title: r.title,
        artist: r.artistLine,
        thumbnail: r.thumbnail,
        duration: r.durationValue);
  }

  void _playFromHistory(LibraryTrack t) {
    _pc.playWithRecommendations(t.videoId,
        title: t.title,
        artist: t.artist,
        thumbnail: t.thumbnail,
        duration: t.durationValue);
  }

  void _queue(SearchResult r) {
    _pc.addToQueue(r.videoId,
        title: r.title,
        artist: r.artistLine,
        thumbnail: r.thumbnail,
        duration: r.durationValue);
    _snack('Added: ${r.title}');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF1C1C1C)),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    children: [
                      _homeTab(),
                      _searchTab(),
                      const LibraryScreen(),
                      _queueTab(),
                    ],
                  ),
                ),
                const SizedBox(height: 72),
              ],
            ),
            const MiniPlayerBar(showBottomNavGap: true),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────────────────

  Widget _bottomNav() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Color(0xFF1C1C1C), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(icon: Icons.home_rounded, label: 'Home', index: 0),
          _navItem(icon: Icons.search_rounded, label: 'Search', index: 1),
          _navItem(icon: Icons.library_music_rounded, label: 'Library', index: 2),
          _navItem(icon: Icons.queue_music_rounded, label: 'Queue', index: 3),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _currentIndex == index;
    final color = selected ? const Color(0xFFFF3B30) : Colors.grey.shade500;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HOME TAB ──────────────────────────────────────────────────────────────

  Widget _homeTab() {
    return Obx(() {
      if (_hc.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFFFF3B30), strokeWidth: 2));
      }
      if (_hc.hasError.value || _hc.homeData.value == null) {
        return _errorState();
      }
      final data = _hc.homeData.value!;
      return RefreshIndicator(
        color: const Color(0xFFFF3B30),
        backgroundColor: const Color(0xFF1C1C1C),
        onRefresh: _hc.fetchHome,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Row(
                children: [
                  Text(
                    'Music',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            _sectionLabel('DAILY TRENDING'),
            _playlistRow(data.daily),
            _sectionLabel('WEEKLY CHARTS'),
            _playlistRow(data.weekly),
            _sectionLabel('TRENDING ARTISTS'),
            ...data.artists.map(_artistTile),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  Widget _errorState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          Text('Could not load charts',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _hc.fetchHome,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('RETRY',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 2.5)),
      );

  Widget _playlistRow(List<TrendingPlaylist> list) => SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _playlistCard(list[i]),
        ),
      );

  Widget _playlistCard(TrendingPlaylist p) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            playlistId: p.playlistId,
            playlistTitle: p.title,
            thumbnailUrl: p.thumbnailUrl,
          ),
        )),
        child: SizedBox(
          width: 132,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: p.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.thumbnailUrl,
                      width: 132,
                      height: 132,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _playlistPlaceholder(132),
                    )
                  : _playlistPlaceholder(132),
            ),
            const SizedBox(height: 6),
            Text(p.title,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade300),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  Widget _playlistPlaceholder(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.library_music_rounded,
            size: size * 0.32, color: Colors.grey.shade800),
      );

  Widget _artistTile(TrendingArtist a) {
    Widget trendWidget;
    if (a.trend == 'up') {
      trendWidget = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.arrow_drop_up_rounded,
            color: Color(0xFF34C759), size: 20),
        Text('UP',
            style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFF34C759),
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]);
    } else if (a.trend == 'down') {
      trendWidget = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.arrow_drop_down_rounded,
            color: Color(0xFFFF3B30), size: 20),
        Text('DN',
            style: GoogleFonts.inter(
                fontSize: 9,
                color: const Color(0xFFFF3B30),
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]);
    } else {
      trendWidget =
          Icon(Icons.remove_rounded, color: Colors.grey.shade700, size: 14);
    }

    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade900, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text(a.rank,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        ClipOval(
          child: a.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: a.thumbnailUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _artistPlaceholder())
              : _artistPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${a.subscribers} subscribers',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: Colors.grey.shade600)),
              ]),
        ),
        const SizedBox(width: 8),
        trendWidget,
      ]),
    );
  }

  Widget _artistPlaceholder() => Container(
        width: 46,
        height: 46,
        color: const Color(0xFF1C1C1C),
        child: Icon(Icons.person_rounded, size: 24, color: Colors.grey.shade700),
      );

  // ── QUEUE TAB ─────────────────────────────────────────────────────────────

  Widget _queueTab() {
    return StreamBuilder<List<MediaItem>>(
      stream: _pc.audioHandler.queue,
      builder: (context, snap) {
        final queue = snap.data ?? [];
        if (queue.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.queue_music_rounded,
                  size: 60, color: Colors.grey.shade800),
              const SizedBox(height: 14),
              Text('Queue is empty',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text('Search  🔍  and add songs',
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          );
        }
        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'UP NEXT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _pc.audioHandler.customAction('clearQueue'),
                    child: Text(
                      'CLEAR QUEUE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF3B30),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1C1C1C)),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.zero,
                itemCount: queue.length,
                onReorder: (o, n) => _pc.audioHandler.customAction(
                    'reorderQueue', {'oldIndex': o, 'newIndex': n}),
                itemBuilder: (_, i) {
                  final item = queue[i];
                  final cur = _pc.currentSong.value?.id == item.id;
                  return _queueRow(item, i, cur,
                      key: ValueKey('${item.id}$i'));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _queueRow(MediaItem item, int index, bool cur, {required Key key}) {
    final art = item.artUri?.toString() ?? '';
    final dur = item.duration;
    final ds = dur != null ? _fmt(dur) : '';
    return GestureDetector(
      key: key,
      onTap: () => _pc.audioHandler.skipToQueueItem(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: cur
            ? const Color(0xFFFF3B30).withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: art.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: art,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _queueThumb())
                : _queueThumb(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (cur)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30), shape: BoxShape.circle),
                      ),
                    Expanded(
                      child: Text(item.title.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text((item.artist ?? '').toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          if (ds.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(ds,
                style:
                    GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _pc.audioHandler.removeQueueItem(item),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child:
                  Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 17),
            ),
          ),
          Icon(Icons.drag_handle_rounded, color: Colors.grey.shade800, size: 18),
        ]),
      ),
    );
  }

  Widget _queueThumb() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note_rounded,
            size: 20, color: Colors.grey.shade700),
      );

  // ── SEARCH TAB ────────────────────────────────────────────────────────────

  Widget _searchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                'Search',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Icon(Icons.mic_none_rounded,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _sc.onQueryChanged,
                    style:
                        GoogleFonts.inter(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Artists, songs, or podcasts',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade600, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Obx(() => _sc.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : _sc.query.value.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _sc.clear();
                            },
                            child: const Icon(Icons.close_rounded,
                                color: Colors.grey, size: 18),
                          )
                        : const SizedBox(width: 18)),
              ],
            ),
          ),
        ),
        Expanded(child: _searchBody()),
      ],
    );
  }

  Widget _searchBody() => Obx(() {
        final results = _sc.results;
        final loading = _sc.isLoading.value;
        final q = _sc.query.value;

        // Empty query — show search history
        if (q.isEmpty) {
          final history = _pc.searchHistory;
          if (history.isEmpty) {
            return Center(
                child: Text('Type to search songs',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey.shade600)));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  Text('RECENT',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                          letterSpacing: 2.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pc.clearSearchHistory,
                    child: Text('CLEAR',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFFFF3B30),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: history.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade900, height: 1, indent: 76),
                  itemBuilder: (_, i) => _historyTile(history[i]),
                ),
              ),
            ],
          );
        }

        if (loading && results.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF3B30), strokeWidth: 2));
        }
        if (!loading && results.isEmpty) {
          return Center(
              child: Text('No results for "$q"',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey.shade600)));
        }
        return ListView.separated(
          padding: const EdgeInsets.only(top: 4),
          itemCount: results.length,
          separatorBuilder: (_, __) =>
              Divider(color: Colors.grey.shade900, height: 1, indent: 76),
          itemBuilder: (_, i) => _searchTile(results[i]),
        );
      });

  Widget _historyTile(LibraryTrack t) => GestureDetector(
        onTap: () => _playFromHistory(t),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: t.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: t.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _queueThumb())
                  : _queueThumb(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(t.artist.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            Icon(Icons.history_rounded, color: Colors.grey.shade700, size: 18),
          ]),
        ),
      );

  Widget _searchTile(SearchResult r) => GestureDetector(
        onTap: () => _play(r),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: r.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: r.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _queueThumb())
                  : _queueThumb(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(r.artistLine.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            if (r.duration.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(r.duration,
                  style:
                      GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _queue(r),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.add_rounded,
                    color: Colors.grey.shade600, size: 20),
              ),
            ),
          ]),
        ),
      );

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}