import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/search_controller.dart';
import '../services/library_service.dart';
import '../services/search_service.dart';
import 'widgets/mini_player_bar.dart';

class AddToLocalPlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String title;

  const AddToLocalPlaylistScreen({
    super.key,
    required this.playlistId,
    required this.title,
  });

  @override
  State<AddToLocalPlaylistScreen> createState() =>
      _AddToLocalPlaylistScreenState();
}

class _AddToLocalPlaylistScreenState extends State<AddToLocalPlaylistScreen> {
  late final SongSearchController _sc;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _addedIds = <String>{}.obs;

  @override
  void initState() {
    super.initState();
    _sc = SongSearchController();
    // Prefocus keyboard shortly after push
    Future.delayed(
      const Duration(milliseconds: 120),
      () => _searchFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _sc.onClose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onAdd(SearchResult r) {
    if (r.videoId.isEmpty) return;
    if (_addedIds.contains(r.videoId)) return;

    final track = LibraryTrack(
      videoId: r.videoId,
      title: r.title,
      artist: r.artistLine,
      thumbnail: r.thumbnail,
      duration: r.duration,
    );
    LibraryService.addTrackToPlaylist(widget.playlistId, track);
    _addedIds.add(r.videoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                Expanded(child: _body()),
                const SizedBox(height: 86),
              ],
            ),
            const MiniPlayerBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF160A0A), Colors.black],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 8),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 22),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ADD SONGS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1F1F1F)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _sc.onQueryChanged,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search songs to add',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade600, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Obx(() => _sc.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : _sc.query.value.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _sc.clear();
                            },
                            child: const Icon(Icons.close_rounded,
                                color: Colors.grey, size: 18),
                          )
                        : const SizedBox(width: 18)),
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final results = _sc.results;
            final loading = _sc.isLoading.value;
            final q = _sc.query.value;

            if (q.isEmpty) {
              return Center(
                child: Text(
                  'Search to add songs\ninto this playlist',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              );
            }

            if (loading && results.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF3B30), strokeWidth: 2),
              );
            }

            if (!loading && results.isEmpty) {
              return Center(
                child: Text(
                  'No results for "$q"',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              itemCount: results.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.grey.shade900,
                height: 1,
                indent: 76,
              ),
              itemBuilder: (_, i) => _resultTile(results[i]),
            );
          }),
        ),
      ],
    );
  }

  Widget _resultTile(SearchResult r) {
    return Obx(() {
      final added = _addedIds.contains(r.videoId);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: r.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: r.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumb(),
                    )
                  : _thumb(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.artistLine,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (r.duration.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                r.duration,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(width: 6),
            GestureDetector(
              onTap: added ? null : () => _onAdd(r),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: added
                      ? const Color(0xFF0E1A12)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: added
                        ? const Color(0xFF1E3A2A)
                        : const Color(0xFF262626),
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      added ? Icons.check_rounded : Icons.add_rounded,
                      key: ValueKey(added),
                      color: added
                          ? const Color(0xFF34C759)
                          : Colors.grey.shade300,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _thumb() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note_rounded,
            size: 20, color: Colors.grey.shade700),
      );
}

