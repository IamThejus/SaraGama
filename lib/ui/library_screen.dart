// ui/library_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/library_service.dart';
import 'app_theme.dart';
import 'local_playlist_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryTrack>   _liked     = [];
  List<LocalPlaylist>  _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        _liked     = LibraryService.getLiked();
        _playlists = LibraryService.getPlaylists();
      });

  void _openLiked() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const LocalPlaylistScreen(title: 'Liked Songs', isLiked: true),
    ));
    _load();
  }

  void _openPlaylist(LocalPlaylist pl) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => LocalPlaylistScreen(title: pl.name, playlistId: pl.id),
    ));
    _load();
  }

  // ── Create playlist sheet ──────────────────────────────────────────────────

  void _createPlaylist() {
    String name = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 16, left: 20, right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('New Playlist', style: AppText.title(size: 16)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => name = v,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: AppText.subtitle(size: 15),
              filled: true, fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'CREATE',
              icon: Icons.add_rounded,
              onTap: () {
                if (name.trim().isEmpty) return;
                LibraryService.createPlaylist(name.trim());
                Navigator.pop(context);
                _load();
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Delete playlist sheet ──────────────────────────────────────────────────

  void _showPlaylistOptions(LocalPlaylist pl) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          // Playlist preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: pl.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: pl.thumbnailUrl,
                        width: 48, height: 48, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 48))
                    : const ThumbPlaceholder(size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pl.name, style: AppText.title(size: 14)),
                    const SizedBox(height: 2),
                    Text('${pl.tracks.length} songs', style: AppText.subtitle()),
                  ])),
            ]),
          ),
          Divider(color: AppColors.border, height: 24),
          ListTile(
            leading: Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 20),
            title: Text('Rename', style: AppText.title(size: 14)),
            onTap: () { Navigator.pop(context); _renamePlaylist(pl); },
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: AppColors.accent, size: 20),
            title: Text('Delete playlist',
                style: AppText.title(size: 14, color: AppColors.accent)),
            onTap: () {
              HapticFeedback.mediumImpact();
              LibraryService.deletePlaylist(pl.id);
              Navigator.pop(context);
              _load();
            },
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ]),
      ),
    );
  }

  void _renamePlaylist(LocalPlaylist pl) {
    String name = pl.name;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 16, left: 20, right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('Rename Playlist', style: AppText.title(size: 16)),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            controller: TextEditingController(text: pl.name),
            onChanged: (v) => name = v,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: AppText.subtitle(size: 15),
              filled: true, fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'SAVE',
              onTap: () {
                if (name.trim().isEmpty) return;
                LibraryService.renamePlaylist(pl.id, name.trim());
                Navigator.pop(context);
                _load();
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Text('Library', style: AppText.heading()),
        ),

        // ── Liked Songs card ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: _openLiked,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withOpacity(0.18),
                    AppColors.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _liked.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                              imageUrl: _liked.first.thumbnail,
                              width: 56, height: 56, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.favorite_rounded,
                                  color: AppColors.accent, size: 28)))
                      : const Icon(Icons.favorite_rounded,
                          color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Liked Songs', style: AppText.title(size: 15)),
                      const SizedBox(height: 3),
                      Text(
                        _liked.isEmpty
                            ? 'No liked songs yet'
                            : '${_liked.length} songs',
                        style: AppText.subtitle(),
                      ),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 22),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Playlists header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Text('PLAYLISTS', style: AppText.label()),
            const Spacer(),
            GestureDetector(
              onTap: _createPlaylist,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text('NEW', style: AppText.label(color: AppColors.accent)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Playlist list ────────────────────────────────────────────────────
        if (_playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                Icon(Icons.library_music_outlined,
                    size: 40, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No playlists yet', style: AppText.title(size: 14)),
                const SizedBox(height: 6),
                Text('Tap NEW to create your first one',
                    style: AppText.subtitle(), textAlign: TextAlign.center),
              ]),
            ),
          )
        else
          ..._playlists.map((pl) => _playlistTile(pl)),
      ],
    );
  }

  Widget _playlistTile(LocalPlaylist pl) {
    return GestureDetector(
      onTap: () => _openPlaylist(pl),
      onLongPress: () => _showPlaylistOptions(pl),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: pl.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: pl.thumbnailUrl,
                    width: 54, height: 54, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 54, radius: 10))
                : const ThumbPlaceholder(size: 54, radius: 10),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pl.name,
                    style: AppText.title(size: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${pl.tracks.length} songs', style: AppText.subtitle()),
              ])),
          GestureDetector(
            onTap: () => _showPlaylistOptions(pl),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}