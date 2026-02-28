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
    final url = thumbs.isNotEmpty ? thumbs[0]['url'] as String : '';
    return PlaylistTrack(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      artistLine: artists,
      thumbnailUrl: url,
      duration: json['duration'] ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
    );
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

  static Future<PlaylistDetail?> getPlaylist(String playlistId) async {
    try {
      final uri = Uri.parse('$_base/playlist')
          .replace(queryParameters: {'playid': playlistId});
      final res =
          await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        // API returns [] on error
        if (body is List) return null;
        return PlaylistDetail.fromJson(Map<String, dynamic>.from(body));
      }
    } catch (_) {}
    return null;
  }
}