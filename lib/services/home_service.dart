// services/home_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrendingPlaylist {
  final String title;
  final String playlistId;
  final String thumbnailUrl;

  const TrendingPlaylist({
    required this.title,
    required this.playlistId,
    required this.thumbnailUrl,
  });

  factory TrendingPlaylist.fromJson(Map<String, dynamic> json) {
    final thumbs = json['thumbnails'] as List? ?? [];
    // index 1 = 576px (high res), index 0 = 192px fallback
    final url = thumbs.length > 1
        ? thumbs[1]['url'] as String
        : thumbs.isNotEmpty
            ? thumbs[0]['url'] as String
            : '';
    return TrendingPlaylist(
      title: json['title'] ?? '',
      playlistId: json['playlistId'] ?? '',
      thumbnailUrl: url,
    );
  }
}

class TrendingArtist {
  final String title;
  final String browseId;
  final String subscribers;
  final String thumbnailUrl;
  final String rank;
  final String trend; // "up" | "down" | "neutral"

  const TrendingArtist({
    required this.title,
    required this.browseId,
    required this.subscribers,
    required this.thumbnailUrl,
    required this.rank,
    required this.trend,
  });

  factory TrendingArtist.fromJson(Map<String, dynamic> json) {
    final thumbs = json['thumbnails'] as List? ?? [];
    final url = thumbs.length > 1
        ? thumbs[1]['url'] as String
        : thumbs.isNotEmpty
            ? thumbs[0]['url'] as String
            : '';
    return TrendingArtist(
      title: json['title'] ?? '',
      browseId: json['browseId'] ?? '',
      subscribers: json['subscribers']?.toString() ?? '',
      thumbnailUrl: url,
      rank: json['rank']?.toString() ?? '',
      trend: json['trend']?.toString() ?? 'neutral',
    );
  }
}

class HomeData {
  final List<TrendingPlaylist> daily;
  final List<TrendingPlaylist> weekly;
  final List<TrendingArtist> artists;

  const HomeData({
    required this.daily,
    required this.weekly,
    required this.artists,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
        daily: (json['daily'] as List? ?? [])
            .map((e) =>
                TrendingPlaylist.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        weekly: (json['weekly'] as List? ?? [])
            .map((e) =>
                TrendingPlaylist.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        artists: (json['artists'] as List? ?? [])
            .map((e) =>
                TrendingArtist.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class HomeService {
  static const _base = 'https://saragama-render.onrender.com';

  static Future<HomeData?> getUpdates() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/getupdates'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return HomeData.fromJson(
            Map<String, dynamic>.from(json.decode(res.body)));
      }
    } catch (_) {}
    return null;
  }
}