// ui/library_screen.dart
// Library tab: Liked Songs card + custom playlists grid.
// Fully reactive — uses StatefulWidget and reloads on return from sub-screens.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/library_service.dart';
import 'local_playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryTrack> _liked = [];
  List<LocalPlaylist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _liked = LibraryService.getLiked();
      _playlists = LibraryService.getPlaylists();
    });
  }

  void _openLiked() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocalPlaylistScreen(
          title: 'Liked Songs',
          isLiked: true,
        ),
      ),
    );
    _load(); // refresh on return
  }

  void _openPlaylist(LocalPlaylist pl) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocalPlaylistScreen(
          title: pl.name,
          playlistId: pl.id,
        ),
      ),
    );
    _load();
  }

  void _createPlaylist() {
    String name = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 16,
            left: 20,
            right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('New Playlist',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => name = v,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade600, fontSize: 15),
              filled: true,
              fillColor: const Color(0xFF1C1C1C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                if (name.trim().isEmpty) return;
                LibraryService.createPlaylist(name.trim());
                Navigator.pop(context);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('CREATE',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.5)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _deletePlaylist(LocalPlaylist pl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('Delete "${pl.name}"?',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('This cannot be undone.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: Text('CANCEL',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  LibraryService.deletePlaylist(pl.id);
                  Navigator.pop(context);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: Text('DELETE',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Text('LIBRARY',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 2.5)),
            const Spacer(),
            GestureDetector(
              onTap: _createPlaylist,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded,
                      color: Colors.grey.shade400, size: 16),
                  const SizedBox(width: 4),
                  Text('NEW PLAYLIST',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Liked Songs card ──────────────────────────────────────────────
        GestureDetector(
          onTap: _openLiked,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0808),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF3B30).withOpacity(0.2)),
            ),
            child: Row(children: [
              // Collage or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _liked.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _liked.first.thumbnail,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _likedPlaceholder(),
                      )
                    : _likedPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Liked Songs',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('${_liked.length} songs',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ]),
              ),
              Icon(Icons.favorite_rounded,
                  color: const Color(0xFFFF3B30), size: 20),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade700, size: 22),
            ]),
          ),
        ),

        // ── Playlists ─────────────────────────────────────────────────────
        if (_playlists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text('PLAYLISTS',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 2.5)),
          ),
          ..._playlists.map((pl) => _playlistTile(pl)),
        ],

        if (_playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Center(
              child: Text('No playlists yet — tap + NEW PLAYLIST',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade700)),
            ),
          ),
      ],
    );
  }

  Widget _likedPlaceholder() => Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A0A0A),
        child: const Icon(Icons.favorite_rounded,
            color: Color(0xFFFF3B30), size: 28),
      );

  Widget _playlistTile(LocalPlaylist pl) {
    return GestureDetector(
      onTap: () => _openPlaylist(pl),
      onLongPress: () => _deletePlaylist(pl),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: Colors.grey.shade900, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: pl.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: pl.thumbnailUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _plPlaceholder(),
                  )
                : _plPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pl.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${pl.tracks.length} songs',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey.shade600)),
                ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade700, size: 22),
        ]),
      ),
    );
  }

  Widget _plPlaceholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFF1C1C1C),
        child: Icon(Icons.queue_music_rounded,
            size: 26, color: Colors.grey.shade700),
      );
}