// ui/immersive_lyrics_screen.dart
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/lyrics_controller.dart';
import '../controllers/player_controller.dart';

class ImmersiveLyricsScreen extends StatelessWidget {
  const ImmersiveLyricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ImmersiveLyricsView();
  }
}

class _ImmersiveLyricsView extends StatefulWidget {
  const _ImmersiveLyricsView();

  @override
  State<_ImmersiveLyricsView> createState() => _ImmersiveLyricsViewState();
}

class _ImmersiveLyricsViewState extends State<_ImmersiveLyricsView> {
  final LyricsController _lc = Get.find<LyricsController>();
  final PlayerController _pc = Get.find<PlayerController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bgColor = _lc.dominantColor.value;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Gradient background ────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bgColor,
                    Color.lerp(bgColor, Colors.black, 0.55)!,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── Blur noise overlay ─────────────────────────────────────
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(color: Colors.black.withOpacity(0.22)),
            ),

            // ── Main layout ────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _TopBar(pc: _pc, lc: _lc),
                  Expanded(child: _LyricsBody(lc: _lc, pc: _pc)),
                  _BottomControls(pc: _pc, lc: _lc),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final PlayerController pc;
  final LyricsController lc;
  const _TopBar({required this.pc, required this.lc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final song  = pc.currentSong.value;
      final artUrl = song?.artUri?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            // Album thumb — tap to close
            GestureDetector(
              onTap: () {
                lc.closeLyrics();
                Navigator.of(context).pop();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: artUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _artFallback(),
                      )
                    : _artFallback(),
              ),
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song?.title ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song?.artist ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Close button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                lc.closeLyrics();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _artFallback() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.music_note_rounded,
            size: 20, color: Colors.white.withOpacity(0.4)),
      );
}

// ── Lyrics body ────────────────────────────────────────────────────────────

class _LyricsBody extends StatelessWidget {
  final LyricsController lc;
  final PlayerController pc;
  const _LyricsBody({required this.lc, required this.pc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (lc.isLoading.value) {
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withOpacity(0.4),
          ),
        );
      }

      if (!lc.isAvailable.value) {
        return Center(
          child: Text(
            'No lyrics found',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        );
      }

      if (lc.hasSynced.value) {
        return _SyncedLyricsView(lc: lc);
      }

      return _PlainLyricsView(lc: lc);
    });
  }
}

// ── Synced lyrics ──────────────────────────────────────────────────────────

class _SyncedLyricsView extends StatelessWidget {
  final LyricsController lc;
  const _SyncedLyricsView({required this.lc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lines  = lc.parsedLyrics;
      final active = lc.activeIndex.value;

      return ListView.builder(
        controller: lc.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final distance = (i - active).abs();
          return _SyncedLine(
            text: lines[i].text,
            isActive: i == active,
            distance: distance,
          );
        },
      );
    });
  }
}

class _SyncedLine extends StatelessWidget {
  final String text;
  final bool   isActive;
  final int    distance;

  const _SyncedLine({
    required this.text,
    required this.isActive,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isActive
        ? 1.0
        : distance == 1
            ? 0.55
            : distance == 2
                ? 0.30
                : 0.18;

    final fontSize = isActive ? 26.0 : 22.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: LyricsController.lineHeight,
      alignment: Alignment.centerLeft,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: Colors.white.withOpacity(opacity),
          height: 1.3,
          shadows: isActive
              ? [
                  Shadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ── Plain lyrics ───────────────────────────────────────────────────────────

class _PlainLyricsView extends StatelessWidget {
  final LyricsController lc;
  const _PlainLyricsView({required this.lc});

  @override
  Widget build(BuildContext context) {
    final lines = lc.plainLyrics.value.split('\n');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final text = lines[i].trim();
        if (text.isEmpty) return const SizedBox(height: 16);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.75),
              height: 1.4,
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom controls ────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final PlayerController pc;
  final LyricsController lc;
  const _BottomControls({required this.pc, required this.lc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state   = pc.buttonState.value;
      final progress = pc.progressBarState.value;
      final total   = progress.total.inSeconds.toDouble();
      final current = progress.current.inSeconds
          .toDouble()
          .clamp(0.0, total > 0 ? total : 1.0);

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: Colors.white.withOpacity(0.85),
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.08),
              ),
              child: Slider(
                value: current,
                min: 0,
                max: total > 0 ? total : 1,
                onChanged: (v) => pc.seek(Duration(seconds: v.toInt())),
              ),
            ),
            // Time labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(progress.current),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  Text(
                    _fmt(progress.total),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CtrlBtn(
                  icon: Icons.shuffle_rounded,
                  size: 22,
                  active: pc.isShuffleEnabled.value,
                  onTap: pc.toggleShuffle,
                ),
                _CtrlBtn(
                  icon: Icons.skip_previous_rounded,
                  size: 34,
                  onTap: pc.prev,
                ),
                // Play / Pause
                GestureDetector(
                  onTap: () => state == PlayButtonState.playing
                      ? pc.pause()
                      : pc.play(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25), width: 1),
                    ),
                    child: state == PlayButtonState.loading
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          )
                        : Icon(
                            state == PlayButtonState.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                  ),
                ),
                _CtrlBtn(
                  icon: Icons.skip_next_rounded,
                  size: 34,
                  onTap: pc.next,
                ),
                _CtrlBtn(
                  icon: Icons.repeat_one_rounded,
                  size: 22,
                  active: pc.isLoopEnabled.value,
                  onTap: pc.toggleLoop,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final double   size;
  final bool     active;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: size,
          color: active
              ? Colors.white
              : Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}