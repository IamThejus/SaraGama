// ui/now_playing_screen.dart
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/player_controller.dart';
import '../services/library_service.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final screenW = MediaQuery.of(context).size.width;
    final artSize = screenW * 0.78;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 32),
                ),
                const Spacer(),
                Text('NOW PLAYING',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 2.5)),
                const Spacer(),
                // ⋮ menu
                Obx(() {
                  final song = pc.currentSong.value;
                  return IconButton(
                    onPressed: song != null
                        ? () => _showMoreMenu(context, pc, song)
                        : null,
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.grey, size: 24),
                  );
                }),
              ]),
            ),

            const Spacer(),

            // ── Artwork with red ring ─────────────────────────────────────
            Obx(() {
              final song = pc.currentSong.value;
              final artUrl = song?.artUri?.toString() ?? '';
              final isPlaying =
                  pc.buttonState.value == PlayButtonState.playing;

              return Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: isPlaying ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      width: artSize + 32,
                      height: artSize + 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              const Color(0xFFFF3B30).withOpacity(0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF3B30).withOpacity(0.18),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: artUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artUrl,
                            width: artSize,
                            height: artSize,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _artPlaceholder(artSize),
                          )
                        : _artPlaceholder(artSize),
                  ),
                ],
              );
            }),

            const Spacer(),

            // ── Title + Artist + Like ─────────────────────────────────────
            Obx(() {
              final song = pc.currentSong.value;
              final liked = pc.isCurrentSongLiked.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song?.title.toUpperCase() ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (song?.artist ?? '').toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                  ),
                  // Like button
                  GestureDetector(
                    onTap: pc.toggleLike,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(liked),
                          color: liked
                              ? const Color(0xFFFF3B30)
                              : Colors.grey.shade500,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            }),

            const SizedBox(height: 20),

            // ── Progress bar ──────────────────────────────────────────────
            Obx(() {
              final state = pc.progressBarState.value;
              final total =
                  state.total.inSeconds.toDouble();
              final current =
                  state.current.inSeconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
              return Column(children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade800,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.1),
                  ),
                  child: Slider(
                    value: current,
                    min: 0,
                    max: total > 0 ? total : 1,
                    onChanged: (v) =>
                        pc.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(state.current),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                      Text(_fmt(state.total),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ]);
            }),

            const SizedBox(height: 12),

            // ── Controls ──────────────────────────────────────────────────
            Obx(() {
              final state = pc.buttonState.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _iconBtn(
                        icon: Icons.shuffle_rounded,
                        onTap: pc.toggleShuffle,
                        active: pc.isShuffleEnabled.value,
                        size: 22),
                    _iconBtn(
                        icon: Icons.skip_previous_rounded,
                        onTap: pc.prev,
                        size: 36,
                        color: Colors.white),
                    GestureDetector(
                      onTap: () => state == PlayButtonState.playing
                          ? pc.pause()
                          : pc.play(),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x55FF3B30),
                                blurRadius: 24,
                                spreadRadius: 4),
                          ],
                        ),
                        child: state == PlayButtonState.loading
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Icon(
                                state == PlayButtonState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                      ),
                    ),
                    _iconBtn(
                        icon: Icons.skip_next_rounded,
                        onTap: pc.next,
                        size: 36,
                        color: Colors.white),
                    _iconBtn(
                        icon: Icons.repeat_one_rounded,
                        onTap: pc.toggleLoop,
                        active: pc.isLoopEnabled.value,
                        size: 22),
                  ],
                ),
              );
            }),

            const SizedBox(height: 28),

            // ── Bottom actions ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bottomAction(
                    icon: Icons.queue_music_rounded,
                    label: 'UP NEXT',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── More menu (⋮) ─────────────────────────────────────────────────────────

  void _showMoreMenu(
      BuildContext context, PlayerController pc, MediaItem song) {
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
          const SizedBox(height: 12),
          // Song info header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: song.artUri != null
                    ? CachedNetworkImage(
                        imageUrl: song.artUri.toString(),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _miniThumb(),
                      )
                    : _miniThumb(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(song.artist ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ]),
          ),
          Divider(color: Colors.grey.shade900, height: 20),
          // Add to playlist
          ListTile(
            leading: Icon(Icons.playlist_add_rounded,
                color: Colors.grey.shade400, size: 22),
            title: Text('Add to playlist',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylist(context, pc, song);
            },
            dense: true,
          ),
          // Like / Unlike
          Obx(() {
            final liked = pc.isCurrentSongLiked.value;
            return ListTile(
              leading: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked
                      ? const Color(0xFFFF3B30)
                      : Colors.grey.shade400,
                  size: 22),
              title: Text(liked ? 'Unlike song' : 'Like song',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                pc.toggleLike();
                Navigator.pop(context);
              },
              dense: true,
            );
          }),
        ]),
      ),
    );
  }

  // ── Add to playlist sheet ─────────────────────────────────────────────────

  void _showAddToPlaylist(
      BuildContext context, PlayerController pc, MediaItem song) {
    final playlists = LibraryService.getPlaylists();
    final track = LibraryTrack(
      videoId: song.id,
      title: song.title,
      artist: song.artist ?? '',
      thumbnail: song.artUri?.toString() ?? '',
      duration: song.duration != null ? _fmt(song.duration!) : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final fresh = LibraryService.getPlaylists();
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scroll) => Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Add to Playlist',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Divider(color: Colors.grey.shade900),
              // Create new playlist
              ListTile(
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded,
                      color: Color(0xFFFF3B30), size: 24),
                ),
                title: Text('Create new playlist',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _createAndAdd(context, track);
                },
                dense: true,
              ),
              Divider(color: Colors.grey.shade900, height: 8),
              // Existing playlists
              Expanded(
                child: fresh.isEmpty
                    ? Center(
                        child: Text('No playlists yet',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600)))
                    : ListView.builder(
                        controller: scroll,
                        itemCount: fresh.length,
                        itemBuilder: (_, i) {
                          final pl = fresh[i];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: pl.thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: pl.thumbnailUrl,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _miniThumb())
                                  : _miniThumb(),
                            ),
                            title: Text(pl.name,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text('${pl.tracks.length} songs',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                            onTap: () {
                              LibraryService.addTrackToPlaylist(
                                  pl.id, track);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    'Added to ${pl.name}',
                                    style: GoogleFonts.inter(
                                        fontSize: 12)),
                                backgroundColor:
                                    const Color(0xFF1C1C1C),
                                duration:
                                    const Duration(seconds: 1),
                              ));
                            },
                            dense: true,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }

  void _createAndAdd(BuildContext context, LibraryTrack track) {
    String name = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 16,
            left: 20,
            right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('New Playlist',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => name = v,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade600, fontSize: 15),
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                if (name.trim().isEmpty) return;
                final pl =
                    LibraryService.createPlaylist(name.trim());
                LibraryService.addTrackToPlaylist(pl.id, track);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Created & added to ${pl.name}',
                      style: GoogleFonts.inter(fontSize: 12)),
                  backgroundColor: const Color(0xFF1C1C1C),
                  duration: const Duration(seconds: 1),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                    child: Text('CREATE & ADD',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _artPlaceholder(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.music_note_rounded,
            size: size * 0.3, color: Colors.grey.shade800),
      );

  Widget _miniThumb() => Container(
        width: 46,
        height: 46,
        color: const Color(0xFF1C1C1C),
        child: Icon(Icons.music_note_rounded,
            size: 20, color: Colors.grey.shade700),
      );

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    double size = 24,
    Color? color,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon,
              size: size,
              color: active
                  ? const Color(0xFFFF3B30)
                  : (color ?? Colors.grey.shade600)),
        ),
      );

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.grey.shade600, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5)),
          ]),
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}