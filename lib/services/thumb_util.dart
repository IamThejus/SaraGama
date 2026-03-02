// services/thumb_util.dart
// Global thumbnail URL quality manager.
// YouTube CDN URLs end with size params like =w60-h60-l90-rj
// We swap them based on where the thumbnail is displayed.

enum ThumbnailSize {
  small,    // 48px  — notification tile, queue list
  medium,   // 226px — search list, playlist track list
  large,    // 544px — now playing screen, playlist header
}

class ThumbUtil {
  static String get(String url, ThumbnailSize size) {
    if (url.isEmpty) return url;
    final params = _params(size);
    // Replace any existing size params at end of URL
    final upgraded = url
        .replaceAll(RegExp(r'=w\d+-h\d+[^&\s]*$'), '=$params')
        .replaceAll(RegExp(r'=s\d+[^&\s]*$'), '=$params');
    // If nothing was replaced (no params found), append them
    if (upgraded == url && !url.contains('=$params')) {
      return '$url=$params';
    }
    return upgraded;
  }

  static String _params(ThumbnailSize size) {
    switch (size) {
      case ThumbnailSize.small:
        return 'w48-h48-l90-rj';
      case ThumbnailSize.medium:
        return 'w226-h226-l90-rj';
      case ThumbnailSize.large:
        return 'w544-h544-l90-rj';
    }
  }
}