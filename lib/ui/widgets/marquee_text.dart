// ui/widgets/marquee_text.dart
//
// Minimal dependency-free marquee. Renders [text] in a single line; if it
// overflows the available width it gently scrolls end-to-end on a loop with
// a pause at each side. Falls back to a static, ellipsised line when the text
// fits — so short titles don't move.

import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity; // logical px per second
  final Duration pause;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 28,
    this.pause = const Duration(seconds: 2),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _scroll = ScrollController();
  bool _running = false;

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      // New song → reset to the start and re-evaluate.
      _running = false;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _maybeStart() async {
    if (_running || !mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return; // text fits — stay static
    _running = true;
    while (mounted && _scroll.hasClients) {
      final extent = _scroll.position.maxScrollExtent;
      if (extent <= 0) break;
      await Future.delayed(widget.pause);
      if (!mounted || !_scroll.hasClients) break;
      await _scroll.animateTo(extent,
          duration: Duration(milliseconds: (extent / widget.velocity * 1000).round()),
          curve: Curves.linear);
      if (!mounted || !_scroll.hasClients) break;
      await Future.delayed(widget.pause);
      if (!mounted || !_scroll.hasClients) break;
      await _scroll.animateTo(0,
          duration: Duration(milliseconds: (extent / widget.velocity * 1000).round()),
          curve: Curves.linear);
    }
    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
