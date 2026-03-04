// ui/local_playlist_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/player_controller.dart';
import '../services/library_service.dart';
import 'add_to_local_playlist_screen.dart';
import 'app_theme.dart';
import 'widgets/mini_player_bar.dart';

class LocalPlaylistScreen extends StatefulWidget {
  final String  title;
  final bool    isLiked;
  final String? playlistId;

  const LocalPlaylistScreen({
    super.key,
    required this.title,
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

  void _load() => setState(() {
        if (widget.isLiked) {
          _tracks = LibraryService.getLiked();
        } else {
          final pl = LibraryService.getPlaylists()
              .firstWhereOrNull((p) => p.id == widget.playlistId);
          _tracks = pl?.tracks ?? [];
        }
      });

  // ── Playback ───────────────────────────────────────────────────────────────

  Future<void> _playAllFromIndex(int startIndex) async {
    if (_tracks.isEmpty) return;
    final slice = _tracks.sublist(startIndex.clamp(0, _tracks.length - 1));
    final first = slice.first;
    await _pc.playVideoId(first.videoId,
        title: first.title, artist: first.artist,
        thumbnail: first.thumbnail, duration: first.durationValue);
    for (final t in slice.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artist,
          thumbnail: t.thumbnail, duration: t.durationValue);
    }
    _snack('Playing ${slice.length} songs');
  }

  Future<void> _shuffleAll() async {
    if (_tracks.isEmpty) return;
    final shuffled = [..._tracks]..shuffle();
    final first = shuffled.first;
    await _pc.playVideoId(first.videoId,
        title: first.title, artist: first.artist,
        thumbnail: first.thumbnail, duration: first.durationValue);
    for (final t in shuffled.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artist,
          thumbnail: t.thumbnail, duration: t.durationValue);
    }
    _snack('Shuffled ${shuffled.length} songs');
  }

  void _addAllToQueue() {
    for (final t in _tracks) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artist,
          thumbnail: t.thumbnail, duration: t.durationValue);
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

  void _openAddSongs() {
    if (widget.isLiked) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddToLocalPlaylistScreen(
          playlistId: widget.playlistId!, title: widget.title),
    )).then((_) => _load());
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: AppText.subtitle()),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.elevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  String get _thumbUrl => _tracks.isNotEmpty ? _tracks.first.thumbnail : '';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        CustomScrollView(slivers: [

          // ── Collapsing header ──────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.bg,
            expandedHeight: 260,
            pinned: true,
            leading: const AppBackButton(),
            actions: [
              if (!widget.isLiked && widget.playlistId != null)
                IconButton(
                  onPressed: () { AppHaptics.light(); _openAddSongs(); },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(fit: StackFit.expand, children: [
                _thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _thumbUrl, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppColors.surface))
                    : Container(
                        color: widget.isLiked
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.surface,
                        child: Icon(
                          widget.isLiked
                              ? Icons.favorite_rounded
                              : Icons.queue_music_rounded,
                          size: 80,
                          color: widget.isLiked
                              ? AppColors.accent.withOpacity(0.4)
                              : AppColors.textMuted,
                        ),
                      ),
                // Gradient
                Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000), Colors.black],
                    stops: [0.3, 0.72, 1.0],
                  ),
                )),
                // Info
                Positioned(left: 16, right: 16, bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isLiked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 12),
                              const SizedBox(width: 5),
                              Text('LIKED', style: AppText.label(color: AppColors.accent)),
                            ]),
                          ),
                        ),
                      Text(widget.title,
                          style: GoogleFonts.inter(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text('${_tracks.length} songs', style: AppText.subtitle()),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Expanded(child: PrimaryButton(
                  label: 'PLAY ALL', icon: Icons.play_arrow_rounded,
                  onTap: () => _playAllFromIndex(0),
                )),
                const SizedBox(width: 10),
                Expanded(child: SecondaryButton(
                  label: 'SHUFFLE', icon: Icons.shuffle_rounded,
                  onTap: _shuffleAll,
                )),
                const SizedBox(width: 10),
                Expanded(child: SecondaryButton(
                  label: 'QUEUE', icon: Icons.add_rounded,
                  onTap: _addAllToQueue,
                  outlined: true,
                )),
              ]),
            ),
          ),

          // ── Empty state ────────────────────────────────────────────────────
          if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  widget.isLiked ? Icons.favorite_border_rounded : Icons.queue_music_rounded,
                  size: 48, color: AppColors.textMuted),
                const SizedBox(height: 14),
                Text(
                  widget.isLiked ? 'No liked songs yet' : 'Playlist is empty',
                  style: AppText.title(size: 15)),
                const SizedBox(height: 6),
                Text(
                  widget.isLiked
                      ? 'Tap ♥ on any song to add it here'
                      : 'Tap + to add songs',
                  style: AppText.subtitle()),
              ])),
            ),

          // ── Track list ─────────────────────────────────────────────────────
          if (_tracks.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _trackTile(_tracks[i], i + 1),
                childCount: _tracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ]),
        const MiniPlayerBar(),
      ]),
    );
  }

  // ── Track tile ─────────────────────────────────────────────────────────────

  Widget _trackTile(LibraryTrack t, int index) {
    return GestureDetector(
      onTap: () => _playAllFromIndex(index - 1),
      onLongPress: () => _trackOptions(t),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          // Index
          SizedBox(
            width: 24,
            child: Text('$index',
                style: AppText.caption(), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          // Thumb
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.thumbnail, width: 46, height: 46, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 46, radius: 8))
                : const ThumbPlaceholder(size: 46, radius: 8),
          ),
          const SizedBox(width: 12),
          // Title + Artist
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: AppText.title(size: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(t.artist,
                    style: AppText.subtitle(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          // Duration
          if (t.duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(t.duration, style: AppText.caption()),
          ],
          // More
          GestureDetector(
            onTap: () => _trackOptions(t),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Track options sheet ────────────────────────────────────────────────────

  void _trackOptions(LibraryTrack t) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.thumbnail.isNotEmpty
                    ? CachedNetworkImage(imageUrl: t.thumbnail,
                        width: 48, height: 48, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 48))
                    : const ThumbPlaceholder(size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: AppText.title(size: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(t.artist, style: AppText.subtitle(),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          ),
          Divider(color: AppColors.border, height: 24),
          ListTile(
            leading: Icon(Icons.add_to_queue_rounded,
                color: AppColors.textSecondary, size: 20),
            title: Text('Add to queue', style: AppText.title(size: 14)),
            onTap: () {
              AppHaptics.light();
              _pc.addToQueue(t.videoId, title: t.title, artist: t.artist,
                  thumbnail: t.thumbnail, duration: t.durationValue);
              Navigator.pop(context);
              _snack('Added to queue');
            },
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          ListTile(
            leading: Icon(
              widget.isLiked
                  ? Icons.heart_broken_outlined
                  : Icons.remove_circle_outline_rounded,
              color: AppColors.accent, size: 20),
            title: Text(
              widget.isLiked ? 'Unlike' : 'Remove from playlist',
              style: AppText.title(size: 14, color: AppColors.accent)),
            onTap: () {
              AppHaptics.medium();
              Navigator.pop(context);
              _removeTrack(t);
            },
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ]),
      ),
    );
  }
}