import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double containerWidth;
  final Duration duration;

  const MarqueeText({
    super.key,
    required this.text,
    required this.containerWidth,
    this.style,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingNeeded = false;
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTextWidth();
    });
  }

  void _calculateTextWidth() {
    final textToMeasure = widget.text;

    final whitespaceCount = ' '.allMatches(textToMeasure).length;

    final additionalWidthForWhitespace = whitespaceCount * 10.0;

    final textPainter = TextPainter(
      text: TextSpan(text: textToMeasure, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = textPainter.size.width + additionalWidthForWhitespace;
    _isScrollingNeeded = _textWidth > widget.containerWidth;

    if (_isScrollingNeeded) {
      _startScrolling();
    }
  }

  void _startScrolling() {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      while (mounted) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.duration,
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          await _scrollController.animateTo(
            0,
            duration: widget.duration,
            curve: Curves.linear,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.containerWidth + 50,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
