// controllers/player_controller.dart
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../services/recommendation_service.dart';

class ProgressBarState {
  final Duration current;
  final Duration buffered;
  final Duration total;
  const ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
}

enum PlayButtonState { paused, playing, loading }

class PlayerController extends GetxController {
  final AudioHandler audioHandler;
  PlayerController({required this.audioHandler});

  final currentSong = Rxn<MediaItem>();
  final buttonState = Rx<PlayButtonState>(PlayButtonState.paused);
  final progressBarState = Rx<ProgressBarState>(
    const ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    ),
  );
  final errorMessage = RxnString();
  final isLoopEnabled = false.obs;
  final isShuffleEnabled = false.obs;
  final isHighQuality = true.obs;
  final cacheSongs = false.obs;

  @override
  void onInit() {
    audioHandler.mediaItem.listen((item) => currentSong.value = item);
    audioHandler.playbackState.listen((state) {
      final p = state.processingState;
      if (p == AudioProcessingState.loading ||
          p == AudioProcessingState.buffering) {
        buttonState.value = PlayButtonState.loading;
      } else if (!state.playing) {
        buttonState.value = PlayButtonState.paused;
      } else {
        buttonState.value = PlayButtonState.playing;
      }
    });
    AudioService.position.listen((pos) {
      final duration = currentSong.value?.duration ?? Duration.zero;
      final buffered = audioHandler.playbackState.value.bufferedPosition;
      progressBarState.value = ProgressBarState(
        current: pos,
        buffered: buffered,
        total: duration,
      );
    });
    final q = Hive.box('AppPrefs').get('streamingQuality') ?? 1;
    isHighQuality.value = q == 1;
    super.onInit();
  }

  void play() => audioHandler.play();
  void pause() => audioHandler.pause();
  void next() => audioHandler.skipToNext();
  void prev() => audioHandler.skipToPrevious();
  void seek(Duration pos) => audioHandler.seek(pos);

  void toggleLoop() {
    isLoopEnabled.value = !isLoopEnabled.value;
    audioHandler.setRepeatMode(
      isLoopEnabled.value
          ? AudioServiceRepeatMode.one
          : AudioServiceRepeatMode.none,
    );
  }

  void toggleShuffle() {
    isShuffleEnabled.value = !isShuffleEnabled.value;
    audioHandler.setShuffleMode(
      isShuffleEnabled.value
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  void toggleQuality() {
    isHighQuality.value = !isHighQuality.value;
    Hive.box('AppPrefs').put('streamingQuality', isHighQuality.value ? 1 : 0);
  }

  Future<void> playVideoId(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnail,
    Duration? duration,
  }) async {
    errorMessage.value = null;
    final song = MediaItem(
      id: videoId,
      title: title ?? videoId,
      artist: artist,
      artUri: thumbnail != null ? Uri.tryParse(thumbnail) : null,
      duration: duration,
      extras: {'url': ''},
    );
    await audioHandler.customAction('setSourceNPlay', {'mediaItem': song});
  }

  Future<void> addToQueue(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnail,
    Duration? duration,
  }) async {
    final song = MediaItem(
      id: videoId,
      title: title ?? videoId,
      artist: artist,
      artUri: thumbnail != null ? Uri.tryParse(thumbnail) : null,
      duration: duration,
      extras: {'url': ''},
    );
    await audioHandler.addQueueItem(song);
  }

  /// Plays the song immediately, then silently fetches recommendations
  /// and appends them to the queue so they auto-play next.
  Future<void> playWithRecommendations(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnail,
    Duration? duration,
  }) async {
    // 1. Play the song right away — no waiting
    await playVideoId(videoId,
        title: title, artist: artist, thumbnail: thumbnail, duration: duration);

    // 2. Fetch recommendations in background — fire and forget
    RecommendationService.getRecommendations(videoId).then((recs) {
      for (final r in recs) {
        addToQueue(r.videoId,
            title: r.title,
            artist: r.artist,
            thumbnail: r.thumbnail,
            duration: r.durationValue);
      }
    });
  }

  void notifyError(String msg) => errorMessage.value = msg;
}