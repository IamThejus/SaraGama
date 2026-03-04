// ui/widgets/mini_player_bar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../app_theme.dart';
import '../now_playing_screen.dart';

class MiniPlayerBar extends StatelessWidget {
  final bool showBottomNavGap;
  const MiniPlayerBar({super.key, this.showBottomNavGap = false});

  static const double height          = 68;
  static const double bottomNavHeight = 56;

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    return Obx(() {
      final song   = pc.currentSong.value;
      final state  = pc.buttonState.value;
      final art    = song?.artUri?.toString() ?? '';
      final bottomSafe = MediaQuery.of(context).padding.bottom;

      return Positioned(
        left: 12, right: 12,
        bottom: (showBottomNavGap ? bottomNavHeight : 0) + bottomSafe + 10,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x88000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      // Artwork
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: art.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: art,
                                width: 46, height: 46, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const ThumbPlaceholder(size: 46, radius: 12))
                            : const ThumbPlaceholder(size: 46, radius: 12),
                      ),
                      const SizedBox(width: 12),
                      // Title + Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              style: AppText.title(size: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((song.artist ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                song.artist!,
                                style: AppText.subtitle(size: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Play/Pause
                      _playPause(pc, state),
                      // Next
                      _iconBtn(icon: Icons.skip_next_rounded, onTap: () {
                        AppHaptics.light();
                        pc.next();
                      }),
                    ]),
                  ),
                ),
        ),
      );
    });
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );

  Widget _playPause(PlayerController pc, PlayButtonState state) {
    if (state == PlayButtonState.loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    return _iconBtn(
      icon: state == PlayButtonState.playing
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded,
      onTap: () {
        AppHaptics.light();
        state == PlayButtonState.playing ? pc.pause() : pc.play();
      },
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