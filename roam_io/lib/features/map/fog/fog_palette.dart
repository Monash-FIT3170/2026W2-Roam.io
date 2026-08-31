/*
 * Description:
 *   Every tunable the fog overlay has, in one place.
 *
 *   The fog is art-driven, so most of these are look-and-feel dials that will
 *   be adjusted on device rather than derived from anything. Keeping them
 *   together means tuning never requires touching render logic.
 */

import 'dart:ui';

/// Look-and-feel constants for the cloud fog overlay.
abstract final class FogPalette {
  // ---------------------------------------------------------------------------
  // Coverage
  // ---------------------------------------------------------------------------

  /// Flat wash drawn beneath the sprites.
  ///
  /// Scattered sprites alone leave thin patches between puffs where the map
  /// would show through at full brightness. The wash carries the opacity floor
  /// and the sprites carry the texture. Sampled from the mid-tone of
  /// Day_Fog_1.png so the two layers sit together.
  static const Color washColor = Color(0xFFA7B6C8);

  /// Wash opacity. Kept light enough that map detail remains visible beneath
  /// the cloud texture.
  static const double washOpacity = 0.46;

  /// Per-sprite tint, multiplied over the artwork via [BlendMode.modulate].
  ///
  /// White leaves the supplied art untouched. Raise toward a cooler or warmer
  /// white here if the fog should read lighter without re-exporting the PNG.
  static const Color spriteTint = Color(0xFFE4E8ED);

  /// Pale screen tint baked over the source artwork in the atlas. This lifts
  /// the blue-grey contour around each puff so overlapping sprites read as one
  /// continuous cloud field instead of separate outlined tiles.
  static const Color spriteEdgeLift = Color(0x38EDF4FA);

  /// Cooler, deeper treatment used while the app is in dark mode.
  static const Color nightWashColor = Color(0xFF4D5D73);
  static const double nightWashOpacity = 0.56;
  static const Color nightSpriteTint = Color(0xFF8190A8);

  // ---------------------------------------------------------------------------
  // Sprite atlas
  // ---------------------------------------------------------------------------

  /// Day sprites, in draw order. More variants improve the field more than
  /// rotation alone does; drop files here and add them to this list.
  static const List<String> daySprites = <String>[
    'assets/fog_of_war/cartoon_cloud_01.png',
  ];

  /// Night sprites. Falls back to [daySprites] while empty.
  static const List<String> nightSprites = <String>[];

  /// Decode width for sprite PNGs.
  ///
  /// Day_Fog_1.png is 1254x1254 and decodes to roughly 6.3MB at full size, but
  /// never renders above a few hundred logical pixels. Downscaling at decode
  /// keeps the atlas texture small.
  static const int spriteDecodeWidth = 768;

  /// Fraction of the sprite half-extent where the edge feather begins and ends.
  ///
  /// The supplied art was cut from a background without a clean alpha matte and
  /// carries cyan/blue fringing, black speckles, and a grey outline tracing its
  /// scalloped border. On one large image that is invisible; scattered as
  /// hundreds of overlapping sprites every one of those outlines repeats and
  /// the field reads as stamped stickers.
  ///
  /// The feather is separable (applied independently on x and y) rather than
  /// radial, because a radial falloff on a square-ish sprite would clip the
  /// corners — where a lot of this artwork lives — at 0.71 of the diagonal.
  ///
  /// Lower [featherOpaqueEdge] to keep more art if a clean-matte export arrives.
  static const double featherTransparentEdge = 0.0;
  static const double featherOpaqueEdge = 0.04;

  // ---------------------------------------------------------------------------
  // Scatter field
  // ---------------------------------------------------------------------------

  /// Target on-screen sprite size in logical pixels at the reference zoom.
  ///
  /// Only a target: the realised size is the chosen level's cell size divided
  /// by [gridSpacingFactor], so power-of-two snapping can round it up to 2x.
  /// Sized so a phone viewport holds tens of puffs rather than one or two —
  /// too large and the field loses its variety no matter how much each sprite
  /// is rotated.
  static const double spriteScreenSize = 200.0;

  /// Grid spacing as a fraction of sprite size.
  ///
  /// Below 1.0 so rotated sprites always overlap and the field never gaps. This
  /// is balanced against [positionJitter] and [scaleVariance]: two neighbours
  /// that both jitter apart and both roll a small scale are the worst case, and
  /// spacing has to cover it. fog_field_test asserts there is no gap, modelling
  /// each sprite as its inscribed circle.
  static const double gridSpacingFactor = 0.5;

  /// Maximum positional jitter within a cell, as a fraction of cell size.
  /// Without this the field reads as an obvious grid.
  static const double positionJitter = 0.28;

  /// Per-instance scale variation, +/- this fraction.
  static const double scaleVariance = 0.1;

  /// Per-instance opacity range.
  static const double opacityMin = 0.42;
  static const double opacityMax = 0.66;

  /// How strongly sprite size tracks zoom.
  ///
  /// 0.0 pins sprites to screen size; 1.0 pins them to the ground and turns a
  /// single puff into a screen-filling blob at zoom 20. Between the two, clouds
  /// grow with zoom but sub-linearly.
  static const double zoomScaleExponent = 0.25;

  /// Parallax layer: larger, slower, fainter.
  static const double parallaxScaleFactor = 1.7;
  static const double parallaxSpeedFactor = 0.45;
  static const double parallaxOpacityFactor = 0.55;

  // ---------------------------------------------------------------------------
  // Motion
  // ---------------------------------------------------------------------------

  /// Resting wind, in reference-zoom world pixels per second.
  static const Offset windVelocity = Offset(9.0, -3.5);

  /// Extra wind per metre/second of user movement, so clouds visibly quicken
  /// when the user is actually travelling.
  static const double windSpeedCoupling = 1.8;

  /// Ceiling on the speed-coupled term so a drive does not turn the fog into a
  /// blur.
  static const double windSpeedCeiling = 45.0;

  /// Per-instance rotation drift, radians per second.
  static const double rotationDriftRate = 0.012;

  /// Frame pacing while the fog is idle. Slow clouds do not need 60fps at rest.
  ///
  /// Deliberately applied only at rest. Pacing a moving camera below the
  /// display's refresh rate is what makes the clouds visibly trail the map, so
  /// movement paints every vsync instead of running through this gate.
  static const int restingFramesPerSecond = 30;

  // ---------------------------------------------------------------------------
  // Motion budget
  // ---------------------------------------------------------------------------

  /// What the parallax cloud layer is worth while the camera is moving.
  ///
  /// The two cloud layers are the overlay's whole fill-rate cost. Sprites are
  /// twice their cell size on each axis (see [gridSpacingFactor]), so a layer
  /// is roughly 4x full-screen translucent overdraw on its own, and the
  /// parallax layer is the one whose [parallaxScaleFactor] lands it mid
  /// blend-band, generating two grid levels rather than one. Dropping it during
  /// a pan is the largest saving available here, and a second fainter, slower
  /// cloud layer is the first thing the eye stops resolving once the map is
  /// sliding under it.
  static const double motionParallaxWeight = 0.0;

  /// Hole feather while the camera is moving, as a fraction of
  /// [holeFeatherRadius]. Every visible cleared region is blurred separately on
  /// every frame with nothing cached, and motion hides a tighter edge.
  static const double motionFeatherFactor = 0.35;

  /// Ceiling on the feather radius in local (world) coordinates.
  ///
  /// [holeFeatherRadius] is divided by the map scale so the feather holds a
  /// constant width on screen, but that inflates the local sigma without bound
  /// as the user zooms out — past 600 at the overview end, for a blur the
  /// canvas transform then shrinks back down to 18 screen pixels. Clamping
  /// trades an increasingly tight on-screen feather at low zoom, where cleared
  /// regions are a few pixels across anyway, for a blur that stays affordable.
  static const double maxLocalFeatherRadius = 128.0;

  /// How long the parallax layer and the feather take to give way to a moving
  /// camera, and how long they take to return afterwards.
  ///
  /// Cutting them the instant a finger lands would visibly pop the fog's
  /// density. Out is quicker than in because the frames are wanted immediately;
  /// the return can afford to be gentle.
  static const Duration motionEaseOut = Duration(milliseconds: 180);
  static const Duration motionEaseIn = Duration(milliseconds: 420);

  // ---------------------------------------------------------------------------
  // Holes and dissipation
  // ---------------------------------------------------------------------------

  /// Blur applied to cleared-region edges, in logical pixels.
  ///
  /// Hard-edged holes look cut out; this is what makes cloud meet clear sky.
  static const double holeFeatherRadius = 18.0;

  /// Duration of the unlock dissipation.
  static const Duration dissolveDuration = Duration(milliseconds: 1400);

  /// Fog return stays on screen long enough for the user to understand which
  /// explored area is changing. It can still be dismissed with the Skip
  /// control shown by the overlay.
  static const Duration fogReturnDuration = Duration(seconds: 6);

  /// How far escaping sprites travel, as a fraction of the region's radius.
  static const double dissolveEscapeDistance = 1.6;

  /// Downwind bias applied to escaping sprites, relative to radial escape.
  static const double dissolveWindBias = 0.65;

  /// Extra spin applied over the dissolve, in radians.
  static const double dissolveSpin = 0.9;

  /// Scale-up applied to escaping sprites as they thin out.
  static const double dissolveScaleGrowth = 0.45;
}
