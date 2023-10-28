import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart';

class Scrollbar95 extends StatefulWidget {
  final Widget child;
  final double scrollAmount;
  final double minThumbHeight;
  final double scrollbarThickness;

  const Scrollbar95({
    super.key,
    required this.child,
    this.scrollAmount = 0.05,
    this.scrollbarThickness = 30,
    this.minThumbHeight = 10,
  }) : assert(scrollAmount > 0 && scrollAmount <= 1);

  @override
  State<Scrollbar95> createState() => _Scrollbar95State();
}

class _Scrollbar95State extends State<Scrollbar95> {
  final ValueNotifier<double> _relativeTrackPosition =
      ValueNotifier<double>(0.0);
  final Duration _scrollingInterval = const Duration(milliseconds: 200);
  final GlobalKey _trackKey = GlobalKey();
  ScrollController? _controller;
  Timer? _continuousScrollingTimer;
  double _thumbExtent = 30;

  @override
  Widget build(BuildContext context) {
    _findControllerAndListen(context);
    return Row(
      children: [
        Expanded(child: widget.child),
        SizedBox(
          height: double.infinity,
          width: widget.scrollbarThickness,
          child: Column(
            children: [
              GestureDetector(
                onTap: _scrollUpOnce,
                onLongPress: () => _startContinuousScrolling(false),
                onLongPressEnd: (_) => _stopContinuousScrolling(),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Elevation95(
                    child: Transform.scale(
                      scale: 1.5,
                      child: const Icon(Icons.arrow_drop_up),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _CheckeredBackgroundPainter(
                    color1: Colors.white,
                    color2: const Color(0xFFC0C0C0),
                    squareSize: 2,
                  ),
                  isComplex: false,
                  willChange: false,
                  child: RepaintBoundary(
                    key: _trackKey,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _relativeTrackPosition,
                          builder: (context, value, child) {
                            return Align(
                              alignment: Alignment(0, value),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onVerticalDragUpdate: _dragUpdate,
                            child: Elevation95(
                              child: SizedBox(
                                height: _thumbExtent,
                                width: widget.scrollbarThickness,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: _scrollDownOnce,
                  onLongPress: () => _startContinuousScrolling(true),
                  onLongPressEnd: (_) => _stopContinuousScrolling(),
                  child: Elevation95(
                    child: Transform.scale(
                      scale: 1.5,
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _positionListener() {
    // Bring the scroll position into the range of -1 to 1
    _relativeTrackPosition.value = clampDouble(
      ((_controller!.offset / _controller!.position.maxScrollExtent) * 2) - 1,
      -1,
      1,
    );
  }

  void _scrollDownOnce() {
    double total = _controller!.position.maxScrollExtent;
    double nextPosition =
        min(_controller!.offset + (total * widget.scrollAmount), total);

    _controller!.animateTo(
      nextPosition,
      duration: _scrollingInterval,
      curve: Curves.easeInOut,
    );
  }

  void _scrollUpOnce() {
    double total = _controller!.position.maxScrollExtent;
    double nextPosition =
        max(0, _controller!.offset - (total * widget.scrollAmount));

    _controller!.animateTo(
      nextPosition,
      duration: _scrollingInterval,
      curve: Curves.easeInOut,
    );
  }

  void _startContinuousScrolling(bool scrollDown) {
    _stopContinuousScrolling();
    if (scrollDown) {
      _continuousScrollingTimer = Timer.periodic(
        _scrollingInterval,
        (timer) => _scrollDownOnce(),
      );
    } else {
      _continuousScrollingTimer = Timer.periodic(
        _scrollingInterval,
        (timer) => _scrollUpOnce(),
      );
    }
  }

  void _stopContinuousScrolling() {
    _continuousScrollingTimer?.cancel();
    _continuousScrollingTimer = null;
  }

  _dragUpdate(DragUpdateDetails details) {
    RenderBox trackRenderBox =
        _trackKey.currentContext!.findRenderObject() as RenderBox;
    double trackHeight = trackRenderBox.size.height;
    double trackTop = trackRenderBox.localToGlobal(Offset.zero).dy;
    double thumbPosition = details.globalPosition.dy - trackTop;

    double thumbPositionNormalised = thumbPosition / trackHeight;

    double nextPosition =
        thumbPositionNormalised * (_controller!.position.maxScrollExtent);

    nextPosition =
        clampDouble(nextPosition, 0, _controller!.position.extentTotal);

    _controller!.jumpTo(nextPosition);
  }

  void _findControllerAndListen(BuildContext context) {
    if (_controller != null) return;

    // Find the scroll controller and attach the listener.
    if (widget.child is ScrollView &&
        (widget.child as ScrollView).controller != null) {
      _controller = (widget.child as ScrollView).controller;
    } else if (widget.child is SingleChildScrollView &&
        (widget.child as SingleChildScrollView).controller != null) {
      _controller = (widget.child as SingleChildScrollView).controller;
    } else {
      _controller = PrimaryScrollController.of(context);
    }

    _controller?.addListener(_positionListener);

    // Call the listener once to set the initial position.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _positionListener();
      _getThumbExtent();
    });
  }

  void _getThumbExtent() {
    ScrollMetrics scrollMetrics = _controller!.position;

    final double totalContentExtent = scrollMetrics.extentTotal;

    // Thumb extent reflects fraction of content visible, as long as this
    final double fractionVisible = clampDouble(
      (scrollMetrics.extentInside) / totalContentExtent,
      0.0,
      1.0,
    );

    final double traversableTrackExtent =
        scrollMetrics.viewportDimension - (2 * widget.scrollbarThickness);

    final double thumbExtent = max(
      min(
        traversableTrackExtent * fractionVisible,
        traversableTrackExtent,
      ),
      traversableTrackExtent * fractionVisible,
    );

    final double fractionOverscrolled =
        1.0 - scrollMetrics.extentInside / scrollMetrics.viewportDimension;

    final double minLength = widget.minThumbHeight;

    final double safeMinLength = min(minLength, traversableTrackExtent);
    final double newMinLength =
        (scrollMetrics.extentBefore > 0 && scrollMetrics.extentAfter > 0)
            ? safeMinLength
            : safeMinLength *
                (1.0 - clampDouble(fractionOverscrolled, 0.0, 0.2) / 0.2);

    _thumbExtent =
        clampDouble(thumbExtent, newMinLength, traversableTrackExtent);
  }
}

class _CheckeredBackgroundPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double squareSize;

  _CheckeredBackgroundPainter(
      {required this.color1, required this.color2, required this.squareSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    // Draw the checkered pattern
    for (double i = 0; i < size.width; i += squareSize) {
      for (double j = 0; j < size.height; j += squareSize) {
        if ((i / squareSize).floor() % 2 == 0) {
          // Even column
          paint.color = (j / squareSize).floor() % 2 == 0 ? color1 : color2;
        } else {
          // Odd column
          paint.color = (j / squareSize).floor() % 2 == 0 ? color2 : color1;
        }

        canvas.drawRect(
            Rect.fromPoints(
                Offset(i, j), Offset(i + squareSize, j + squareSize)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}