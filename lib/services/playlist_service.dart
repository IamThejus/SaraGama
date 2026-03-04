// services/playlist_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class PlaylistTrack {
  final String videoId;
  final String title;
  final String artistLine;
  final String thumbnailUrl;
  final String duration;
  final int durationSeconds;

  const PlaylistTrack({
    required this.videoId,
    required this.title,
    required this.artistLine,
    required this.thumbnailUrl,
    required this.duration,
    required this.durationSeconds,
  });

  Duration get durationValue => Duration(seconds: durationSeconds);

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List? ?? [])
        .map((a) => a['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');
    final thumbs = json['thumbnails'] as List? ?? [];
    // Prefer highest res thumbnail available
    String url = '';
    if (thumbs.isNotEmpty) {
      // Try to get the largest one (last in list is usually highest res)
      url = (thumbs.last['url'] as String? ?? '');
      // Upgrade to high-res using YouTube CDN param replacement
      url = _upgradeThumb(url);
    }
    return PlaylistTrack(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      artistLine: artists,
      thumbnailUrl: url,
      duration: json['duration'] ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
    );
  }

  static String _upgradeThumb(String url) {
    if (url.isEmpty) return url;
    return url
        .replaceAll(RegExp(r'=w\d+-h\d+[^ ]*$'), '=w544-h544-l90-rj')
        .replaceAll(RegExp(r'=s\d+[^ ]*$'), '=w544-h544-l90-rj');
  }

  factory PlaylistTrack.fromCacheJson(Map<String, dynamic> json) =>
      PlaylistTrack(
        videoId: json['videoId'] ?? '',
        title: json['title'] ?? '',
        artistLine: json['artistLine'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        duration: json['duration'] ?? '',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artistLine': artistLine,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'durationSeconds': durationSeconds,
      };
}

class PlaylistDetail {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String authorName;
  final String year;
  final String totalDuration;
  final int trackCount;
  final List<PlaylistTrack> tracks;

  const PlaylistDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.authorName,
    required this.year,
    required this.totalDuration,
    required this.trackCount,
    required this.tracks,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final thumbs = json['thumbnails'] as List? ?? [];
    final url = thumbs.length > 2
        ? thumbs[2]['url'] as String
        : thumbs.length > 1
            ? thumbs[1]['url'] as String
            : thumbs.isNotEmpty
                ? thumbs[0]['url'] as String
                : '';
    final author = json['author'] as Map? ?? {};
    return PlaylistDetail(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: url,
      authorName: author['name']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      totalDuration: json['duration']?.toString() ?? '',
      trackCount: json['trackCount'] as int? ?? 0,
      tracks: (json['tracks'] as List? ?? [])
          .map((t) => PlaylistTrack.fromJson(Map<String, dynamic>.from(t)))
          .where((t) => t.videoId.isNotEmpty)
          .toList(),
    );
  }

  factory PlaylistDetail.fromCacheJson(Map<String, dynamic> json) =>
      PlaylistDetail(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        authorName: json['authorName'] ?? '',
        year: json['year'] ?? '',
        totalDuration: json['totalDuration'] ?? '',
        trackCount: json['trackCount'] as int? ?? 0,
        tracks: (json['tracks'] as List? ?? [])
            .map((t) => PlaylistTrack.fromCacheJson(Map<String, dynamic>.from(t)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'authorName': authorName,
        'year': year,
        'totalDuration': totalDuration,
        'trackCount': trackCount,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

class PlaylistService {
  static const _base = 'https://saragama-render.onrender.com';

  // ── Persistent Hive cache via CacheService ────────────────────────────────
  //
  // Strategy: stale-while-revalidate.
  //   1. If fresh cache exists (< 24hr) → return instantly, no network call.
  //   2. If stale cache exists → return stale data instantly,
  //      then fetch fresh data in background and update cache.
  //   3. If no cache → fetch, cache, and return.

  static Future<PlaylistDetail?> getPlaylist(String playlistId) async {
    // 1. Fresh cache hit — serve instantly
    final freshJson = CacheService.getFreshPlaylist(playlistId);
    if (freshJson != null) {
      try { return PlaylistDetail.fromCacheJson(freshJson); } catch (_) {}
    }

    // 2. Stale cache exists — return stale, refresh in background
    final staleJson = CacheService.getAnyPlaylist(playlistId);
    if (staleJson != null) {
      PlaylistDetail? stale;
      try { stale = PlaylistDetail.fromCacheJson(staleJson); } catch (_) {}
      if (stale != null) {
        // Fire background refresh without awaiting
        _fetchAndCache(playlistId).ignore();
        return stale;
      }
    }

    // 3. No cache — fetch now
    return _fetchAndCache(playlistId);
  }

  static Future<PlaylistDetail?> _fetchAndCache(String playlistId) async {
    try {
      final uri = Uri.parse('$_base/playlist')
          .replace(queryParameters: {'playid': playlistId});
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is List) return null;
        final detail = PlaylistDetail.fromJson(Map<String, dynamic>.from(body));
        CacheService.savePlaylist(playlistId, detail.toJson());
        return detail;
      }
    } catch (_) {}
    return null;
  }

  /// Force-refresh a playlist, clearing its cache first.
  static Future<PlaylistDetail?> refreshPlaylist(String playlistId) {
    CacheService.clearPlaylist(playlistId);
    return _fetchAndCache(playlistId);
  }
}