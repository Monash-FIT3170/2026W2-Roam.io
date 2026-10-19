import 'package:flutter/material.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import 'party_style.dart';

/// Introduction shown before joining a party. The map is illustrative so it
/// needs neither location access nor a live map connection.
class PartyLanding extends StatelessWidget {
  const PartyLanding({super.key, this.onCreate, this.onJoin, this.error});

  final VoidCallback? onCreate;
  final VoidCallback? onJoin;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'Roam.io,\nreimagined.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: AppSurfaces.textPrimary(context),
                              fontSize: 38,
                              height: 1.08,
                              letterSpacing: -1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Team up. Claim tiles.\nMake the map yours.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppSurfaces.textMuted(context),
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 26),
                          const _PartyMapPreview(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    CartoonPressable(
                      soft: true,
                      enabled: onCreate != null,
                      child: ElevatedButton(
                        onPressed: onCreate,
                        style: PartyStyle.button(
                          context,
                          background: AppColors.sage,
                          foreground: Colors.white,
                        ),
                        child: const Text('Create Party'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CartoonPressable(
                      soft: true,
                      enabled: onJoin != null,
                      child: OutlinedButton(
                        onPressed: onJoin,
                        style: PartyStyle.button(
                          context,
                          background: AppSurfaces.softCard(context),
                          foreground: AppSurfaces.textPrimary(context),
                        ),
                        child: const Text('Join Party'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyMapPreview extends StatelessWidget {
  const _PartyMapPreview();

  static const blue = AppColors.teamA;
  static const red = AppColors.teamB;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Party Mode preview: two teams compete to claim map tiles.',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: PartyStyle.card(context, radius: 26, offset: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23.5),
            child: AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _PreviewMapPainter(
                      background: AppSurfaces.innerCard(context),
                      road: AppSurfaces.isDark(context)
                          ? const Color(0xFF454A55)
                          : const Color(0xFFFFFBF1),
                      park: theme.colorScheme.primary.withValues(alpha: 0.22),
                      ink: PartyStyle.outline(context),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: PartyStyle.card(
                        context,
                        color: AppSurfaces.softCard(context),
                        radius: 18,
                        offset: 3,
                      ),
                      child: Row(
                        children: [
                          _score(context, 'Team A', '5 tiles', blue),
                          const PartyVsBadge(),
                          _score(context, 'Team B', '2 tiles', red),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _score(BuildContext context, String team, String tiles, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            team,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            tiles,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMapPainter extends CustomPainter {
  const _PreviewMapPainter({
    required this.background,
    required this.road,
    required this.park,
    required this.ink,
  });

  final Color background;
  final Color road;
  final Color park;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.save();
    canvas.scale(size.width / 360, size.height / 320);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(205, 120, 100, 115),
        const Radius.circular(32),
      ),
      Paint()..color = park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(205, 120, 100, 115),
        const Radius.circular(32),
      ),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final streets = Paint()
      ..color = road
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    for (final x in [30.0, 105.0, 180.0, 270.0, 350.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x - 55, 320), streets);
    }
    for (final y in [90.0, 155.0, 220.0, 285.0]) {
      canvas.drawLine(Offset(0, y), Offset(360, y + 35), streets);
    }
    void tile(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.3));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    tile(const [
      Offset(0, 0),
      Offset(198, 0),
      Offset(169, 172),
      Offset(0, 155),
    ], _PartyMapPreview.blue);
    tile(const [
      Offset(198, 0),
      Offset(360, 0),
      Offset(360, 191),
      Offset(169, 172),
    ], _PartyMapPreview.red);
    tile(const [
      Offset(0, 155),
      Offset(169, 172),
      Offset(144, 320),
      Offset(0, 320),
    ], _PartyMapPreview.blue);
    final avenue = Path()
      ..moveTo(-10, 200)
      ..lineTo(145, 220)
      ..lineTo(370, 315);
    canvas.drawPath(avenue, streets..strokeWidth = 12);
    const location = Offset(154, 235);
    canvas.drawCircle(
      location,
      18,
      Paint()..color = _PartyMapPreview.blue.withValues(alpha: 0.18),
    );
    canvas.drawCircle(location, 11, Paint()..color = ink);
    canvas.drawCircle(location, 8.5, Paint()..color = Colors.white);
    canvas.drawCircle(location, 5.5, Paint()..color = _PartyMapPreview.blue);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewMapPainter oldDelegate) =>
      background != oldDelegate.background ||
      road != oldDelegate.road ||
      park != oldDelegate.park ||
      ink != oldDelegate.ink;
}
