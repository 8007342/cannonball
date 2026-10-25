import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'departure_timeline.dart';

/// A directed 2.5D departure. Its clock is independent of the race clock.
/// Whole painted views are exchanged behind foreground occlusion, rather than
/// pretending a single painting supports an arbitrary camera orbit.
class ProofGarage extends StatefulWidget {
  const ProofGarage({
    super.key,
    required this.departing,
    required this.ready,
    required this.reducedMotion,
    required this.onTakeKeys,
    required this.onComplete,
    required this.onShot,
    required this.onSound,
    required this.muted,
    this.artwork = true,
  });
  final bool departing, ready, reducedMotion, muted, artwork;
  final VoidCallback onTakeKeys, onComplete, onSound;
  final ValueChanged<String> onShot;

  @override
  State<ProofGarage> createState() => _ProofGarageState();
}

class _ProofGarageState extends State<ProofGarage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  String _shot = 'keys';
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.reducedMotion
            ? DepartureTimeline.reducedDurationMilliseconds
            : DepartureTimeline.durationMilliseconds,
      ),
    )..addListener(_advance);
    if (widget.departing) _clock.forward();
  }

  @override
  void didUpdateWidget(ProofGarage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.departing && !oldWidget.departing) {
      _completed = false;
      _clock.forward(from: 0);
    }
    if (!widget.departing && oldWidget.departing) _clock.reset();
  }

  void _advance() {
    final t = _clock.value;
    final next = DepartureTimeline.shot(t);
    if (next != _shot) {
      _shot = next;
      widget.onShot(next);
    }
    if (_clock.isCompleted && !_completed) {
      _completed = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Widget _picture(String path, {Alignment alignment = Alignment.center}) =>
      widget.artwork
      ? Image.asset(
          path,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xff302822)),
        )
      : const ColoredBox(color: Color(0xff302822));

  Widget _cell(
    int index, {
    required double extent,
    String path = 'assets/proof-next/entry-atlas.png',
    double visibleFraction = 1,
  }) => SizedBox.square(
    dimension: extent,
    child: widget.artwork
        ? ClipRect(
            clipper: _AtlasGutterClip(visibleFraction),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: extent * 3,
              maxHeight: extent * 2,
              child: Transform.translate(
                offset: Offset(-(index % 3) * extent, -(index ~/ 3) * extent),
                child: Image.asset(
                  path,
                  width: extent * 3,
                  height: extent * 2,
                  fit:
                      BoxFit.fill, // Uniform square cells; never viewport fill.
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          )
        : null,
  );

  Widget _hand(int frame, double extent) =>
      _cell(frame, extent: extent, path: 'assets/milestone/hand-atlas.png');

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final t = _clock.value;
        final w = bounds.maxWidth, h = bounds.maxHeight;
        final moving = widget.departing;
        final pickup = DepartureTimeline.progress(t, 0, .20);
        final pan = DepartureTimeline.smooth(
          DepartureTimeline.progress(t, .20, .40),
        );
        final walk = DepartureTimeline.smooth(
          DepartureTimeline.progress(t, .40, .60),
        );
        final door = DepartureTimeline.progress(t, .60, .70);
        final cabin = DepartureTimeline.smooth(
          DepartureTimeline.progress(t, .70, .82),
        );
        final rear = DepartureTimeline.smooth(
          DepartureTimeline.progress(t, .82, .93),
        );
        final handReach = DepartureTimeline.smooth(
          DepartureTimeline.progress(pickup, 0, .48),
        );
        final withdraw = DepartureTimeline.smooth(
          DepartureTimeline.progress(pickup, .70, 1),
        );
        final sway = widget.reducedMotion
            ? 0.0
            : math.sin(walk * math.pi * 4) * 2.0 * math.sin(walk * math.pi);
        final keyExtent = h * .21;
        final handExtent = h * .44;
        final handLeft =
            w * .43 -
            handExtent * .32 +
            (widget.reducedMotion
                ? 0
                : (1 - handReach) * w * .28 + withdraw * w * .20);
        final handTop =
            h * .36 -
            handExtent * .34 +
            (widget.reducedMotion
                ? 0
                : (1 - handReach) * h * .27 + withdraw * h * .34);
        final showKey = !moving || pickup < .55;
        final exterior = _picture('assets/proof-next/garage-exterior.png');
        final wall = _picture('assets/proof-next/garage-wall.png');
        return Stack(
          fit: StackFit.expand,
          children: [
            // A continuous leftward camera move: the wall retreats right and
            // the existing doorway painting enters from the left. Their dark
            // garage edges meet without a full-screen opaque wipe.
            Opacity(
              opacity: moving ? DepartureTimeline.overlayOpacity(t) : 1,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pan < 1)
                      Transform.translate(
                        offset: Offset(widget.reducedMotion ? 0 : w * pan, 0),
                        child: Opacity(
                          opacity: widget.reducedMotion ? 1 - pan : 1,
                          child: Opacity(opacity: 1 - rear, child: wall),
                        ),
                      ),
                    if (pan > 0)
                      Transform.translate(
                        offset: Offset(
                          widget.reducedMotion
                              ? 0
                              : w * (pan - 1) - walk * w * .045,
                          sway,
                        ),
                        child: Transform.scale(
                          scale: widget.reducedMotion ? 1 : 1 + walk * .19,
                          child: Opacity(
                            opacity: widget.reducedMotion ? pan : 1,
                            child: Opacity(opacity: 1 - rear, child: exterior),
                          ),
                        ),
                      ),
                    if (pan < 1 && showKey)
                      Positioned(
                        left:
                            w * .43 -
                            keyExtent * .5 +
                            (widget.reducedMotion ? 0 : w * pan),
                        top: h * .36 - keyExtent * .10,
                        child: _cell(
                          0,
                          extent: keyExtent,
                          visibleFraction: .90,
                        ),
                      ),
                    if (moving && pickup > 0 && t < .20)
                      Positioned(
                        left: handLeft,
                        top: handTop,
                        child: Opacity(
                          opacity: widget.reducedMotion
                              ? math.sin(pickup * math.pi)
                              : 1,
                          child: _hand(
                            DepartureTimeline.handFrame(pickup),
                            handExtent,
                          ),
                        ),
                      ),
                    if (moving && t >= .60 && t < .74)
                      Positioned(
                        left: w * (.72 - door * .42),
                        top: h * .08,
                        child: Transform.rotate(
                          angle: widget.reducedMotion ? 0 : -door * .10,
                          child: _cell(3, extent: h * 1.10),
                        ),
                      ),
                    if (moving && t >= .70 && t < .85)
                      Opacity(
                        opacity: cabin,
                        child: Transform.scale(
                          scale: widget.reducedMotion
                              ? 1
                              : 1.025 - cabin * .025,
                          child: _picture(
                            'assets/milestone/cabin.png',
                            alignment: const Alignment(0, -.15),
                          ),
                        ),
                      ),
                    if (moving && t >= .82)
                      Opacity(
                        opacity: 1 - rear,
                        child: _picture('assets/milestone/cabin.png'),
                      ),
                    if (moving && t >= .82)
                      // The live game is underneath this overlay. A rear sprite
                      // settles toward its chase-camera position during the cut.
                      Opacity(
                        opacity: rear,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: const Color(0xff1d2b34)
                                  .withValues(alpha: (1 - rear) * .45),
                            ),
                            Positioned(
                              left: w * .5 - h * (.43 - rear * .08) * .5,
                              top:
                                  h * .80 -
                                  h * (.43 - rear * .08) * (449 / 512),
                              child: _cell(
                                0,
                                extent: h * (.43 - rear * .08),
                                path: 'assets/proof-next/s2000-atlas.png',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!moving)
              Positioned(
                left: w * .29,
                top: h * .18,
                width: w * .42,
                height: h * .64,
                child: Semantics(
                  button: true,
                  label: 'Take the S2000 keys',
                  child: GestureDetector(
                    key: const ValueKey('take-keys'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.ready ? widget.onTakeKeys : null,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _button(
                        widget.muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        widget.muted ? 'Enable sound' : 'Mute sound',
                        widget.onSound,
                      ),
                      if (moving)
                        _button(
                          Icons.fast_forward_rounded,
                          'Skip departure',
                          widget.onComplete,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!moving)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: IconButton(
                      tooltip: widget.ready
                          ? 'Take the S2000 keys'
                          : 'Preparing the road',
                      onPressed: widget.ready ? widget.onTakeKeys : null,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xaa211c17),
                      ),
                      icon: Icon(
                        widget.ready
                            ? Icons.key_rounded
                            : Icons.hourglass_empty,
                        color: const Color(0xffffdf9c),
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _button(IconData icon, String label, VoidCallback onTap) => IconButton(
    tooltip: label,
    style: IconButton.styleFrom(backgroundColor: const Color(0xaa211c17)),
    onPressed: onTap,
    icon: Icon(icon, color: const Color(0xffffdf9c)),
  );
}

class _AtlasGutterClip extends CustomClipper<Rect> {
  const _AtlasGutterClip(this.visibleFraction);
  final double visibleFraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * visibleFraction);

  @override
  bool shouldReclip(_AtlasGutterClip oldClipper) =>
      visibleFraction != oldClipper.visibleFraction;
}
