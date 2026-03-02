import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/player_controller.dart';
import '../now_playing_screen.dart';

class MiniPlayerBar extends StatelessWidget {
  final bool showBottomNavGap;

  /// If true, leaves space for the bottom nav (used on `PlayerScreen`).
  const MiniPlayerBar({super.key, this.showBottomNavGap = false});

  static const double height = 72;
  static const double bottomNavHeight = 56;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    return Obx(() {
      final song = pc.currentSong.value;
      final state = pc.buttonState.value;
      final art = song?.artUri?.toString() ?? '';
      final bottomSafe = MediaQuery.of(context).padding.bottom;

      return Positioned(
        left: 12,
        right: 12,
        bottom: (showBottomNavGap ? bottomNavHeight : 0) + bottomSafe + 14,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: anim.drive(slide), child: child),
            );
          },
          child: song == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  key: ValueKey(song.id),
                  onTap: () => Navigator.of(context).push(_slideUp()),
                  child: Container(
                    height: height,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF1F1F1F)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 26,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: art.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: art,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _thumbPlaceholder(),
                                )
                              : _thumbPlaceholder(size: 48),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            song.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _playPause(pc, state),
                        _iconBtn(
                          icon: Icons.skip_next_rounded,
                          onTap: pc.next,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
    });
  }

  Widget _thumbPlaceholder({double size = 42}) => Container(
        width: size,
        height: size,
        color: const Color(0xFF1C1C1C),
        child: Icon(Icons.music_note_rounded,
            size: 18, color: Colors.grey.shade700),
      );

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );

  Widget _playPause(PlayerController pc, PlayButtonState state) {
    if (state == PlayButtonState.loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    return _iconBtn(
      icon: state == PlayButtonState.playing
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded,
      onTap: () => state == PlayButtonState.playing ? pc.pause() : pc.play(),
    );
  }

  PageRouteBuilder _slideUp() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: anim.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      );
}

