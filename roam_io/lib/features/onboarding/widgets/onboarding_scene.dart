import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../map/fog/fog_palette.dart';
import '../../../theme/app_accessibility.dart';

/// Local, illustrative scenes: no GPS, maps SDK, network or account data.
class OnboardingScene extends StatefulWidget {
  const OnboardingScene({
    super.key,
    required this.chapter,
    required this.active,
  });

  final int chapter;
  final bool active;

  @override
  State<OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<OnboardingScene>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(OnboardingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _animate();
  }

  void _animate() {
    if (context.reduceMotion) {
      _entrance.value = 1;
    } else if (widget.active) {
      _entrance.forward(from: 0);
    } else {
      _entrance.stop();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: FittedBox(
          fit: BoxFit.contain,
          child: MediaQuery.withNoTextScaling(
            child: SizedBox(
              width: 340,
              height: 330,
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_entrance.value);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _Contours(dark: dark)),
                      ),
                      Positioned(
                        top: 18,
                        right: 12,
                        child: Transform.rotate(
                          angle: .4 * t,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 25,
                            color: AppColors.clay.withValues(alpha: .7),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 23,
                        left: 14,
                        child: Icon(
                          Icons.add,
                          size: 21,
                          color: dark ? AppColors.lightSage : AppColors.sage,
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: .4 + .6 * t,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - t)),
                            child: switch (widget.chapter) {
                              0 => _ExplorationScene(progress: t),
                              1 => _JourneyScene(progress: t),
                              2 => _LocationScene(progress: t),
                              3 => _QuestScene(progress: t),
                              4 => _SocialScene(progress: t),
                              _ => _ProgressScene(progress: t),
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _paper(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF252C29)
    : const Color(0xFFFFFCF5);

class _Paper extends StatelessWidget {
  const _Paper({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _paper(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.sand.withValues(alpha: .35)),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .1),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: child,
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.icon, {this.green = false});

  final String text;
  final IconData icon;
  final bool green;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: green ? AppColors.sage : _paper(context),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .1),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: green ? Colors.white : AppColors.clay),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: green
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

class _ExplorationScene extends StatelessWidget {
  const _ExplorationScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? FogPalette.nightSpriteTint : FogPalette.spriteTint;
    return Stack(
      children: [
        Positioned(
          left: 19,
          right: 19,
          top: 29,
          bottom: 35,
          child: Transform.rotate(
            angle: -.055,
            child: _Paper(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _MapArt(progress: 0, dark: dark, location: true),
                    ),
                    ClipPath(
                      clipper: _FogCutout(progress),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color:
                                (dark
                                        ? FogPalette.nightWashColor
                                        : FogPalette.washColor)
                                    .withValues(
                                      alpha: dark
                                          ? FogPalette.nightWashOpacity
                                          : FogPalette.washOpacity,
                                    ),
                          ),
                          for (final cloud in [
                            (x: -72.0, y: -76.0, size: 255.0),
                            (x: 83.0, y: -33.0, size: 240.0),
                            (x: -55.0, y: 95.0, size: 238.0),
                            (x: 120.0, y: 115.0, size: 230.0),
                          ])
                            Positioned(
                              left: cloud.x + 9 * progress,
                              top: cloud.y - 6 * progress,
                              child: Image.asset(
                                FogPalette.daySprites.first,
                                width: cloud.size,
                                height: cloud.size,
                                color: tint,
                                colorBlendMode: BlendMode.modulate,
                              ),
                            ),
                        ],
                      ),
                    ),
                    CustomPaint(painter: _UnlockedTiles(progress)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: 7,
          left: 3,
          child: _Tag('Less fog. More possibility.', Icons.wb_cloudy_outlined),
        ),
        Positioned(
          left: 117,
          top: 117,
          child: Transform.scale(
            scale: .8 + .2 * progress,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage.withValues(alpha: .18),
                border: Border.all(color: Colors.white.withValues(alpha: .6)),
              ),
              child: const CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                child: Icon(Icons.directions_walk_rounded, size: 25),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 18,
          child: Transform.rotate(
            angle: .055,
            child: const _Tag(
              'New ground unlocked',
              Icons.layers_rounded,
              green: true,
            ),
          ),
        ),
      ],
    );
  }
}

// Irregular regions echo the real map's tiles, revealed in walking order.
List<Path> _exploredTiles(Size size, double progress) {
  const outlines = [
    [
      Offset(26, 118),
      Offset(95, 92),
      Offset(120, 135),
      Offset(105, 195),
      Offset(38, 183),
    ],
    [
      Offset(95, 92),
      Offset(155, 65),
      Offset(193, 116),
      Offset(171, 158),
      Offset(120, 135),
    ],
    [Offset(155, 65), Offset(215, 39), Offset(243, 93), Offset(193, 116)],
  ];
  return [
    for (var index = 0; index < outlines.length; index++)
      if (progress * 3 > index)
        Path()..addPolygon([
          for (final point in outlines[index])
            Offset(point.dx * size.width / 260, point.dy * size.height / 230),
        ], true),
  ];
}

class _FogCutout extends CustomClipper<Path> {
  const _FogCutout(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final tile in _exploredTiles(size, progress)) {
      path.addPath(tile, Offset.zero);
    }
    return path;
  }

  @override
  bool shouldReclip(_FogCutout oldClipper) => progress != oldClipper.progress;
}

class _UnlockedTiles extends CustomPainter {
  const _UnlockedTiles(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final tile in _exploredTiles(size, progress)) {
      canvas.drawPath(tile, Paint()..color = const Color(0x30FFFFFF));
      canvas.drawPath(
        tile,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_UnlockedTiles oldDelegate) =>
      progress != oldDelegate.progress;
}

class _JourneyScene extends StatelessWidget {
  const _JourneyScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 29,
        top: 32,
        width: 278,
        height: 248,
        child: Transform.rotate(
          angle: -.065,
          child: _Paper(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: _MapArt(
                  progress: progress,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 3 - progress * 5,
        left: 6 - progress * 12,
        child: Opacity(
          opacity: .85 - progress * .25,
          child: Image.asset(
            'assets/fog_of_war/cartoon_cloud_01.png',
            width: 140,
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
      ),
      const Positioned(
        right: 4,
        top: 56,
        child: _Tag('Adventure in progress', Icons.route_rounded, green: true),
      ),
      Positioned(
        left: 9,
        bottom: 32,
        child: _Paper(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.sand,
                foregroundColor: AppColors.ink,
                radius: 19,
                child: Icon(Icons.directions_walk_rounded, size: 23),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The scenic way home',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Your route. Your pace.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: 18,
        bottom: 13,
        child: Transform.rotate(
          angle: .13,
          child: const _Tag('Keep wandering', Icons.north_east_rounded),
        ),
      ),
    ],
  );
}

class _LocationScene extends StatelessWidget {
  const _LocationScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 24,
        right: 24,
        top: 35,
        bottom: 36,
        child: Transform.rotate(
          angle: .045,
          child: _Paper(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                painter: _MapArt(
                  progress: 0,
                  dark: Theme.of(context).brightness == Brightness.dark,
                  location: true,
                ),
                child: Center(
                  child: Container(
                    width: 130 + progress * 18,
                    height: 130 + progress * 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sage.withValues(alpha: .1),
                      border: Border.all(
                        color: AppColors.sage.withValues(alpha: .35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.sage, width: 2),
                        ),
                        child: const CircleAvatar(
                          radius: 27,
                          backgroundColor: AppColors.sage,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.park_outlined, size: 29),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const Positioned(
        left: 8,
        top: 20,
        child: _Tag(
          'In range · within 100m',
          Icons.my_location_rounded,
          green: true,
        ),
      ),
      Positioned(
        right: 0,
        bottom: 31,
        child: Transform.translate(
          offset: Offset(16 * (1 - progress), 0),
          child: _Paper(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.sage,
                  size: 31,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A new favourite spot',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Visited. Remembered. Yours.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 20,
        top: 78,
        child: Image.asset('icons/tram.webp', width: 36, height: 36),
      ),
    ],
  );
}

class _QuestScene extends StatelessWidget {
  const _QuestScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 42,
        right: 34,
        top: 20,
        bottom: 28,
        child: Transform.rotate(
          angle: -.055,
          child: _Paper(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          right: -10,
                          top: -25,
                          child: Icon(
                            Icons.explore_outlined,
                            size: 145,
                            color: Colors.white.withValues(alpha: .1),
                          ),
                        ),
                        const Icon(
                          Icons.landscape_outlined,
                          size: 102,
                          color: AppColors.cream,
                        ),
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: Text(
                            'THE LITTLE DETOUR',
                            style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 13,
                          child: Text(
                            'A new perspective awaits',
                            style: TextStyle(
                              color: AppColors.cream,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  'Find something unexpected',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.sage),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Accept a challenge',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: AppColors.clay,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Follow the quest instructions',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const Positioned(
        left: 0,
        top: 73,
        child: _Tag('Side quest accepted', Icons.explore, green: true),
      ),
      Positioned(
        right: 0,
        bottom: -7 + 7 * progress,
        child: Transform.rotate(
          angle: .075,
          child: const _Tag('Complete it. Earn XP.', Icons.auto_awesome),
        ),
      ),
    ],
  );
}

class _SocialScene extends StatelessWidget {
  const _SocialScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 31,
        top: 42,
        child: Transform.rotate(
          angle: -.12,
          child: const _Explorer(
            name: 'Wanderer',
            badge: 'scout',
            icon: Icons.forest_outlined,
            colour: AppColors.sage,
          ),
        ),
      ),
      Positioned(
        right: 20,
        top: 70 - 10 * progress,
        child: Transform.rotate(
          angle: .1,
          child: const _Explorer(
            name: 'City explorer',
            badge: 'pathfinder',
            icon: Icons.location_city_outlined,
            colour: AppColors.clay,
          ),
        ),
      ),
      const Positioned(
        left: 0,
        bottom: 46,
        child: _Tag(
          'A little friendly competition',
          Icons.emoji_events_outlined,
        ),
      ),
      Positioned(
        right: 8,
        bottom: 10,
        child: Transform.rotate(
          angle: -.05,
          child: const _Tag(
            'Better with your people',
            Icons.people_outline,
            green: true,
          ),
        ),
      ),
      Positioned(
        left: 143,
        top: 12,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _paper(context),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.clay,
            size: 25,
          ),
        ),
      ),
    ],
  );
}

class _Explorer extends StatelessWidget {
  const _Explorer({
    required this.name,
    required this.badge,
    required this.icon,
    required this.colour,
  });
  final String name;
  final String badge;
  final IconData icon;
  final Color colour;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 157,
    height: 199,
    child: _Paper(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset('assets/badges/$badge.png', width: 112),
                Icon(icon, size: 31, color: colour),
              ],
            ),
          ),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Let’s explore',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProgressScene extends StatelessWidget {
  const _ProgressScene({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 5,
        left: 76,
        width: 192,
        height: 206,
        child: Transform.scale(
          scale: .88 + .12 * progress,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/badges/pathfinder.png', width: 192),
              const Icon(
                Icons.explore_rounded,
                size: 53,
                color: AppColors.sage,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 1,
        top: 74,
        child: Transform.rotate(
          angle: -.2,
          child: Image.asset(
            'assets/badges/milestones/tile_collector_1.png',
            width: 85,
            height: 85,
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 155,
        child: Transform.rotate(
          angle: .2,
          child: Image.asset(
            'assets/badges/milestones/visit_viking_1.png',
            width: 77,
            height: 77,
          ),
        ),
      ),
      Positioned(
        left: 32,
        right: 32,
        bottom: 21,
        child: _Paper(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'A little more explorer',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.clay,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: .2 + .55 * progress,
                  minHeight: 9,
                  backgroundColor: AppColors.sand.withValues(alpha: .4),
                  color: AppColors.sage,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Every adventure adds up.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      const Positioned(
        right: 0,
        top: 30,
        child: _Tag('Discover. Earn. Grow.', Icons.trending_up, green: true),
      ),
    ],
  );
}

class _Contours extends CustomPainter {
  const _Contours({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      centre,
      145,
      Paint()..color = AppColors.sand.withValues(alpha: dark ? .06 : .17),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.sage.withValues(alpha: dark ? .22 : .12);
    for (var ring = 0; ring < 4; ring++) {
      final path = Path();
      for (var step = 0; step <= 100; step++) {
        final angle = step / 100 * math.pi * 2;
        final radius = 120 + ring * 12 + math.sin(angle * 3) * 7;
        final point =
            centre +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius * .89);
        if (step == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path..close(), line);
    }
  }

  @override
  bool shouldRepaint(_Contours oldDelegate) => dark != oldDelegate.dark;
}

class _MapArt extends CustomPainter {
  const _MapArt({
    required this.progress,
    required this.dark,
    this.location = false,
  });
  final double progress;
  final bool dark;
  final bool location;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260, size.height / 230);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 260, 230),
      Paint()..color = dark ? const Color(0xFF354036) : const Color(0xFFE4E8D6),
    );
    final blocks = Paint()
      ..color = AppColors.sand.withValues(alpha: dark ? .16 : .55);
    for (var x = -1; x < 4; x++) {
      for (var y = 0; y < 4; y++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * 83.0 + 12, y * 70.0 - 15, 67, 52),
            const Radius.circular(9),
          ),
          blocks,
        );
      }
    }
    final river = Path()
      ..moveTo(-20, 178)
      ..cubicTo(70, 200, 110, 130, 280, 157);
    canvas.drawPath(
      river,
      Paint()
        ..color = dark ? const Color(0xFF4E6C70) : const Color(0xFFBED5D2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28,
    );
    final roads = Paint()
      ..color = dark ? const Color(0xFF637061) : const Color(0xFFFFFCF5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawLine(const Offset(10, 0), const Offset(100, 230), roads);
    canvas.drawLine(const Offset(200, 0), const Offset(155, 230), roads);
    canvas.drawLine(const Offset(0, 77), const Offset(260, 107), roads);
    canvas.drawLine(
      const Offset(0, 208),
      const Offset(260, 28),
      roads..strokeWidth = 7,
    );
    if (!location) {
      final route = Path()
        ..moveTo(65, 180)
        ..lineTo(97, 151)
        ..quadraticBezierTo(108, 135, 126, 128)
        ..lineTo(177, 100)
        ..lineTo(183, 67);
      final metric = route.computeMetrics().first;
      final length = metric.length * (.08 + .92 * progress);
      canvas.drawPath(
        metric.extractPath(0, length),
        Paint()
          ..color = AppColors.sage
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(
        const Offset(65, 180),
        7,
        Paint()..color = AppColors.sage,
      );
      canvas.drawCircle(
        const Offset(65, 180),
        3,
        Paint()..color = Colors.white,
      );
      final tip = metric.getTangentForOffset(length)!.position;
      canvas.drawCircle(
        tip,
        16,
        Paint()..color = AppColors.sage.withValues(alpha: .18),
      );
      canvas.drawCircle(tip, 9, Paint()..color = Colors.white);
      canvas.drawCircle(tip, 6, Paint()..color = AppColors.clay);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapArt oldDelegate) =>
      progress != oldDelegate.progress ||
      dark != oldDelegate.dark ||
      location != oldDelegate.location;
}
