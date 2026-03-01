// services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchResult {
  final String title;
  final String videoId;
  final List<String> artists;
  final String thumbnail;
  final String duration;

  const SearchResult({
    required this.title,
    required this.videoId,
    required this.artists,
    required this.thumbnail,
    required this.duration,
  });

  String get artistLine => artists.join(', ');

  Duration get durationValue {
    try {
      final parts = duration.split(':').map(int.parse).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } catch (_) {}
    return Duration.zero;
  }

  /// Upgrades any YouTube thumbnail URL to 544×544 high-res.
  /// YouTube CDN URLs end with size params like =w60-h60 or =w226-h226-l90-rj
  /// We replace them with =w544-h544-l90-rj for consistency with recommendations.
  static String _upgradeThumb(String url) {
    if (url.isEmpty) return url;
    return url
        .replaceAll(RegExp(r'=w\d+-h\d+[^ ]*$'), '=w544-h544-l90-rj')
        .replaceAll(RegExp(r'=s\d+[^ ]*$'), '=w544-h544-l90-rj');
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] ?? '',
        videoId: json['video_url'] ?? '',
        artists: List<String>.from(json['artist'] ?? []),
        thumbnail: _upgradeThumb(json['thumbnail'] ?? ''),
        duration: json['duration'] ?? '',
      );
}

class SearchService {
  static const _base = 'https://saragama-render.onrender.com';

  static Future<List<SearchResult>> autocomplete(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_base/autocomplete')
          .replace(queryParameters: {'q': query});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        return data
            .map((e) => SearchResult.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}