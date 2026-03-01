// services/playlist_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    // prefer highest res thumbnail (index 2 = 1200px, else 1 = 576px, else 0)
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
}

class PlaylistService {
  static const _base = 'https://saragama-render.onrender.com';

  // ── Session-level in-memory cache ─────────────────────────────────────────
  // Cleared when app restarts. Prevents re-fetching the same playlist
  // every time the user opens it during the same session.
  static final Map<String, PlaylistDetail> _cache = {};

  static Future<PlaylistDetail?> getPlaylist(String playlistId) async {
    // Return cached version instantly if available
    if (_cache.containsKey(playlistId)) return _cache[playlistId];

    try {
      final uri = Uri.parse('$_base/playlist')
          .replace(queryParameters: {'playid': playlistId});
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is List) return null; // API returns [] on error
        final detail = PlaylistDetail.fromJson(Map<String, dynamic>.from(body));
        _cache[playlistId] = detail; // store in cache
        return detail;
      }
    } catch (_) {}
    return null;
  }

  /// Force-refresh a playlist, bypassing the cache.
  static Future<PlaylistDetail?> refreshPlaylist(String playlistId) {
    _cache.remove(playlistId);
    return getPlaylist(playlistId);
  }
}