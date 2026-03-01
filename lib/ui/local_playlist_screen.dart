// ui/local_playlist_screen.dart
// Shows a local (Hive-stored) playlist — liked songs or custom playlist.
// Same visual style as PlaylistScreen but data comes from LibraryService.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/player_controller.dart';
import '../services/library_service.dart';

class LocalPlaylistScreen extends StatefulWidget {
  final String title;
  final String? heroTag; // optional — "liked" or playlist id
  final bool isLiked;    // true = liked songs, false = custom playlist
  final String? playlistId;

  const LocalPlaylistScreen({
    super.key,
    required this.title,
    this.heroTag,
    this.isLiked = false,
    this.playlistId,
  });

  @override
  State<LocalPlaylistScreen> createState() => _LocalPlaylistScreenState();
}

class _LocalPlaylistScreenState extends State<LocalPlaylistScreen> {
  final PlayerController _pc = Get.find();
  List<LibraryTrack> _tracks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      if (widget.isLiked) {
        _tracks = LibraryService.getLiked();
      } else {
        final pl = LibraryService.getPlaylists()
            .firstWhereOrNull((p) => p.id == widget.playlistId);
        _tracks = pl?.tracks ?? [];
      }
    });
  }

  void _playSong(LibraryTrack t) {
    _pc.playWithRecommendations(t.videoId,
        title: t.title,
        artist: t.artist,
        thumbnail: t.thumbnail,
        duration: t.durationValue);
    _snack('Playing: ${t.title}');
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    _pc.audioHandler.customAction('clearQueue');
    final first = _tracks.first;
    _pc.playWithRecommendations(first.videoId,
        title: first.title,
        artist: first.artist,
        thumbnail: first.thumbnail,
        duration: first.durationValue);
    for (final t in _tracks.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title,
          artist: t.artist,
          thumbnail: t.thumbnail,
          duration: t.durationValue);
    }
    _snack('Playing ${_tracks.length} songs');
  }

  void _addAllToQueue() {
    for (final t in _tracks) {
      _pc.addToQueue(t.videoId,
          title: t.title,
          artist: t.artist,
          thumbnail: t.thumbnail,
          duration: t.durationValue);
    }
    _snack('Added ${_tracks.length} songs to queue');
  }

  void _removeTrack(LibraryTrack t) {
    if (widget.isLiked) {
      LibraryService.unlike(t.videoId);
    } else {
      LibraryService.removeTrackFromPlaylist(widget.playlistId!, t.videoId);
    }
    _load();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF1C1C1C)),
      );

  String get _thumbUrl =>
      _tracks.isNotEmpty ? _tracks.first.thumbnail : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header ───────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.black,
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(fit: StackFit.expand, children: [
                // blurred bg
                _thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFF111111)),
                      )
                    : Container(
                        color: widget.isLiked
                            ? const Color(0xFF1A0A0A)
                            : const Color(0xFF0A0A1A),
                        child: Icon(
                          widget.isLiked
                              ? Icons.favorite_rounded
                              : Icons.queue_music_rounded,
                          size: 80,
                          color: widget.isLiked
                              ? const Color(0xFFFF3B30).withOpacity(0.3)
                              : Colors.grey.shade800,
                        ),
                      ),
                // gradient
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
                      stops: [0.3, 0.7, 1.0],
                    ),
                  ),
                ),
                // info
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isLiked)
                        Icon(Icons.favorite_rounded,
                            color: const Color(0xFFFF3B30), size: 28),
                      const SizedBox(height: 6),
                      Text(
                        widget.title.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.length} songs',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Action buttons ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
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

          // ── Empty state ─────────────────────────────────────────────────
          if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    widget.isLiked
                        ? Icons.favorite_border_rounded
                        : Icons.queue_music_rounded,
                    size: 52,
                    color: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isLiked
                        ? 'No liked songs yet'
                        : 'Playlist is empty',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isLiked
                        ? 'Tap ♥ on any song to add it here'
                        : 'Use ⋮ on any song to add it here',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade700),
                  ),
                ]),
              ),
            ),

          // ── Track list ──────────────────────────────────────────────────
          if (_tracks.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _trackTile(_tracks[i], i + 1),
                childCount: _tracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _trackTile(LibraryTrack t, int index) {
    return GestureDetector(
      onTap: () => _playSong(t),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: Colors.grey.shade900, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
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
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: t.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.thumbnail,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _thumb(),
                  )
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
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(t.artist.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          if (t.duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(t.duration,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
          const SizedBox(width: 4),
          // Remove from playlist/liked
          GestureDetector(
            onTap: () => _confirmRemove(t),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.remove_circle_outline_rounded,
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

  void _confirmRemove(LibraryTrack t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('Remove "${t.title}"?',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            widget.isLiked
                ? 'This will unlike the song'
                : 'This will remove it from the playlist',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('CANCEL',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _removeTrack(t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('REMOVE',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5))),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}