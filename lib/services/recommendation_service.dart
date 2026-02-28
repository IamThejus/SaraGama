// services/recommendation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RecommendedTrack {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final String duration;

  const RecommendedTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.duration,
  });

  Duration get durationValue {
    try {
      final parts = duration.split(':').map(int.parse).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } catch (_) {}
    return Duration.zero;
  }

  factory RecommendedTrack.fromJson(Map<String, dynamic> json) => RecommendedTrack(
        videoId: json['video_id'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        duration: json['duration'] ?? '',
      );
}

class RecommendationService {
  static const _base = 'https://saragama-render.onrender.com';

  static Future<List<RecommendedTrack>> getRecommendations(String videoId) async {
    if (videoId.isEmpty) return [];
    try {
      final uri = Uri.parse('$_base/recommendation')
          .replace(queryParameters: {'video_id': videoId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data
            .map((e) => RecommendedTrack.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.videoId.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}