// audio_handler.dart
// Mirrors HarmonyMusic's MyAudioHandler architecture:
//   - BaseAudioHandler + GetxServiceMixin
//   - checkNGetUrl() with Hive URL cache + Isolate fetching
//   - LockCachingAudioSource for transparent disk caching
//   - Loop, shuffle, queue-loop, loudness normalisation
//   - Custom actions as the internal command bus

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/hm_streaming_data.dart';
import '../services/background_task.dart';
import '../controllers/player_controller.dart';

Future<AudioHandler> initAudioService() async {
  return AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ytplayer.audio',
      androidNotificationChannelName: 'YTPlayer',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Check if a stream URL has expired (30-minute safety buffer).
/// Mirrors HarmonyMusic's isExpired() util.
bool _isUrlExpired(String url) {
  final match = RegExp(r'expire=(\d+)').firstMatch(url);
  if (match != null) {
    final epoch = int.parse(match.group(1)!);
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800 >= epoch;
  }
  return true; // assume expired if no expiry found
}

// ── MyAudioHandler ─────────────────────────────────────────────────────────

class MyAudioHandler extends BaseAudioHandler with GetxServiceMixin {
  late final String _cacheDir;
  late final AudioPlayer _player;

  dynamic currentIndex;
  late String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;
  bool isSongLoading = true;
  bool _isTransitioning = false; // prevents double-trigger on song end

  List<String> shuffledQueue = [];
  int currentShuffleIndex = 0;

  final _playList =
      ConcatenatingAudioSource(children: [], useLazyPreparation: false);

  MyAudioHandler() {
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 50),
          maxBufferDuration: Duration(seconds: 120),
          bufferForPlaybackDuration: Duration(milliseconds: 50),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        ),
      ),
    );

    _createCacheDir();
    _addEmptyPlaylist();
    _notifyAboutPlaybackEvents();
    _listenForNextSong();
    _listenForDurationChanges();

    final prefs = Hive.box('AppPrefs');
    loopModeEnabled = prefs.get('loopMode') ?? false;
    shuffleModeEnabled = prefs.get('shuffleMode') ?? false;
    queueLoopModeEnabled = prefs.get('queueLoopMode') ?? false;
    loudnessNormalizationEnabled =
        prefs.get('loudnessNormalization') ?? false;
  }

  // ── Init helpers ──────────────────────────────────────────────────────────

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    final dir = Directory('$_cacheDir/cachedSongs/');
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  void _addEmptyPlaylist() {
    try {
      _player.setAudioSource(_playList);
    } catch (_) {}
  }

  // ── Playback event broadcasting ────────────────────────────────────────────

  void _notifyAboutPlaybackEvents() {
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: isSongLoading
              ? AudioProcessingState.loading
              : {
                  ProcessingState.idle: AudioProcessingState.idle,
                  ProcessingState.loading: AudioProcessingState.loading,
                  ProcessingState.buffering: AudioProcessingState.buffering,
                  ProcessingState.ready: AudioProcessingState.ready,
                  ProcessingState.completed: AudioProcessingState.completed,
                }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: currentIndex,
        ));
      },
      onError: (Object e, StackTrace st) async {
        // On any playback error, re-fetch a fresh URL (same recovery as HarmonyMusic)
        final curPos = _player.position;
        await _player.stop();
        customAction('playByIndex', {'index': currentIndex, 'newUrl': true});
        await _player.seek(curPos, index: 0);
      },
    );
  }

  // ── Auto-advance to next song ─────────────────────────────────────────────
  // HarmonyMusic uses a position-stream approach on desktop to work around
  // media_kit timing differences. We do the same generically.

  void _listenForNextSong() {
    _player.positionStream.listen((pos) async {
      if (_isTransitioning) return; // already handling a transition
      if (_player.duration != null && _player.duration!.inSeconds != 0) {
        if (pos.inMilliseconds >=
            (_player.duration!.inMilliseconds - 200)) {
          _isTransitioning = true;
          await _triggerNext();
        }
      }
    });
  }

  Future<void> _triggerNext() async {
    if (loopModeEnabled) {
      await _player.seek(Duration.zero);
      if (!_player.playing) _player.play();
      _isTransitioning = false;
      return;
    }
    await skipToNext();
    // _isTransitioning is reset inside playByIndex after new song starts
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) async {
      final currQueue = queue.value;
      if (currentIndex == null || currQueue.isEmpty || duration == null) return;
      final currentSong = currQueue[currentIndex];
      if (currentSong.duration == null || currentIndex == 0) {
        mediaItem.add(currentSong.copyWith(duration: duration));
      }
    });
  }

  // ── Queue management ───────────────────────────────────────────────────────

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
    if (shuffleModeEnabled) {
      final ids = mediaItems.map((i) => i.id).toList();
      shuffledQueue.addAll(ids);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    if (shuffleModeEnabled) shuffledQueue.add(item.id);
    final newQueue = queue.value..add(item);
    queue.add(newQueue);
  }

  @override
  Future<void> removeQueueItem(MediaItem item) async {
    if (shuffleModeEnabled) {
      final idx = shuffledQueue.indexOf(item.id);
      if (currentShuffleIndex > idx) currentShuffleIndex -= 1;
      shuffledQueue.remove(item.id);
    }
    final currQueue = queue.value;
    final currSong = mediaItem.value;
    final idx = currQueue.indexOf(item);
    if (currentIndex > idx) currentIndex -= 1;
    currQueue.remove(item);
    queue.add(currQueue);
    mediaItem.add(currSong);
  }

  @override
  Future<void> updateQueue(List<MediaItem> items) async {
    final newQueue = queue.value..replaceRange(0, queue.value.length, items);
    queue.add(newQueue);
  }

  // ── Audio source factory ───────────────────────────────────────────────────

  AudioSource _createAudioSource(MediaItem item) {
    final url = item.extras!['url'] as String;
    if (url.startsWith('file://') ||
        (Get.find<PlayerController>().cacheSongs.isTrue &&
            url.startsWith('http'))) {
      isPlayingUsingLockCachingSource = true;
      return LockCachingAudioSource(
        Uri.parse(url),
        cacheFile: File('$_cacheDir/cachedSongs/${item.id}.mp3'),
        tag: item,
      );
    }
    isPlayingUsingLockCachingSource = false;
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    if (currentSongUrl == null) {
      await customAction('playByIndex', {'index': currentIndex});
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await customAction('playByIndex', {'index': index});
  }

  @override
  Future<void> skipToNext() async {
    final index = _getNextSongIndex();
    if (index != currentIndex) {
      if (_player.position != Duration.zero) _player.seek(Duration.zero);
      await customAction('playByIndex', {'index': index});
    } else {
      _player.seek(Duration.zero);
      _player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // HarmonyMusic: if >5 s played, restart current song
    if (_player.position.inMilliseconds > 5000) {
      _player.seek(Duration.zero);
      return;
    }
    _player.seek(Duration.zero);
    final index = _getPrevSongIndex();
    if (index != currentIndex) {
      await customAction('playByIndex', {'index': index});
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    loopModeEnabled = mode != AudioServiceRepeatMode.none;
    Hive.box('AppPrefs').put('loopMode', loopModeEnabled);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    if (mode == AudioServiceShuffleMode.none) {
      shuffleModeEnabled = false;
      shuffledQueue.clear();
    } else {
      _buildShuffledQueue(currentIndex);
      shuffleModeEnabled = true;
    }
    Hive.box('AppPrefs').put('shuffleMode', shuffleModeEnabled);
  }

  // ── Index helpers ─────────────────────────────────────────────────────────

  int _getNextSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex + 1 >= shuffledQueue.length) {
        shuffledQueue.shuffle();
        currentShuffleIndex = 0;
      } else {
        currentShuffleIndex += 1;
      }
      return queue.value
          .indexWhere((i) => i.id == shuffledQueue[currentShuffleIndex]);
    }
    if (queue.value.length > currentIndex + 1) return currentIndex + 1;
    if (queueLoopModeEnabled) return 0;
    return currentIndex;
  }

  int _getPrevSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex - 1 < 0) {
        shuffledQueue.shuffle();
        currentShuffleIndex = shuffledQueue.length - 1;
      } else {
        currentShuffleIndex -= 1;
      }
      return queue.value
          .indexWhere((i) => i.id == shuffledQueue[currentShuffleIndex]);
    }
    if (currentIndex - 1 >= 0) return currentIndex - 1;
    return currentIndex;
  }

  void _buildShuffledQueue(int fromIndex) {
    final ids = queue.value.map((i) => i.id).toList();
    final current = ids.removeAt(fromIndex);
    ids.shuffle();
    ids.insert(0, current);
    shuffledQueue
      ..clear()
      ..addAll(ids);
    currentShuffleIndex = 0;
  }

  // ── Loudness normalisation ────────────────────────────────────────────────
  // Formula: target -5 dBFS → volume = 10^((-5 - loudnessDb) / 20)

  void _normalizeVolume(double loudnessDb) {
    final diff = -5.0 - loudnessDb;
    final vol = pow(10.0, diff / 20.0).toDouble().clamp(0.0, 1.0);
    _player.setVolume(vol);
  }

  // ── Prefetch next song URL ────────────────────────────────────────────────
  // Called after playByIndex so the next song's URL is already in Hive
  // cache when the user skips or the song ends — zero loading delay.

  void _prefetchNext() {
    try {
      final q = queue.value;
      final nextIdx = currentIndex + 1;
      if (nextIdx >= q.length) return;
      final nextId = q[nextIdx].id;
      // Fire and forget — just warms the cache
      checkNGetUrl(nextId).catchError((_) {});
    } catch (_) {}
  }

  // ── URL resolution — mirrors HarmonyMusic's checkNGetUrl() ───────────────
  // Priority: cached file → downloaded file → cached URL → fresh Isolate fetch

  Future<HMStreamingData> checkNGetUrl(String videoId,
      {bool generateNewUrl = false}) async {
    final urlCacheBox = Hive.box('SongsUrlCache');
    final qualityIndex = Hive.box('AppPrefs').get('streamingQuality') ?? 1;

    // 1. Check if URL is cached and still valid
    if (urlCacheBox.containsKey(videoId) && !generateNewUrl) {
      final cached = urlCacheBox.get(videoId);
      if (cached is Map && !_isUrlExpired(cached['lowQualityAudio']?['url'] ?? '')) {
        final data = HMStreamingData.fromJson(Map<String, dynamic>.from(cached));
        data.setQualityIndex(qualityIndex);
        return data;
      }
    }

    // 2. Fetch fresh from YouTube in a background Isolate (same as HarmonyMusic)
    final token = RootIsolateToken.instance!;
    final json = await Isolate.run(() => getStreamInfo(videoId, token));
    final data = HMStreamingData.fromJson(json);

    if (data.playable) {
      urlCacheBox.put(videoId, json);
    }

    data.setQualityIndex(qualityIndex);
    return data;
  }

  // ── customAction — internal command bus ───────────────────────────────────
  // All complex operations go through here (mirrors HarmonyMusic's pattern).

  @override
  Future<void> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {

      // ── Play a song by queue index ──────────────────────────────────────
      case 'playByIndex':
        final songIndex = extras!['index'] as int;
        currentIndex = songIndex;
        final isNewUrl = extras['newUrl'] ?? false;
        final song = queue.value[currentIndex];

        // ── Stop current playback IMMEDIATELY so old song never bleeds ──
        // This is the key fix: pause + clear BEFORE the async URL fetch.
        // Without this, just_audio keeps playing the old source while we
        // await checkNGetUrl(), causing the old song to bleed briefly.
        await _player.pause();
        await _playList.clear();
        currentSongUrl = null;

        isSongLoading = true;
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.loading,
          playing: false,
        ));
        mediaItem.add(song);

        // Fetch URL (cached or fresh) — now happens with player fully stopped
        final streamInfo =
            await checkNGetUrl(song.id, generateNewUrl: isNewUrl);

        // Guard: user may have skipped again while we were fetching
        if (songIndex != currentIndex) return;

        if (!streamInfo.playable) {
          currentSongUrl = null;
          isSongLoading = false;
          Get.find<PlayerController>().notifyError(streamInfo.statusMSG);
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: streamInfo.statusMSG,
          ));
          return;
        }

        currentSongUrl = song.extras!['url'] = streamInfo.audio!.url;
        await _playList.add(_createAudioSource(song));

        isSongLoading = false;
        playbackState
            .add(playbackState.value.copyWith(queueIndex: currentIndex));

        if (loudnessNormalizationEnabled) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        await _player.play();

        // Reset transition guard so next song-end triggers correctly
        _isTransitioning = false;
        // Silently prefetch the next song's URL into cache
        _prefetchNext();
        break;

      // ── Load a single song and play immediately ─────────────────────────
      case 'setSourceNPlay':
        final song = extras!['mediaItem'] as MediaItem;
        isSongLoading = true;
        currentIndex = 0;
        await _playList.clear();
        mediaItem.add(song);
        queue.add([song]);

        final streamInfo = await checkNGetUrl(song.id);

        if (!streamInfo.playable) {
          currentSongUrl = null;
          isSongLoading = false;
          Get.find<PlayerController>().notifyError(streamInfo.statusMSG);
          return;
        }

        currentSongUrl = song.extras!['url'] = streamInfo.audio!.url;
        await _playList.add(_createAudioSource(song));
        isSongLoading = false;

        if (loudnessNormalizationEnabled) {
          _normalizeVolume(streamInfo.audio!.loudnessDb);
        }

        await _player.play();
        break;

      // ── Reorder queue ───────────────────────────────────────────────────
      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'] as int;
        int newIndex = extras['newIndex'] as int;
        if (oldIndex < newIndex) newIndex--;
        final q = queue.value;
        final current = q[currentIndex];
        final item = q.removeAt(oldIndex);
        q.insert(newIndex, item);
        currentIndex = q.indexOf(current);
        queue.add(q);
        mediaItem.add(current);
        break;

      // ── Insert next in queue ────────────────────────────────────────────
      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        final q = queue.value;
        q.insert(currentIndex + 1, song);
        queue.add(q);
        if (shuffleModeEnabled) {
          shuffledQueue.insert(currentShuffleIndex + 1, song.id);
        }
        break;

      // ── Clear all but current ───────────────────────────────────────────
      case 'clearQueue':
        customAction('reorderQueue',
            {'oldIndex': currentIndex, 'newIndex': 0});
        final q = queue.value;
        q.removeRange(1, q.length);
        queue.add(q);
        if (shuffleModeEnabled) {
          shuffledQueue
            ..clear()
            ..add(q.first.id);
          currentShuffleIndex = 0;
        }
        break;

      // ── Toggle loudness normalisation ───────────────────────────────────
      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = extras!['enable'] as bool;
        Hive.box('AppPrefs')
            .put('loudnessNormalization', loudnessNormalizationEnabled);
        if (!loudnessNormalizationEnabled) {
          _player.setVolume(1.0);
        }
        break;

      // ── Toggle queue loop ───────────────────────────────────────────────
      case 'toggleQueueLoop':
        queueLoopModeEnabled = extras!['enable'] as bool;
        Hive.box('AppPrefs').put('queueLoopMode', queueLoopModeEnabled);
        break;

      // ── Set volume (0–100) ──────────────────────────────────────────────
      case 'setVolume':
        _player.setVolume((extras!['value'] as int) / 100);
        break;

      // ── Restore saved session on app start ─────────────────────────────
      case 'restoreSession':
        final items = extras!['items'] as List<MediaItem>;
        final restoreIndex = extras['index'] as int;
        final posMs = extras['positionMs'] as int? ?? 0;
        if (items.isEmpty) break;

        // Rebuild queue without playing yet
        queue.add(items);
        currentIndex = restoreIndex;
        mediaItem.add(items[restoreIndex]);

        isSongLoading = true;
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.loading,
        ));

        final restoreStream = await checkNGetUrl(items[restoreIndex].id);
        if (!restoreStream.playable) {
          isSongLoading = false;
          break;
        }

        currentSongUrl = items[restoreIndex].extras!['url'] =
            restoreStream.audio!.url;
        await _playList.clear();
        await _playList.add(_createAudioSource(items[restoreIndex]));
        isSongLoading = false;
        playbackState.add(playbackState.value.copyWith(
          queueIndex: restoreIndex,
          processingState: AudioProcessingState.ready,
        ));
        // Seek to saved position but don't auto-play — user resumes manually
        await _player.seek(Duration(milliseconds: posMs));
        _prefetchNext();
        break;

      // ── Dispose ─────────────────────────────────────────────────────────
      case 'dispose':
        await _player.dispose();
        super.stop();
        break;

      default:
        break;
    }
  }
}