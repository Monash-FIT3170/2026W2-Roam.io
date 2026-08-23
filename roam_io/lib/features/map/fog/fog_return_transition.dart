import 'fog_palette.dart';

/// One batched visual transition for regions whose fog returned while away.
class FogReturnTransition {
  FogReturnTransition({
    required Set<String> regionIds,
    required this.startedAt,
    this.duration = FogPalette.dissolveDuration,
  }) : regionIds = Set<String>.unmodifiable(regionIds);

  final Set<String> regionIds;
  final Duration startedAt;
  final Duration duration;

  double progressAt(Duration now) {
    final total = duration.inMicroseconds;
    if (total <= 0) return 1;
    return ((now - startedAt).inMicroseconds / total).clamp(0.0, 1.0);
  }

  bool isCompleteAt(Duration now) => progressAt(now) >= 1;

  /// Smoothly reduces the clear hole so clouds fade back over the region.
  double clearOpacityAt(Duration now) {
    final progress = progressAt(now);
    return 1 - progress * progress * (3 - 2 * progress);
  }
}
