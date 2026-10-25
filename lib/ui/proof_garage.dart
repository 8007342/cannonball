import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.reducedMotion ? 1800 : 7600),
    )..addListener(_advance);
    if (widget.departing) _clock.forward();
  }

  @override
  void didUpdateWidget(ProofGarage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.departing && !oldWidget.departing) _clock.forward(from: 0);
    if (!widget.departing && oldWidget.departing) _clock.reset();
  }

  void _advance() {
    final t = _clock.value;
    final next = t < .12
        ? 'pickup'
        : t < .36
        ? 'reveal'
        : t < .68
        ? 'walk'
        : t < .83
        ? 'door'
        : t < .94
        ? 'cabin'
        : 'launch';
    if (next != _shot) {
      _shot = next;
      widget.onShot(next);
    }
    if (_clock.isCompleted) widget.onComplete();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Widget _picture(String name) => widget.artwork
      ? Image.asset(
          'assets/proof-next/$name.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xff302822)),
        )
      : const ColoredBox(color: Color(0xff302822));

  Widget _cell(int index, {double width = 230, double height = 230}) =>
      widget.artwork
      ? SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: width * 3,
              maxHeight: height * 2,
              child: Transform.translate(
                offset: Offset(-(index % 3) * width, -(index ~/ 3) * height),
                child: Image.asset(
                  'assets/proof-next/entry-atlas.png',
                  width: width * 3,
                  height: height * 2,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        )
      : SizedBox(width: width, height: height);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final t = _clock.value;
        final w = bounds.maxWidth, h = bounds.maxHeight;
        final moving = widget.departing;
        final reveal = ((t - .12) / .24).clamp(0.0, 1.0);
        final walk = ((t - .36) / .32).clamp(0.0, 1.0);
        final entry = ((t - .68) / .26).clamp(0.0, 1.0);
        final exterior = t >= .245;
        final sway = widget.reducedMotion
            ? 0.0
            : math.sin(walk * math.pi * 5) * 3;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(
                exterior ? -walk * w * .075 : reveal * w * .1,
                sway,
              ),
              child: Transform.scale(
                scale: exterior ? 1 + walk * .23 : 1.05 - reveal * .05,
                child: _picture(exterior ? 'garage-exterior' : 'garage-wall'),
              ),
            ),
            if (!exterior)
              Positioned(
                left: w * .43 - h * .105,
                top: h * .36 - h * .021,
                child: Transform.translate(
                  offset: Offset(
                    moving ? -w * t * 2 : 0,
                    moving ? h * t * 2 : 0,
                  ),
                  child: _cell(moving ? 1 : 0, width: h * .21, height: h * .21),
                ),
              ),
            // A foreground post masks the change of painted camera view.
            if (moving && t > .17 && t < .33)
              Transform.translate(
                offset: Offset(w * (1 - (t - .17) / .16 * 2), 0),
                child: ColoredBox(
                  color: const Color(0xff291e18).withValues(alpha: .98),
                ),
              ),
            if (moving && t >= .68 && t < .83)
              Align(
                alignment: Alignment(1.4 - entry * 1.1, .5),
                child: _cell(3, width: w * .9, height: h * 1.2),
              ),
            if (moving && t >= .80)
              Opacity(
                opacity: ((t - .80) / .05).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1 + entry * .1,
                  child: Center(
                    child: _cell(4, width: w, height: h),
                  ),
                ),
              ),
            if (moving && t > .92)
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: ((t - .92) / .08).clamp(0.0, 1.0),
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
