/*
 * Description:
 *   One baked cloud atlas per brightness, shared by every fog surface.
 *
 *   Baking decodes a 768px sprite sheet and composites a mirrored copy of every
 *   variant, leaving a texture measured in megabytes. The live map used to be
 *   the only surface that wanted one; now a feed of journey cards and a summary
 *   sheet opened over the map all draw fog, and each baking its own copy of
 *   identical artwork is pure waste.
 *
 *   Holders are counted rather than the atlas being kept forever, so the texture
 *   goes away with the last surface that was drawing it.
 */

import 'dart:async';
import 'dart:ui' show Brightness;

import 'fog_atlas.dart';
import 'fog_palette.dart';

/// Reference-counted cache of baked cloud atlases.
abstract final class FogAtlasCache {
  static final Map<Brightness, Future<FogAtlas?>> _atlases =
      <Brightness, Future<FogAtlas?>>{};
  static final Map<Brightness, int> _holders = <Brightness, int>{};

  /// Sprite artwork for [brightness]. Night falls back to the day set while it
  /// has no artwork of its own.
  static List<String> spritesFor(Brightness brightness) {
    if (brightness != Brightness.dark) return FogPalette.daySprites;
    return FogPalette.nightSprites.isEmpty
        ? FogPalette.daySprites
        : FogPalette.nightSprites;
  }

  /// The atlas for [brightness], baking it if nobody holds one yet.
  ///
  /// Every caller must [release] exactly once, including when it goes away
  /// before this future resolves — the holder is counted at the call, not at
  /// the resolution.
  static Future<FogAtlas?> acquire(Brightness brightness) {
    _holders.update(brightness, (count) => count + 1, ifAbsent: () => 1);
    return _atlases.putIfAbsent(
      brightness,
      () => FogAtlas.load(assetPaths: spritesFor(brightness)),
    );
  }

  /// Drops one holder, disposing the texture when it was the last.
  static Future<void> release(Brightness brightness) async {
    final remaining = (_holders[brightness] ?? 0) - 1;
    if (remaining > 0) {
      _holders[brightness] = remaining;
      return;
    }

    _holders.remove(brightness);
    // Removed before the await so an acquire arriving mid-dispose bakes its own
    // atlas rather than being handed the one about to be thrown away.
    final pending = _atlases.remove(brightness);
    if (pending == null) return;
    (await pending)?.dispose();
  }
}
