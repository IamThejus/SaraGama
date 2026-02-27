// ui/now_playing_screen.dart
// Full-screen "Now Playing" view — opened when user taps the mini player bar.
// Matches the reference: large artwork with red ring, big title, progress bar,
// shuffle / prev / play-pause / next / repeat controls, UP NEXT bottom action.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import './controllers/player_controller.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  // ADDED For thumbnail creation
  String _resizeGoogleThumb(String url, String size) {
  if (url.isEmpty) return url;

  return url.replaceAll(
    RegExp(r'=w\d+-h\d+-l\d+-rj'),
    size,
  );
}
  // ENded here

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
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  // Down chevron — close
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const Spacer(),
                  Text(
                    'NOW PLAYING',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.grey, size: 24),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Artwork with red ring ────────────────────────────────────
            Obx(() {
              final song = pc.currentSong.value;
              final originalUrl = song?.artUri?.toString() ?? '';
              final artUrl = _resizeGoogleThumb(
                originalUrl,
                "=w600-h600-l90-rj", // Full screen size
              );
              //final artUrl = song?.artUri?.toString() ?? '';
              final isPlaying = pc.buttonState.value == PlayButtonState.playing;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Red glowing ring (only visible when playing)
                  AnimatedOpacity(
                    opacity: isPlaying ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      width: artSize + 32,
                      height: artSize + 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withOpacity(0.18),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Artwork
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: artUrl.isNotEmpty
                        ? Image.network(
                            artUrl,
                            width: artSize,
                            height: artSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _artPlaceholder(artSize),
                          )
                        : _artPlaceholder(artSize),
                  ),
                ],
              );
            }),

            const Spacer(),

            // ── Title + Artist ───────────────────────────────────────────
            Obx(() {
              final song = pc.currentSong.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      song != null
                          ? song.title.toUpperCase()
                          : 'NOTHING PLAYING',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (song?.artist != null && song!.artist!.isNotEmpty)
                      Text(
                        song.artist!.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 28),

            // ── Progress bar ─────────────────────────────────────────────
            Obx(() {
              final state = pc.progressBarState.value;
              final total = state.total.inSeconds.toDouble();
              final current = state.current.inSeconds.toDouble();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade800,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white12,
                      ),
                      child: Slider(
                        value: total > 0 ? current.clamp(0, total) : 0,
                        min: 0,
                        max: total > 0 ? total : 1,
                        onChanged: (v) =>
                            pc.seek(Duration(seconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // ── Controls ─────────────────────────────────────────────────
            Obx(() {
              final state = pc.buttonState.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Shuffle
                    _iconBtn(
                      icon: Icons.shuffle_rounded,
                      onTap: pc.toggleShuffle,
                      active: pc.isShuffleEnabled.value,
                      size: 22,
                    ),

                    // Prev
                    _iconBtn(
                      icon: Icons.skip_previous_rounded,
                      onTap: pc.prev,
                      size: 36,
                      color: Colors.white,
                    ),

                    // Big red play/pause
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
                              spreadRadius: 4,
                            ),
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

                    // Next
                    _iconBtn(
                      icon: Icons.skip_next_rounded,
                      onTap: pc.next,
                      size: 36,
                      color: Colors.white,
                    ),

                    // Repeat
                    _iconBtn(
                      icon: Icons.repeat_one_rounded,
                      onTap: pc.toggleLoop,
                      active: pc.isLoopEnabled.value,
                      size: 22,
                    ),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _artPlaceholder(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.music_note_rounded,
            size: size * 0.3, color: Colors.grey.shade800),
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
          child: Icon(
            icon,
            size: size,
            color: active
                ? const Color(0xFFFF3B30)
                : (color ?? Colors.grey.shade600),
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.grey.shade600, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}