// ui/player_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import './controllers/home_controller.dart';
import './controllers/player_controller.dart';
import './controllers/search_controller.dart';
import './services/home_service.dart';
import './services/search_service.dart';
import 'now_playing_screen.dart';
import 'playlist_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final PlayerController _pc = Get.find();
  final SongSearchController _sc = Get.put(SongSearchController());
  final HomeController _hc = Get.put(HomeController());

  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── search ────────────────────────────────────────────────────────────────

  void _openSearch() {
    setState(() => _searchOpen = true);
    Future.delayed(
        const Duration(milliseconds: 80), () => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    _sc.clear();
    setState(() => _searchOpen = false);
  }

  void _play(SearchResult r) {
    _pc.playVideoId(r.videoId,
        title: r.title,
        artist: r.artistLine,
        thumbnail: r.thumbnail,
        duration: r.durationValue);
    _closeSearch();
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
            content:
                Text(msg, style: GoogleFonts.inter(fontSize: 12)),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF1C1C1C)),
      );

  // ── root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                if (!_searchOpen) _tabBar(),
                Expanded(
                  child: _searchOpen
                      ? _searchBody()
                      : TabBarView(
                          controller: _tabs,
                          children: [_homeTab(), _queueTab()],
                        ),
                ),
                const SizedBox(height: 72),
              ],
            ),
            Positioned(
                left: 0, right: 0, bottom: 0, child: _miniPlayer()),
          ],
        ),
      ),
    );
  }

  // ── top bar ───────────────────────────────────────────────────────────────

  Widget _topBar() {
    if (_searchOpen) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(4, 10, 16, 8),
        child: Row(children: [
          IconButton(
              onPressed: _closeSearch,
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22)),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _sc.onQueryChanged,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade600, fontSize: 15),
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
                      strokeWidth: 2, color: Colors.white))
              : _sc.query.value.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _sc.clear();
                      },
                      child: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 20))
                  : const SizedBox(width: 20)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
      child: Row(children: [
        Text('MUSIC',
            style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5)),
        const Spacer(),
        GestureDetector(
            onTap: _openSearch,
            child: Icon(Icons.search_rounded,
                color: Colors.grey.shade500, size: 26)),
      ]),
    );
  }

  Widget _tabBar() => Container(
        color: Colors.black,
        child: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFF3B30),
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8),
          unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.8),
          tabs: const [Tab(text: 'HOME'), Tab(text: 'QUEUE')],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // HOME TAB
  // ─────────────────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            // ── Daily trending ──────────────────────────────────────────
            _sectionLabel('DAILY TRENDING'),
            _playlistRow(data.daily),

            // ── Weekly charts ───────────────────────────────────────────
            _sectionLabel('WEEKLY CHARTS'),
            _playlistRow(data.weekly),

            // ── Top artists ─────────────────────────────────────────────
            _sectionLabel('TOP ARTISTS'),
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
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _hc.fetchHome,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  // ── Horizontal playlist cards ─────────────────────────────────────────────

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

  Widget _playlistCard(TrendingPlaylist p) {
    return GestureDetector(
      onTap: () => _playlistSheet(p),
      child: SizedBox(
        width: 132,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: p.thumbnailUrl.isNotEmpty
                ? Image.network(
                    p.thumbnailUrl,
                    width: 132,
                    height: 132,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _playlistPlaceholder(132),
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
  }

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

  void _playlistSheet(TrendingPlaylist p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaylistScreen(
        playlistId: p.playlistId,
        playlistTitle: p.title,
        thumbnailUrl: p.thumbnailUrl,
      ),
    ));
  }

  // ── Artist tile ───────────────────────────────────────────────────────────

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
      trendWidget = Icon(Icons.remove_rounded,
          color: Colors.grey.shade700, size: 14);
    }

    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade900, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // rank
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
        // avatar
        ClipOval(
          child: a.thumbnailUrl.isNotEmpty
              ? Image.network(a.thumbnailUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _artistPlaceholder())
              : _artistPlaceholder(),
        ),
        const SizedBox(width: 12),
        // name + subscribers
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
        child: Icon(Icons.person_rounded,
            size: 24, color: Colors.grey.shade700),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // QUEUE TAB
  // ─────────────────────────────────────────────────────────────────────────

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
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade700)),
            ]),
          );
        }
        return ReorderableListView.builder(
          padding: EdgeInsets.zero,
          itemCount: queue.length,
          onReorder: (o, n) => _pc.audioHandler
              .customAction('reorderQueue', {'oldIndex': o, 'newIndex': n}),
          itemBuilder: (_, i) {
            final item = queue[i];
            final cur = _pc.currentSong.value?.id == item.id;
            return _queueRow(item, i, cur, key: ValueKey('${item.id}$i'));
          },
        );
      },
    );
  }

  Widget _queueRow(MediaItem item, int index, bool cur,
      {required Key key}) {
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: art.isNotEmpty
                ? Image.network(art,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _queueThumb())
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
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle),
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
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _pc.audioHandler.removeQueueItem(item),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                  color: Colors.grey.shade700, size: 17),
            ),
          ),
          Icon(Icons.drag_handle_rounded,
              color: Colors.grey.shade800, size: 18),
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

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH BODY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _searchBody() => Obx(() {
        final results = _sc.results;
        final loading = _sc.isLoading.value;
        final q = _sc.query.value;
        if (q.isEmpty) {
          return Center(
              child: Text('Type to search songs',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey.shade600)));
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
          separatorBuilder: (_, __) => Divider(
              color: Colors.grey.shade900, height: 1, indent: 76),
          itemBuilder: (_, i) => _searchTile(results[i]),
        );
      });

  Widget _searchTile(SearchResult r) => GestureDetector(
        onTap: () => _play(r),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: r.thumbnail.isNotEmpty
                  ? Image.network(r.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _queueThumb())
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
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade500)),
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

  // ─────────────────────────────────────────────────────────────────────────
  // MINI PLAYER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _miniPlayer() => Obx(() {
        final song = _pc.currentSong.value;
        final state = _pc.buttonState.value;
        final prog = _pc.progressBarState.value;
        final total = prog.total.inMilliseconds.toDouble();
        final cur = prog.current.inMilliseconds.toDouble();
        final frac = total > 0 ? (cur / total).clamp(0.0, 1.0) : 0.0;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          // red progress line
          Container(
            height: 2,
            color: const Color(0xFF1A1A1A),
            child: FractionallySizedBox(
              widthFactor: frac,
              alignment: Alignment.centerLeft,
              child: Container(color: const Color(0xFFFF3B30)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(_slideUp()),
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song != null
                            ? song.title.toUpperCase()
                            : 'NOTHING PLAYING',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song?.artist != null &&
                          song!.artist!.isNotEmpty)
                        Text(song.artist!.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _miniBtn(Icons.skip_previous_rounded, _pc.prev),
                _miniPlayPause(state),
                _miniBtn(Icons.skip_next_rounded, _pc.next),
              ]),
            ),
          ),
        ]);
      });

  Widget _miniBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );

  Widget _miniPlayPause(PlayButtonState state) {
    if (state == PlayButtonState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () =>
          state == PlayButtonState.playing ? _pc.pause() : _pc.play(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Icon(
          state == PlayButtonState.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // ── utilities ─────────────────────────────────────────────────────────────

  PageRouteBuilder _slideUp() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final tween =
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: anim.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}