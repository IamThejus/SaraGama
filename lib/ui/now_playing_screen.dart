// ui/now_playing_screen.dart
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/lyrics_controller.dart';
import '../controllers/player_controller.dart';
import '../services/library_service.dart';
import '../services/thumb_util.dart';
import 'app_theme.dart';
import 'widgets/lyrics_button.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  final PlayerController pc = Get.find<PlayerController>();

  late final AnimationController _playBtnCtrl;
  late final Animation<double>   _playBtnScale;

  @override
  void initState() {
    super.initState();
    _playBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _playBtnScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _playBtnCtrl, curve: Curves.easeIn),
    );
    ever(pc.progressBarState, (state) {
      Get.find<LyricsController>().updatePlaybackPosition(state.current);
    });
  }

  @override
  void dispose() {
    _playBtnCtrl.dispose();
    super.dispose();
  }

  void _onPlayTap() {
    HapticFeedback.mediumImpact();
    _playBtnCtrl.forward().then((_) => _playBtnCtrl.reverse());
    final s = pc.buttonState.value;
    if (s == PlayButtonState.playing) pc.pause(); else pc.play();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final artSize = screenW * 0.80;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
            child: Row(children: [
              IconButton(
                onPressed: () { AppHaptics.light(); Navigator.of(context).pop(); },
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 32),
              ),
              const Spacer(),
              Text('NOW PLAYING', style: AppText.label()),
              const Spacer(),
              Obx(() {
                final song = pc.currentSong.value;
                return IconButton(
                  onPressed: song != null
                      ? () { AppHaptics.light(); _showMoreMenu(context, pc, song); }
                      : null,
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 22),
                );
              }),
            ]),
          ),

          const Spacer(flex: 2),

          // ── Artwork — shrinks when paused ──────────────────────────────────
          Obx(() {
            final song = pc.currentSong.value;
            // Upgrade to full 544px art — tile-size URLs stored at queue time
            // are too small for the large now-playing artwork display.
            final rawArt = song?.artUri?.toString() ?? '';
            final artUrl = rawArt.isNotEmpty
                ? ThumbUtil.upgrade(rawArt, ThumbnailSize.art)
                : '';
            final playing = pc.buttonState.value == PlayButtonState.playing;
            final size = playing ? artSize : artSize * 0.86;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: size, height: size,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedOpacity(
                  opacity: playing ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppColors.accent.withOpacity(0.2),
                      blurRadius: 48, spreadRadius: 10,
                    )],
                  )),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: artUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: artUrl,
                          width: size, height: size, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _artPlaceholder(size))
                      : _artPlaceholder(size),
                ),
              ]),
            );
          }),

          const Spacer(flex: 2),

          // ── Title + Artist + Like ──────────────────────────────────────────
          Obx(() {
            final song  = pc.currentSong.value;
            final liked = pc.isCurrentSongLiked.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song?.title ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(song?.artist ?? '',
                          style: AppText.subtitle(size: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () { AppHaptics.medium(); pc.toggleLike(); },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.elasticOut,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      key: ValueKey(liked),
                      color: liked ? AppColors.accent : AppColors.textSecondary,
                      size: 26,
                    ),
                  ),
                ),
              ]),
            );
          }),

          const SizedBox(height: 24),

          // ── Progress bar with buffered track ───────────────────────────────
          Obx(() {
            final s      = pc.progressBarState.value;
            final total  = s.total.inSeconds.toDouble();
            final cur    = s.current.inSeconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
            final buf    = s.buffered.inSeconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Stack(children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                      activeTrackColor: AppColors.textMuted.withOpacity(0.35),
                      inactiveTrackColor: AppColors.borderSoft,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(value: buf, min: 0, max: total > 0 ? total : 1, onChanged: (_) {}),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: cur, min: 0, max: total > 0 ? total : 1,
                      onChanged: (v) => pc.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(s.current), style: AppText.caption()),
                    Text(_fmt(s.total),   style: AppText.caption()),
                  ],
                ),
              ),
            ]);
          }),

          const SizedBox(height: 16),

          // ── Controls ───────────────────────────────────────────────────────
          Obx(() {
            final state = pc.buttonState.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBtn(icon: Icons.shuffle_rounded,
                      onTap: () { AppHaptics.selection(); pc.toggleShuffle(); },
                      active: pc.isShuffleEnabled.value, size: 22),
                  _iconBtn(icon: Icons.skip_previous_rounded,
                      onTap: () { AppHaptics.light(); pc.prev(); },
                      size: 38, color: Colors.white),
                  GestureDetector(
                    onTap: _onPlayTap,
                    child: ScaleTransition(
                      scale: _playBtnScale,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 24, spreadRadius: 2)],
                        ),
                        child: state == PlayButtonState.loading
                            ? const Padding(padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Icon(
                                state == PlayButtonState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white, size: 38),
                      ),
                    ),
                  ),
                  _iconBtn(icon: Icons.skip_next_rounded,
                      onTap: () { AppHaptics.light(); pc.next(); },
                      size: 38, color: Colors.white),
                  _iconBtn(icon: Icons.repeat_one_rounded,
                      onTap: () { AppHaptics.selection(); pc.toggleLoop(); },
                      active: pc.isLoopEnabled.value, size: 22),
                ],
              ),
            );
          }),

          const SizedBox(height: 28),

          // ── Bottom actions ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _bottomAction(icon: Icons.queue_music_rounded, label: 'QUEUE',
                    onTap: () { AppHaptics.light(); Navigator.of(context).pop(); }),
                const LyricsButton(),
                _bottomAction(icon: Icons.share_rounded, label: 'SHARE',
                    onTap: () => AppHaptics.light()),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ── More menu ──────────────────────────────────────────────────────────────

  void _showMoreMenu(BuildContext context, PlayerController pc, MediaItem song) {
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
                child: song.artUri != null
                    ? CachedNetworkImage(imageUrl: song.artUri.toString(),
                        width: 48, height: 48, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 48))
                    : const ThumbPlaceholder(size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: AppText.title(size: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(song.artist ?? '', style: AppText.subtitle(),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          ),
          Divider(color: AppColors.border, height: 24),
          _menuTile(Icons.playlist_add_rounded, 'Add to playlist', () {
            Navigator.pop(context);
            _showAddToPlaylist(context, pc, song);
          }),
          Obx(() {
            final liked = pc.isCurrentSongLiked.value;
            return _menuTile(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              liked ? 'Unlike' : 'Like song',
              () { AppHaptics.medium(); pc.toggleLike(); Navigator.pop(context); },
              iconColor: liked ? AppColors.accent : null,
            );
          }),
        ]),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap, {Color? iconColor}) =>
      ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
        title: Text(label, style: AppText.title(size: 14)),
        onTap: () { AppHaptics.light(); onTap(); },
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      );

  // ── Add to playlist ────────────────────────────────────────────────────────

  void _showAddToPlaylist(BuildContext context, PlayerController pc, MediaItem song) {
    final track = LibraryTrack(
      videoId: song.id, title: song.title,
      artist: song.artist ?? '',
      thumbnail: song.artUri?.toString() ?? '',
      duration: song.duration != null ? _fmt(song.duration!) : '',
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, _) {
        final pls = LibraryService.getPlaylists();
        return DraggableScrollableSheet(
          initialChildSize: 0.55, minChildSize: 0.35, maxChildSize: 0.85,
          expand: false,
          builder: (_, scroll) => Column(children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            const SizedBox(height: 16),
            Text('Add to Playlist', style: AppText.title(size: 16)),
            const SizedBox(height: 8),
            Divider(color: AppColors.border),
            ListTile(
              leading: Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded, color: AppColors.accent, size: 24)),
              title: Text('Create new playlist', style: AppText.title(size: 14)),
              onTap: () { Navigator.pop(ctx); _createAndAdd(context, track); },
              dense: true,
            ),
            Divider(color: AppColors.border, height: 8),
            Expanded(
              child: pls.isEmpty
                  ? Center(child: Text('No playlists yet', style: AppText.subtitle()))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: pls.length,
                      itemBuilder: (_, i) {
                        final pl = pls[i];
                        return ListTile(
                          leading: ClipRRect(borderRadius: BorderRadius.circular(6),
                            child: pl.thumbnailUrl.isNotEmpty
                                ? CachedNetworkImage(imageUrl: pl.thumbnailUrl,
                                    width: 46, height: 46, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const ThumbPlaceholder(size: 46, radius: 6))
                                : const ThumbPlaceholder(size: 46, radius: 6)),
                          title: Text(pl.name, style: AppText.title(size: 14)),
                          subtitle: Text('${pl.tracks.length} songs', style: AppText.subtitle()),
                          onTap: () {
                            AppHaptics.light();
                            LibraryService.addTrackToPlaylist(pl.id, track);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(_snackBar('Added to ${pl.name}'));
                          },
                          dense: true,
                        );
                      }),
            ),
          ]),
        );
      }),
    );
  }

  void _createAndAdd(BuildContext context, LibraryTrack track) {
    String name = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 16, left: 20, right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('New Playlist', style: AppText.title(size: 16)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => name = v,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: AppText.subtitle(size: 15),
              filled: true, fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
              child: PrimaryButton(label: 'CREATE & ADD', onTap: () {
                if (name.trim().isEmpty) return;
                final pl = LibraryService.createPlaylist(name.trim());
                LibraryService.addTrackToPlaylist(pl.id, track);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    _snackBar('Created & added to ${pl.name}'));
              })),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _artPlaceholder(double size) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: AppColors.elevated,
            borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.music_note_rounded,
            size: size * 0.3, color: AppColors.textMuted),
      );

  Widget _iconBtn({required IconData icon, required VoidCallback onTap,
      bool active = false, double size = 24, Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: size,
              color: active ? AppColors.accent : (color ?? AppColors.textSecondary)),
        ),
      );

  Widget _bottomAction({required IconData icon, required String label,
      required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(height: 5),
            Text(label, style: AppText.label()),
          ]),
        ),
      );

  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg, style: AppText.subtitle()),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.elevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}