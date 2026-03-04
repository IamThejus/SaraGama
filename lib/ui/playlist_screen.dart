// ui/playlist_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/player_controller.dart';
import '../services/playlist_service.dart';
import 'app_theme.dart';
import 'widgets/mini_player_bar.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String playlistTitle;
  final String thumbnailUrl;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    required this.thumbnailUrl,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final PlayerController _pc = Get.find();

  PlaylistDetail? _detail;
  bool _loading = true;
  bool _error   = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    final data = await PlaylistService.getPlaylist(widget.playlistId);
    if (mounted) setState(() {
      _detail  = data;
      _loading = false;
      _error   = data == null;
    });
  }

  // ── Playback helpers ───────────────────────────────────────────────────────

  Future<void> _playAllFromIndex(int startIndex) async {
    if (_detail == null || _detail!.tracks.isEmpty) return;
    final slice = _detail!.tracks.sublist(
        startIndex.clamp(0, _detail!.tracks.length - 1));
    final first = slice.first;
    await _pc.playVideoId(first.videoId,
        title: first.title, artist: first.artistLine,
        thumbnail: first.thumbnailUrl, duration: first.durationValue);
    for (final t in slice.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artistLine,
          thumbnail: t.thumbnailUrl, duration: t.durationValue);
    }
    _snack('Playing ${slice.length} songs');
  }

  Future<void> _shuffleAll() async {
    if (_detail == null || _detail!.tracks.isEmpty) return;
    final shuffled = [..._detail!.tracks]..shuffle();
    final first = shuffled.first;
    await _pc.playVideoId(first.videoId,
        title: first.title, artist: first.artistLine,
        thumbnail: first.thumbnailUrl, duration: first.durationValue);
    for (final t in shuffled.skip(1)) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artistLine,
          thumbnail: t.thumbnailUrl, duration: t.durationValue);
    }
    _snack('Shuffled ${shuffled.length} songs');
  }

  void _addAllToQueue() {
    if (_detail == null) return;
    for (final t in _detail!.tracks) {
      _pc.addToQueue(t.videoId,
          title: t.title, artist: t.artistLine,
          thumbnail: t.thumbnailUrl, duration: t.durationValue);
    }
    _snack('Added ${_detail!.tracks.length} songs to queue');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: AppText.subtitle()),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.elevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        _loading  ? _loadingView()  :
        _error    ? _errorView()    :
                    _contentView(),
        const MiniPlayerBar(),
      ]),
    );
  }

  Widget _loadingView() => SafeArea(child: Column(children: [
    _appBar(widget.playlistTitle),
    const Expanded(child: Center(
        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))),
  ]));

  Widget _errorView() => SafeArea(child: Column(children: [
    _appBar(widget.playlistTitle),
    Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
      const SizedBox(height: 12),
      Text('Could not load playlist', style: AppText.subtitle()),
      const SizedBox(height: 20),
      SecondaryButton(label: 'RETRY', icon: Icons.refresh_rounded, onTap: _load),
    ]))),
  ]));

  Widget _appBar(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
    child: Row(children: [
      const AppBackButton(),
      const SizedBox(width: 4),
      Expanded(child: Text(title,
          style: AppText.title(size: 16),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _contentView() {
    final d = _detail!;
    return CustomScrollView(slivers: [

      // ── Collapsing header ──────────────────────────────────────────────────
      SliverAppBar(
        backgroundColor: AppColors.bg,
        expandedHeight: 280,
        pinned: true,
        leading: const AppBackButton(),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: Stack(fit: StackFit.expand, children: [
            if (d.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: d.thumbnailUrl, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.surface)),
            Container(decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xDD000000), Colors.black],
                stops: [0.3, 0.72, 1.0],
              ),
            )),
            Positioned(left: 16, right: 16, bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.title,
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (d.authorName.isNotEmpty) ...[
                      Text(d.authorName, style: AppText.subtitle()),
                      Text('  ·  ', style: AppText.caption()),
                    ],
                    Text('${d.trackCount} songs · ${d.totalDuration}',
                        style: AppText.subtitle()),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),

      // ── Action buttons ─────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(child: PrimaryButton(
              label: 'PLAY ALL', icon: Icons.play_arrow_rounded,
              onTap: () => _playAllFromIndex(0),
            )),
            const SizedBox(width: 10),
            Expanded(child: SecondaryButton(
              label: 'SHUFFLE', icon: Icons.shuffle_rounded,
              onTap: _shuffleAll,
            )),
            const SizedBox(width: 10),
            Expanded(child: SecondaryButton(
              label: 'QUEUE', icon: Icons.add_rounded,
              onTap: _addAllToQueue,
              outlined: true,
            )),
          ]),
        ),
      ),

      // ── Description ────────────────────────────────────────────────────────
      if (d.description.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(d.description,
                style: AppText.subtitle(),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),

      // ── Tracks label ───────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('TRACKS', style: AppText.label()),
        ),
      ),

      // ── Track list ─────────────────────────────────────────────────────────
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _trackTile(d.tracks[i], i + 1),
          childCount: d.tracks.length,
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 140)),
    ]);
  }

  // ── Track tile ─────────────────────────────────────────────────────────────

  Widget _trackTile(PlaylistTrack t, int index) {
    return GestureDetector(
      onTap: () => _playAllFromIndex(index - 1),
      onLongPress: () => _trackOptions(t),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 24,
            child: Text('$index', style: AppText.caption(), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.thumbnailUrl, width: 46, height: 46, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 46, radius: 8))
                : const ThumbPlaceholder(size: 46, radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: AppText.title(size: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(t.artistLine, style: AppText.subtitle(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          if (t.duration.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(t.duration, style: AppText.caption()),
          ],
          GestureDetector(
            onTap: () => _trackOptions(t),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  void _trackOptions(PlaylistTrack t) {
    AppHaptics.medium();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: t.thumbnailUrl,
                        width: 48, height: 48, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ThumbPlaceholder(size: 48))
                    : const ThumbPlaceholder(size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: AppText.title(size: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(t.artistLine, style: AppText.subtitle(),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
            ]),
          ),
          Divider(color: AppColors.border, height: 24),
          ListTile(
            leading: Icon(Icons.play_arrow_rounded, color: AppColors.textSecondary, size: 22),
            title: Text('Play from here', style: AppText.title(size: 14)),
            onTap: () {
              AppHaptics.light();
              Navigator.pop(context);
              _playAllFromIndex(_detail!.tracks.indexOf(t));
            },
            dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          ListTile(
            leading: Icon(Icons.add_to_queue_rounded, color: AppColors.textSecondary, size: 22),
            title: Text('Add to queue', style: AppText.title(size: 14)),
            onTap: () {
              AppHaptics.light();
              _pc.addToQueue(t.videoId, title: t.title, artist: t.artistLine,
                  thumbnail: t.thumbnailUrl, duration: t.durationValue);
              Navigator.pop(context);
              _snack('Added to queue');
            },
            dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ]),
      ),
    );
  }
}