// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/player_controller.dart';
import 'services/audio_handler.dart';
import 'player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive init (same boxes as HarmonyMusic) ────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox('AppPrefs');
  await Hive.openBox('SongsUrlCache');

  // ── Register audio handler (same as HarmonyMusic) ─────────────────────────
  final audioHandler = await initAudioService();

  // ── Register PlayerController as GetX dependency ──────────────────────────
  Get.put(PlayerController(audioHandler: audioHandler));

  runApp(const YTPlayerApp());
}

class YTPlayerApp extends StatelessWidget {
  const YTPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'YT Audio Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PlayerScreen(),
    );
  }
}
