// ui/player_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/home_controller.dart';
import '../controllers/player_controller.dart';
import '../controllers/search_controller.dart';
import '../services/home_service.dart';
import '../services/library_service.dart';
import '../services/search_service.dart';
import 'app_theme.dart';
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
  int _previousIndex = 0;
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  final RxString _homeFilter = 'ALL'.obs;

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex  = index;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search helpers ────────────────────────────────────────────────────────

  void _play(SearchResult r) {
    _pc.addToSearchHistory(LibraryTrack(
      videoId:   r.videoId,
      title:     r.title,
      artist:    r.artistLine,
      thumbnail: r.thumbnail,
      duration:  r.duration,
    ));
    _pc.playWithRecommendations(r.videoId,
        title:     r.title,
        artist:    r.artistLine,
        thumbnail: r.thumbnail,
        duration:  r.durationValue);
  }

  void _playFromHistory(LibraryTrack t) {
    _pc.playWithRecommendations(t.videoId,
        title:     t.title,
        artist:    t.artist,
        thumbnail: t.thumbnail,
        duration:  t.durationValue);
  }

  void _queue(SearchResult r) {
    _pc.addToQueue(r.videoId,
        title:     r.title,
        artist:    r.artistLine,
        thumbnail: r.thumbnail,
        duration:  r.durationValue);
    _snack('Added: ${r.title}');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: AppText.subtitle()),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.elevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _homeTab(),
      _searchTab(),
      const LibraryScreen(),
      _queueTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _TabSwitcher(
                    currentIndex: _currentIndex,
                    previousIndex: _previousIndex,
                    tabs: tabs,
                  ),
                ),
                const SizedBox(height: 72),
              ],
            ),
            const MiniPlayerBar(showBottomNavGap: true),
            Positioned(
              left: 0, right: 0, bottom: 0,
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
        border: Border(top: BorderSide(color: Color(0xFF1C1C1C), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(icon: Icons.home_rounded,          label: 'Home',    index: 0),
          _navItem(icon: Icons.search_rounded,         label: 'Search',  index: 1),
          _navItem(icon: Icons.library_music_rounded,  label: 'Library', index: 2),
          _navItem(icon: Icons.queue_music_rounded,    label: 'Queue',   index: 3),
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
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: selected ? 1.22 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color),
            child: Text(label),
          ),
        ]),
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

      final data   = _hc.homeData.value!;
      final filter = _homeFilter.value;

      final List<TrendingPlaylist> displayList = filter == 'DAILY'
          ? data.daily
          : filter == 'WEEKLY'
              ? data.weekly
              : [...data.daily, ...data.weekly];

      return RefreshIndicator(
        color: const Color(0xFFFF3B30),
        backgroundColor: const Color(0xFF1C1C1C),
        onRefresh: _hc.fetchHome,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF3B30),
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SARAGAMA',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(() => _hc.isRefreshing.value
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Color(0xFFFF3B30)))
                      : const SizedBox.shrink()),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showSettingsSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Filter chips ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Obx(() => Row(
                    children: ['ALL', 'DAILY', 'WEEKLY'].map((f) {
                      final active = _homeFilter.value == f;
                      return GestureDetector(
                        onTap: () => _homeFilter.value = f,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFFFF3B30)
                                  : const Color(0xFF2A2A2A),
                            ),
                          ),
                          child: Text(
                            f,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
            ),

            const SizedBox(height: 28),

            // ── Section title ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  filter == 'ALL'
                      ? 'TRENDING NOW'
                      : filter == 'DAILY'
                          ? 'DAILY TRENDING'
                          : 'WEEKLY CHARTS',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${displayList.length} playlists',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),

            // ── 2-column grid ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _playlistGrid(displayList),
            ),
          ],
        ),
      );
    });
  }

  Widget _playlistGrid(List<TrendingPlaylist> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No playlists available',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey.shade700)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _playlistGridCard(list[i], i),
    );
  }

  Widget _playlistGridCard(TrendingPlaylist p, int index) {
    final isFirst = index == 0;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          playlistId:    p.playlistId,
          playlistTitle: p.title,
          thumbnailUrl:  p.thumbnailUrl,
        ),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFirst
                ? const Color(0xFFFF3B30).withOpacity(0.4)
                : const Color(0xFF1F1F1F),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    p.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: p.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _gridThumbPlaceholder(),
                          )
                        : _gridThumbPlaceholder(),
                    if (isFirst)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF3B30).withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isFirst
                              ? const Color(0xFFFF3B30)
                              : Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                p.title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isFirst ? Colors.white : Colors.grey.shade300,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridThumbPlaceholder() => Container(
        color: AppColors.elevated,
        child: Icon(Icons.library_music_rounded,
            size: 40, color: AppColors.textMuted),
      );

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
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('Settings',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade900),
          // Streaming quality
          Obx(() {
            final hq = _pc.isHighQuality.value;
            return ListTile(
              leading: Icon(
                  hq ? Icons.high_quality_rounded : Icons.sd_rounded,
                  color: const Color(0xFFFF3B30), size: 22),
              title: Text('Streaming Quality',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
              subtitle: Text(hq ? 'High Quality' : 'Data Saver',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade600)),
              trailing: Switch(
                value: hq,
                onChanged: (_) => _pc.toggleQuality(),
                activeColor: const Color(0xFFFF3B30),
              ),
              dense: true,
            );
          }),
          // Clear search history
          ListTile(
            leading: Icon(Icons.history_rounded,
                color: Colors.grey.shade400, size: 22),
            title: Text('Clear Search History',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              _pc.clearSearchHistory();
              Navigator.pop(context);
              _snack('Search history cleared');
            },
            dense: true,
          ),
          // Clear queue
          ListTile(
            leading: Icon(Icons.queue_music_rounded,
                color: Colors.grey.shade400, size: 22),
            title: Text('Clear Queue',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              _pc.clearQueue();
              Navigator.pop(context);
              _snack('Queue cleared');
            },
            dense: true,
          ),
        ]),
      ),
    );
  }

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
              Text('Search and add songs',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _switchTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('GO TO SEARCH',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          );
        }
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Text('UP NEXT',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 2.5)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _pc.clearQueue();
                  _snack('Queue cleared');
                },
                child: Text('CLEAR',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF3B30),
                        letterSpacing: 1.5)),
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFF1C1C1C)),
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.zero,
              itemCount: queue.length,
              onReorder: (o, n) => _pc.audioHandler
                  .customAction('reorderQueue', {'oldIndex': o, 'newIndex': n}),
              itemBuilder: (_, i) {
                final item = queue[i];
                final cur  = _pc.currentSong.value?.id == item.id;
                return _queueRow(item, i, cur, key: ValueKey('${item.id}$i'));
              },
            ),
          ),
        ]);
      },
    );
  }

  Widget _queueRow(MediaItem item, int index, bool cur, {required Key key}) {
    final art = item.artUri?.toString() ?? '';
    final dur = item.duration;
    final ds  = dur != null ? _fmt(dur) : '';
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
                    width: 46, height: 46, fit: BoxFit.cover,
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
                        width: 7, height: 7,
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

  Widget _queueThumb() => const ThumbPlaceholder(size: 46, radius: 6);

  // ── SEARCH TAB ────────────────────────────────────────────────────────────

  Widget _searchTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          Text('Search',
              style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2)),
          const Spacer(),
          Icon(Icons.mic_none_rounded, color: Colors.grey.shade400, size: 22),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _sc.onQueryChanged,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
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
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : _sc.query.value.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _sc.clear();
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Colors.grey, size: 18))
                    : const SizedBox(width: 18)),
          ]),
        ),
      ),
      Expanded(child: _searchBody()),
    ]);
  }

  Widget _searchBody() => Obx(() {
        final results = _sc.results;
        final loading = _sc.isLoading.value;
        final q       = _sc.query.value;

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
                  separatorBuilder: (_, __) => Divider(
                      color: Colors.grey.shade900, height: 1, indent: 76),
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
                      width: 48, height: 48, fit: BoxFit.cover,
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
            Icon(Icons.history_rounded,
                color: Colors.grey.shade700, size: 18),
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
                      width: 48, height: 48, fit: BoxFit.cover,
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

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Tab switcher: fade + slide up ─────────────────────────────────────────

class _TabSwitcher extends StatefulWidget {
  final int currentIndex;
  final int previousIndex;
  final List<Widget> tabs;

  const _TabSwitcher({
    required this.currentIndex,
    required this.previousIndex,
    required this.tabs,
  });

  @override
  State<_TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<_TabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _visibleIndex = widget.currentIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _buildAnimations();
    // Start fully visible — no animation on initial load
    _ctrl.value = 1.0;
  }

  void _buildAnimations() {
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_TabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _visibleIndex = widget.currentIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.tabs.length, (i) {
        final isActive = i == _visibleIndex;
        if (!isActive) {
          return Offstage(offstage: true, child: widget.tabs[i]);
        }
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: widget.tabs[i],
          ),
        );
      }),
    );
  }
}