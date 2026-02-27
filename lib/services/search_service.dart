// services/search_service.dart
// Calls the Saragama autocomplete API and returns typed SearchResult objects.

import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchResult {
  final String title;
  final String videoId;
  final List<String> artists;
  final String thumbnail;

  const SearchResult({
    required this.title,
    required this.videoId,
    required this.artists,
    required this.thumbnail,
  });

  String get artistLine => artists.join(', ');

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] ?? '',
        videoId: json['video_url'] ?? '',
        artists: List<String>.from(json['artist'] ?? []),
        thumbnail: json['thumbnail'] ?? '',
      );
}

class SearchService {
  static const _base = 'https://saragama-render.onrender.com';

  static Future<List<SearchResult>> autocomplete(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri =
          Uri.parse('$_base/autocomplete').replace(queryParameters: {'q': query});
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