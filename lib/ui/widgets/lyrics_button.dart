// ui/widgets/lyrics_button.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/lyrics_controller.dart';
import '../immersive_lyrics_screen.dart';

class LyricsButton extends StatefulWidget {
  const LyricsButton({super.key});

  @override
  State<LyricsButton> createState() => _LyricsButtonState();
}

class _LyricsButtonState extends State<LyricsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lc = Get.find<LyricsController>();
    return Obx(() {
      final available = lc.isAvailable.value;
      final loading   = lc.isLoading.value;

      return GestureDetector(
        onTap: available
            ? () {
                HapticFeedback.lightImpact();
                lc.openLyrics();
                Navigator.of(context).push(_lyricsRoute());
              }
            : null,
        child: AnimatedOpacity(
          opacity: available ? 1.0 : 0.38,
          duration: const Duration(milliseconds: 300),
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) {
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                  border: Border.all(
                    color: available
                        ? Colors.white.withOpacity(0.18 + _glowAnim.value * 0.12)
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: available
                      ? [
                          BoxShadow(
                            color: Colors.white
                                .withOpacity(0.06 * _glowAnim.value),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Center(
                      child: loading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            )
                          : Icon(
                              Icons.lyrics_outlined,
                              color: available
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                              size: 20,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  PageRouteBuilder _lyricsRoute() => PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ImmersiveLyricsScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final fade  = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      );
}