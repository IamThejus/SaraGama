// ui/player_screen.dart
// UI redesigned to match the reference — dark background, large "MUSIC" header,
// song list with thumbnail + title + artist + duration, mini player bar at bottom.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import './controllers/player_controller.dart';
import './controllers/search_controller.dart';
import './services/search_service.dart';
import 'now_playing_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlayerController _pc = Get.find();
  final SongSearchController _sc = Get.put(SongSearchController());

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  // ── Search helpers ────────────────────────────────────────────────────────

  void _openSearch() {
    setState(() => _searchOpen = true);
    Future.delayed(
        const Duration(milliseconds: 80), () => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    _sc.clear();
    setState(() => _searchOpen = false);
  }

  void _playResult(SearchResult r) {
    _pc.playVideoId(
      r.videoId,
      title: r.title,
      artist: r.artistLine,
      thumbnail: r.thumbnail,
      duration: r.durationValue,
    );
    _closeSearch();
  }

  void _queueResult(SearchResult r) {
    _pc.addToQueue(
      r.videoId,
      title: r.title,
      artist: r.artistLine,
      thumbnail: r.thumbnail,
      duration: r.durationValue,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added: ${r.title}',
          style: GoogleFonts.inter(fontSize: 12)),
      duration: const Duration(seconds: 1),
      backgroundColor: const Color(0xFF1C1C1C),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _searchOpen
                      ? _buildSearchBody()
                      : _buildSongListBody(),
                ),
                // Space for mini player
                const SizedBox(height: 72),
              ],
            ),
            // Mini player pinned to bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMiniPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    if (_searchOpen) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _closeSearch,
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _sc.onQueryChanged,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search songs...',
                  hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade600, fontSize: 16),
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
                          _searchController.clear();
                          _sc.clear();
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Colors.grey, size: 20),
                      )
                    : const SizedBox(width: 20)),
          ],
        ),
      );
    }

    // Normal header — big "MUSIC" title + search icon
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'MUSIC',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openSearch,
            child: Icon(Icons.search_rounded,
                color: Colors.grey.shade500, size: 26),
          ),
        ],
      ),
    );
  }

  // ── Song list ─────────────────────────────────────────────────────────────

  Widget _buildSongListBody() {
    return StreamBuilder<List<MediaItem>>(
      stream: _pc.audioHandler.queue,
      builder: (context, snap) {
        final queue = snap.data ?? [];
        if (queue.isEmpty) return _emptyQueueState();
        return Column(
          children: [
            const Divider(color: Color(0xFF2A2A2A), height: 1, thickness: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: queue.length,
                separatorBuilder: (_, __) =>
                    const Divider(
                        color: Color(0xFF1A1A1A), height: 1, indent: 76),
                itemBuilder: (_, i) {
                  final item = queue[i];
                  final isCurrent = _pc.currentSong.value?.id == item.id;
                  return _buildSongRow(item, i, isCurrent);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyQueueState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music_rounded,
              size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text('No songs yet',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Tap  🔍  to search and add songs',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildSongRow(MediaItem item, int index, bool isCurrent) {
    final artUrl = item.artUri?.toString() ?? '';
    final dur = item.duration;
    final durStr = dur != null ? _fmt(dur) : '';

    return GestureDetector(
      onTap: () => _pc.audioHandler.skipToQueueItem(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: artUrl.isNotEmpty
                  ? Image.network(
                      artUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 14),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Red dot for currently playing
                      if (isCurrent) ...[
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          item.title.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (item.artist ?? '').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duration
            if (durStr.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                durStr,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note_rounded,
            size: 22, color: Colors.grey.shade700),
      );

  // ── Search body ───────────────────────────────────────────────────────────

  Widget _buildSearchBody() {
    return Obx(() {
      final results = _sc.results;
      final loading = _sc.isLoading.value;
      final q = _sc.query.value;

      if (q.isEmpty) {
        return Center(
          child: Text('Type to search songs',
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey.shade600)),
        );
      }
      if (loading && results.isEmpty) {
        return const Center(
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
      }
      if (!loading && results.isEmpty) {
        return Center(
          child: Text('No results for "$q"',
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey.shade600)),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.only(top: 4),
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFF1A1A1A), height: 1, indent: 76),
        itemBuilder: (_, i) => _buildSearchTile(results[i]),
      );
    });
  }

  Widget _buildSearchTile(SearchResult r) {
    return GestureDetector(
      onTap: () => _playResult(r),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: r.thumbnail.isNotEmpty
                  ? Image.network(
                      r.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 14),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.artistLine.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duration
            if (r.duration.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                r.duration,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400),
              ),
            ],
            const SizedBox(width: 8),

            // Add to queue
            GestureDetector(
              onTap: () => _queueResult(r),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.add_rounded,
                    color: Colors.grey.shade600, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mini player bar ───────────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    return Obx(() {
      final song = _pc.currentSong.value;
      final state = _pc.buttonState.value;
      final progress = _pc.progressBarState.value;

      final total = progress.total.inMilliseconds.toDouble();
      final current = progress.current.inMilliseconds.toDouble();
      final fraction = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin red progress line (like reference)
          Container(
            height: 2,
            width: double.infinity,
            color: const Color(0xFF1A1A1A),
            child: FractionallySizedBox(
              widthFactor: fraction,
              alignment: Alignment.centerLeft,
              child: Container(color: const Color(0xFFFF3B30)),
            ),
          ),
          // Mini player body
          GestureDetector(
            onTap: () => Navigator.of(context).push(_slideUpRoute()),
            child: Container(
            color: Colors.black,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Red dot indicator
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),

                // Title + artist
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
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song?.artist != null && song!.artist!.isNotEmpty)
                        Text(
                          song.artist!.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Prev
                _miniCtrl(
                  icon: Icons.skip_previous_rounded,
                  onTap: _pc.prev,
                ),

                // Play / Pause / Loading
                _miniPlayBtn(state),

                // Next
                _miniCtrl(
                  icon: Icons.skip_next_rounded,
                  onTap: _pc.next,
                ),
              ],
            ),
          ),
          ), // GestureDetector
        ],
      );
    });
  }

  // Slide-up page transition for Now Playing screen
  PageRouteBuilder _slideUpRoute() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final tween =
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      );

  Widget _miniCtrl({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );

  Widget _miniPlayBtn(PlayButtonState state) {
    if (state == PlayButtonState.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        ),
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

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}