// ui/player_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import './controllers/player_controller.dart';
import './controllers/search_controller.dart';
import './services/search_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final PlayerController _pc = Get.find();
  final SongSearchController _sc = Get.put(SongSearchController());

  // Search bar controller
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  // Manual ID input
  final _idController = TextEditingController();
  final _titleController = TextEditingController();

  // ── Search helpers ───────────────────────────────────────────────────────

  void _openSearch() {
    setState(() => _searchOpen = true);
    Future.delayed(const Duration(milliseconds: 80),
        () => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    _sc.clear();
    setState(() => _searchOpen = false);
  }

  void _onSearchChanged(String v) => _sc.onQueryChanged(v);

  void _playResult(SearchResult result) {
    _pc.playVideoId(result.videoId, title: result.title, artist: result.artistLine, thumbnail: result.thumbnail);
    _closeSearch();
  }

  void _queueResult(SearchResult result) {
    _pc.addToQueue(result.videoId, title: result.title, artist: result.artistLine, thumbnail: result.thumbnail);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added: ${result.title}',
            style: GoogleFonts.spaceMono(fontSize: 11)),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
  }

  // ── Manual ID load ────────────────────────────────────────────────────────

  void _onLoad() {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    _pc.playVideoId(id,
        title: _titleController.text.trim().isEmpty
            ? id
            : _titleController.text.trim());
    _idController.clear();
    _titleController.clear();
    FocusScope.of(context).unfocus();
  }

  void _onAddToQueue() {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    _pc.addToQueue(id,
        title: _titleController.text.trim().isEmpty
            ? id
            : _titleController.text.trim());
    _idController.clear();
    _titleController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Added to queue'),
          duration: Duration(seconds: 1)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Search results overlay OR normal content
            Expanded(
              child: _searchOpen ? _buildSearchOverlay() : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _searchOpen ? _buildSearchBar() : _buildNormalHeader(),
    );
  }

  Widget _buildNormalHeader() {
    return Container(
      key: const ValueKey('normal-header'),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded,
              color: Color(0xFFFF0000), size: 24),
          const SizedBox(width: 10),
          Text('YT Audio Player',
              style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.5)),
          const Spacer(),
          // Search icon
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded,
                color: Colors.grey, size: 22),
            tooltip: 'Search',
          ),
          // Quality toggle
          Obx(() => GestureDetector(
                onTap: _pc.toggleQuality,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3A3A3A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hd_rounded,
                          size: 15,
                          color: _pc.isHighQuality.value
                              ? const Color(0xFFFF0000)
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _pc.isHighQuality.value ? 'HQ' : 'LQ',
                        style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: _pc.isHighQuality.value
                                ? const Color(0xFFFF0000)
                                : Colors.grey),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search-header'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _closeSearch,
            icon:
                const Icon(Icons.arrow_back_rounded, color: Colors.grey, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: GoogleFonts.spaceMono(
                    color: Colors.grey.shade700, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Obx(() => _sc.isLoading.value
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF0000)),
                )
              : _sc.query.value.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _sc.clear();
                      },
                      child: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 18),
                    )
                  : const SizedBox(width: 18)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Search overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchOverlay() {
    return Obx(() {
      final results = _sc.results;
      final loading = _sc.isLoading.value;
      final q = _sc.query.value;

      if (q.isEmpty) {
        return _searchEmptyState();
      }
      if (loading && results.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0000)),
        );
      }
      if (!loading && results.isEmpty) {
        return _noResultsState(q);
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFF1F1F1F), height: 1),
        itemBuilder: (_, i) => _buildResultTile(results[i]),
      );
    });
  }

  Widget _searchEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 56, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          Text('Type to search songs',
              style: GoogleFonts.spaceMono(
                  fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _noResultsState(String q) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 56, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          Text('No results for "$q"',
              style: GoogleFonts.spaceMono(
                  fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildResultTile(SearchResult result) {
    return InkWell(
      onTap: () => _playResult(result),
      splashColor: const Color(0xFFFF0000).withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                result.thumbnail,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.grey, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + artists
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: GoogleFonts.rajdhani(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.artistLine,
                    style: GoogleFonts.spaceMono(
                        fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Add to queue button
            GestureDetector(
              onTap: () => _queueResult(result),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.grey, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            // Play button
            GestureDetector(
              onTap: () => _playResult(result),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFFF0000), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main content (player + manual input + queue)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildInputCard(),
          const SizedBox(height: 16),
          _buildPlayerCard(),
          const SizedBox(height: 16),
          _buildQueueSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Input card (manual ID)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MANUAL ID',
              style: GoogleFonts.spaceMono(
                  fontSize: 10, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13),
            decoration: _inputDeco(
                'YouTube Video ID  e.g. dQw4w9WgXcQ', Icons.link_rounded),
            onSubmitted: (_) => _onLoad(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13),
            decoration:
                _inputDeco('Song title (optional)', Icons.title_rounded),
            onSubmitted: (_) => _onLoad(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _onLoad,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('PLAY NOW',
                      style: GoogleFonts.spaceMono(
                          fontSize: 11, letterSpacing: 1)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onAddToQueue,
                  icon: const Icon(Icons.queue_music_rounded, size: 18),
                  label: Text('+ QUEUE',
                      style: GoogleFonts.spaceMono(
                          fontSize: 11, letterSpacing: 1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3A3A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.spaceMono(color: Colors.grey.shade700, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 18),
        filled: true,
        fillColor: const Color(0xFF0F0F0F),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF0000)),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Player card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPlayerCard() {
    return Obx(() {
      final song = _pc.currentSong.value;
      final error = _pc.errorMessage.value;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            _buildArtwork(song),
            const SizedBox(height: 16),
            if (error != null) _buildError(error),
            Text(
              song?.title ?? 'No song loaded',
              style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              song?.artist ?? '--',
              style: GoogleFonts.spaceMono(
                  fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildProgressBar(),
            const SizedBox(height: 20),
            _buildControls(),
          ],
        ),
      );
    });
  }

  Widget _buildArtwork(MediaItem? song) {
    final artUrl = song?.artUri?.toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 175,
        color: const Color(0xFF0F0F0F),
        child: artUrl != null && artUrl.isNotEmpty
            ? Image.network(artUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder())
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() => Center(
        child: Icon(Icons.music_note_rounded,
            size: 64, color: Colors.grey.shade800),
      );

  Widget _buildError(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style:
                      GoogleFonts.spaceMono(fontSize: 11, color: Colors.red)),
            ),
          ],
        ),
      );

  Widget _buildProgressBar() {
    return Obx(() {
      final state = _pc.progressBarState.value;
      final total = state.total.inSeconds.toDouble();
      final current = state.current.inSeconds.toDouble();
      final buffered = state.buffered.inSeconds.toDouble();

      return Column(
        children: [
          Stack(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.grey.shade700,
                  inactiveTrackColor: Colors.grey.shade800,
                ),
                child: Slider(
                  value: total > 0 ? buffered.clamp(0, total) : 0,
                  min: 0,
                  max: total > 0 ? total : 1,
                  onChanged: null,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: const Color(0xFFFF0000),
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                ),
                child: Slider(
                  value: total > 0 ? current.clamp(0, total) : 0,
                  min: 0,
                  max: total > 0 ? total : 1,
                  onChanged: (v) =>
                      _pc.seek(Duration(seconds: v.toInt())),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(state.current),
                    style: GoogleFonts.spaceMono(
                        fontSize: 10, color: Colors.grey.shade600)),
                Text(_fmt(state.total),
                    style: GoogleFonts.spaceMono(
                        fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildControls() {
    return Obx(() {
      final state = _pc.buttonState.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ctrlBtn(
              icon: Icons.shuffle_rounded,
              onTap: _pc.toggleShuffle,
              active: _pc.isShuffleEnabled.value,
              size: 22),
          const SizedBox(width: 8),
          _ctrlBtn(
              icon: Icons.skip_previous_rounded, onTap: _pc.prev, size: 30),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (state == PlayButtonState.playing) {
                _pc.pause();
              } else if (state == PlayButtonState.paused) {
                _pc.play();
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: state == PlayButtonState.loading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      state == PlayButtonState.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          _ctrlBtn(icon: Icons.skip_next_rounded, onTap: _pc.next, size: 30),
          const SizedBox(width: 8),
          _ctrlBtn(
              icon: Icons.repeat_one_rounded,
              onTap: _pc.toggleLoop,
              active: _pc.isLoopEnabled.value,
              size: 22),
        ],
      );
    });
  }

  Widget _ctrlBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    double size = 24,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon,
              size: size,
              color:
                  active ? const Color(0xFFFF0000) : Colors.grey.shade500),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Queue
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQueueSection() {
    return StreamBuilder<List<MediaItem>>(
      stream: _pc.audioHandler.queue,
      builder: (context, snap) {
        final queue = snap.data ?? [];
        if (queue.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.queue_music_rounded,
                        color: Color(0xFFFF0000), size: 18),
                    const SizedBox(width: 8),
                    Text('QUEUE',
                        style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            color: Colors.grey,
                            letterSpacing: 2)),
                    const Spacer(),
                    Text('${queue.length} songs',
                        style: GoogleFonts.spaceMono(
                            fontSize: 10, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: queue.length,
                onReorder: (oldIndex, newIndex) {
                  _pc.audioHandler.customAction('reorderQueue', {
                    'oldIndex': oldIndex,
                    'newIndex': newIndex,
                  });
                },
                itemBuilder: (_, index) {
                  final item = queue[index];
                  final isCurrent = _pc.currentSong.value?.id == item.id;
                  return _buildQueueItem(item, index, isCurrent,
                      key: ValueKey('${item.id}$index'));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueItem(MediaItem item, int index, bool isCurrent,
      {required Key key}) {
    final artUrl = item.artUri?.toString() ?? '';
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFF0000).withOpacity(0.08)
            : Colors.transparent,
        border:
            const Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: isCurrent
                ? const Icon(Icons.equalizer_rounded,
                    color: Color(0xFFFF0000), size: 16)
                : Text('${index + 1}',
                    style: GoogleFonts.spaceMono(
                        fontSize: 11, color: Colors.grey.shade700)),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: artUrl.isNotEmpty
                ? Image.network(artUrl,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _queueThumbPlaceholder())
                : _queueThumbPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? const Color(0xFFFF0000)
                          : Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.artist != null && item.artist!.isNotEmpty)
                  Text(item.artist!,
                      style: GoogleFonts.spaceMono(
                          fontSize: 9, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _pc.audioHandler.skipToQueueItem(index),
            child: const Icon(Icons.play_circle_outline_rounded,
                color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _pc.audioHandler.removeQueueItem(item),
            child: const Icon(Icons.close_rounded,
                color: Colors.grey, size: 18),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.drag_handle_rounded,
              color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _queueThumbPlaceholder() => Container(
        width: 42,
        height: 42,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note_rounded,
            size: 16, color: Colors.grey),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _idController.dispose();
    _titleController.dispose();
    super.dispose();
  }
}