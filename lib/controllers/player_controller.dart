// controllers/player_controller.dart
import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../services/library_service.dart';
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

  final currentSong    = Rxn<MediaItem>();
  final buttonState    = Rx<PlayButtonState>(PlayButtonState.paused);
  final progressBarState = Rx<ProgressBarState>(
    const ProgressBarState(
      current: Duration.zero, buffered: Duration.zero, total: Duration.zero,
    ),
  );
  final errorMessage      = RxnString();
  final isLoopEnabled     = false.obs;
  final isShuffleEnabled  = false.obs;
  final isHighQuality     = true.obs;
  final cacheSongs        = false.obs;

  // ── Liked state (reactive so mini player / now playing update instantly) ─
  final isCurrentSongLiked = false.obs;

  // ── Search history ────────────────────────────────────────────────────────
  final searchHistory = <LibraryTrack>[].obs;

  @override
  void onInit() {
    // Load search history from Hive
    _loadSearchHistory();

    audioHandler.mediaItem.listen((item) {
      currentSong.value = item;
      if (item != null) {
        // Update liked state reactively
        isCurrentSongLiked.value = LibraryService.isLiked(item.id);
        // Auto-save session whenever song changes
        _saveSession();
      }
    });

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
        current: pos, buffered: buffered, total: duration,
      );
    });

    final q = Hive.box('AppPrefs').get('streamingQuality') ?? 1;
    isHighQuality.value = q == 1;

    // Restore last session after a short delay (let audio service init)
    Future.delayed(const Duration(milliseconds: 500), _restoreSession);

    super.onInit();
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  void play()  => audioHandler.play();
  void pause() => audioHandler.pause();
  void next()  => audioHandler.skipToNext();
  void prev()  => audioHandler.skipToPrevious();
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

  // ── Core play methods ─────────────────────────────────────────────────────

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

  /// Plays song immediately + fetches recommendations in background.
  Future<void> playWithRecommendations(
    String videoId, {
    String? title,
    String? artist,
    String? thumbnail,
    Duration? duration,
  }) async {
    await playVideoId(videoId,
        title: title, artist: artist, thumbnail: thumbnail, duration: duration);
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

  // ── Like / Unlike ─────────────────────────────────────────────────────────

  void toggleLike() {
    final song = currentSong.value;
    if (song == null) return;
    final track = LibraryTrack(
      videoId: song.id,
      title: song.title,
      artist: song.artist ?? '',
      thumbnail: song.artUri?.toString() ?? '',
      duration: song.duration != null ? _fmtDuration(song.duration!) : '',
    );
    LibraryService.toggleLike(track);
    isCurrentSongLiked.value = LibraryService.isLiked(song.id);
  }

  // ── Search History ────────────────────────────────────────────────────────

  void addToSearchHistory(LibraryTrack track) {
    final list = List<LibraryTrack>.from(searchHistory);
    list.removeWhere((t) => t.videoId == track.videoId); // no duplicates
    list.insert(0, track);
    if (list.length > 10) list.removeLast();
    searchHistory.assignAll(list);
    _saveSearchHistory();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    _saveSearchHistory();
  }

  void _loadSearchHistory() {
    final raw = Hive.box('AppPrefs').get('searchHistory', defaultValue: []) as List;
    searchHistory.assignAll(
      raw.map((e) => LibraryTrack.fromMap(Map.from(e))).toList(),
    );
  }

  void _saveSearchHistory() {
    Hive.box('AppPrefs').put(
      'searchHistory',
      searchHistory.map((t) => t.toMap()).toList(),
    );
  }

  // ── Session Save / Restore ────────────────────────────────────────────────

  void _saveSession() {
    try {
      final q = audioHandler.queue.value;
      final idx = audioHandler.playbackState.value.queueIndex ?? 0;
      final pos = progressBarState.value.current.inMilliseconds;
      if (q.isEmpty) return;
      Hive.box('AppPrefs').put('session', {
        'queue': q.map((m) => {
          'id':       m.id,
          'title':    m.title,
          'artist':   m.artist ?? '',
          'artUri':   m.artUri?.toString() ?? '',
          'duration': m.duration?.inMilliseconds ?? 0,
        }).toList(),
        'index': idx,
        'position': pos,
      });
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    try {
      final saved = Hive.box('AppPrefs').get('session');
      if (saved == null || saved is! Map) return;
      final rawQueue = saved['queue'] as List? ?? [];
      if (rawQueue.isEmpty) return;
      final items = rawQueue.map<MediaItem>((m) => MediaItem(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        artist: m['artist'],
        artUri: (m['artUri'] as String).isNotEmpty
            ? Uri.tryParse(m['artUri'])
            : null,
        duration: Duration(milliseconds: m['duration'] as int? ?? 0),
        extras: {'url': ''},
      )).where((m) => m.id.isNotEmpty).toList();

      if (items.isEmpty) return;

      final index = (saved['index'] as int? ?? 0).clamp(0, items.length - 1);
      final posMs = saved['position'] as int? ?? 0;

      await audioHandler.customAction('restoreSession', {
        'items': items,
        'index': index,
        'positionMs': posMs,
      });
    } catch (_) {}
  }

  void notifyError(String msg) => errorMessage.value = msg;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}