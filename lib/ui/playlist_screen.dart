// ui/playlist_screen.dart
// Full-screen playlist detail page.
// Header: large blurred thumbnail + title + author + track count + total duration.
// Body: numbered track list — tap to play, long press to add to queue.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/player_controller.dart';
import '../services/playlist_service.dart';
import '../services/recommendation_service.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String playlistTitle;
  final String thumbnailUrl;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    required this.thumbnailUrl,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final PlayerController _pc = Get.find();

  PlaylistDetail? _detail;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final data = await PlaylistService.getPlaylist(widget.playlistId);
    if (mounted) {
      setState(() {
        _detail = data;
        _loading = false;
        _error = data == null;
      });
    }
  }

  // ── play helpers ──────────────────────────────────────────────────────────

  /// Plays first track immediately, queues all remaining playlist tracks,
  /// then fetches recommendations and appends them at the very end.
  /// This preserves playlist order: Song1 → Song2...SongN → recommendations.
  void _playAll() {
    if (_detail == null || _detail!.tracks.isEmpty) return;
    final tracks = _detail!.tracks;

    // Clear current queue
    _pc.audioHandler.customAction('clearQueue');

    // Play first song WITHOUT recommendations (use plain playVideoId)
    final first = tracks.first;
    _pc.playVideoId(first.videoId,
        title: first.title,
        artist: first.artistLine,
        thumbnail: first.thumbnailUrl,
        duration: first.durationValue);

    // Queue ALL remaining playlist tracks immediately after
    for (final t in tracks.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title,
          artist: t.artistLine,
          thumbnail: t.thumbnailUrl,
          duration: t.durationValue);
    }

    // Fetch recommendations in background and append AFTER the full playlist
    RecommendationService.getRecommendations(first.videoId).then((recs) {
      for (final r in recs) {
        _pc.addToQueue(r.videoId,
            title: r.title,
            artist: r.artist,
            thumbnail: r.thumbnail,
            duration: r.durationValue);
      }
    });

    _snack('Playing ${tracks.length} songs');
  }

  /// Silently appends every track in the playlist to the current queue.
  void _addAllToQueue() {
    if (_detail == null || _detail!.tracks.isEmpty) return;
    for (final t in _detail!.tracks) {
      _pc.addToQueue(t.videoId,
          title: t.title,
          artist: t.artistLine,
          thumbnail: t.thumbnailUrl,
          duration: t.durationValue);
    }
    _snack('Added ${_detail!.tracks.length} songs to queue');
  }

  void _playSong(PlaylistTrack t) {
    _pc.playWithRecommendations(t.videoId,
        title: t.title,
        artist: t.artistLine,
        thumbnail: t.thumbnailUrl,
        duration: t.durationValue);
    _snack('Playing: ${t.title}');
  }

  void _queueSong(PlaylistTrack t) {
    _pc.addToQueue(t.videoId,
        title: t.title,
        artist: t.artistLine,
        thumbnail: t.thumbnailUrl,
        duration: t.durationValue);
    _snack('Added: ${t.title}');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF1C1C1C)),
      );

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? _loadingView()
          : _error || _detail == null
              ? _errorView()
              : _contentView(),
    );
  }

  Widget _loadingView() => SafeArea(
        child: Column(children: [
          _backBar(widget.playlistTitle),
          const Expanded(
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF3B30), strokeWidth: 2)),
          ),
        ]),
      );

  Widget _errorView() => SafeArea(
        child: Column(children: [
          _backBar(widget.playlistTitle),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded,
                    size: 52, color: Colors.grey.shade800),
                const SizedBox(height: 12),
                Text('Could not load playlist',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _load,
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
            ),
          ),
        ]),
      );

  Widget _contentView() {
    final d = _detail!;
    return CustomScrollView(
      slivers: [
        // ── Collapsing header ─────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: Colors.black,
          expandedHeight: 300,
          pinned: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred background
                if (d.thumbnailUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: d.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF111111))),
                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xCC000000),
                        Colors.black,
                      ],
                      stops: [0.3, 0.75, 1.0],
                    ),
                  ),
                ),
                // Info at bottom of header
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.title.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (d.authorName.isNotEmpty) ...[
                          Text(d.authorName.toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          Text('  ·  ',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade600)),
                        ],
                        Text(
                          '${d.trackCount} songs  ·  ${d.totalDuration}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Action buttons ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              // PLAY ALL
              Expanded(
                child: GestureDetector(
                  onTap: _playAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text('PLAY ALL',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1.5)),
                        ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ADD ALL TO QUEUE
              Expanded(
                child: GestureDetector(
                  onTap: _addAllToQueue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.grey.shade300, size: 20),
                          const SizedBox(width: 6),
                          Text('ADD TO QUEUE',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade300,
                                  letterSpacing: 1.2)),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Description ───────────────────────────────────────────────────
        if (d.description.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                d.description,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // ── Track count label ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'TRACKS',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 2.5),
            ),
          ),
        ),

        // ── Track list ────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= d.tracks.length) return null;
              final t = d.tracks[i];
              return _trackTile(t, i + 1);
            },
            childCount: d.tracks.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _backBar(String title) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );

  Widget _trackTile(PlaylistTrack t, int index) {
    return GestureDetector(
      onTap: () => _playSong(t),
      onLongPress: () => _showTrackOptions(t),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade900, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Index number
          SizedBox(
            width: 28,
            child: Text('$index',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: t.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: t.thumbnailUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _thumb())
                : _thumb(),
          ),
          const SizedBox(width: 12),
          // Title + artist
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(t.artistLine.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          // Duration
          if (t.duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(t.duration,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(width: 8),
          // More options
          GestureDetector(
            onTap: () => _showTrackOptions(t),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.more_vert_rounded,
                  color: Colors.grey.shade700, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _thumb() => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(Icons.music_note_rounded,
            size: 20, color: Colors.grey.shade800),
      );

  void _showTrackOptions(PlaylistTrack t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Song info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: t.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: t.thumbnailUrl,
                        width: 48, height: 48, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _thumb())
                    : _thumb(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(t.artistLine,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ]),
          ),
          Divider(color: Colors.grey.shade900, height: 20),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22),
            title: Text('Play now',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _playSong(t);
            },
            dense: true,
          ),
          ListTile(
            leading: Icon(Icons.add_rounded,
                color: Colors.grey.shade400, size: 22),
            title: Text('Add to queue',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _queueSong(t);
            },
            dense: true,
          ),
        ]),
      ),
    );
  }
}