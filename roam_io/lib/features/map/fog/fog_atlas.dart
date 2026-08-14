/*
 * Description:
 *   Loads the cloud sprite artwork and bakes it into a single texture suitable
 *   for Canvas.drawAtlas.
 *
 *   Two things happen here that the raw PNGs cannot provide:
 *
 *   1. Edge cleanup. The supplied art was cut from a background without a clean
 *      alpha matte, leaving cyan/blue fringing, black speckles, and a grey
 *      outline around its scalloped border. Invisible on one large image;
 *      scattered as hundreds of overlapping sprites, every outline repeats and
 *      the field reads as stamped stickers. Multiplying alpha down to zero
 *      inside the artifact ring discards the fringe and lets overlapping puffs
 *      merge into continuous cloud.
 *
 *   2. Mirroring. RSTransform carries rotation, uniform scale and translation
 *      but cannot flip, so a horizontally mirrored copy of each sprite is baked
 *      alongside the original and selected per instance. That doubles apparent
 *      variety for no per-frame cost.
 */

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'fog_palette.dart';

/// A baked cloud sprite sheet plus the source rects addressing it.
class FogAtlas {
  const FogAtlas({required this.image, required this.sprites});

  /// Single texture holding every sprite, each in normal and mirrored form.
  final ui.Image image;

  /// Source rectangles into [image]. Even indices are normal, odd are mirrored.
  final List<Rect> sprites;

  int get length => sprites.length;

  bool get isEmpty => sprites.isEmpty;

  /// Source rect for a sprite variant.
  ///
  /// [variant] selects the artwork, [mirrored] the flipped copy of it.
  Rect rectFor({required int variant, required bool mirrored}) {
    final index = ((variant.abs() * 2) + (mirrored ? 1 : 0)) % sprites.length;
    return sprites[index];
  }

  /// Number of distinct source artworks (not counting mirrored copies).
  int get variantCount => sprites.length ~/ 2;

  void dispose() => image.dispose();

  /// Loads [assetPaths] and bakes them into one atlas.
  ///
  /// Returns null when no sprite could be loaded, which the overlay treats as
  /// "draw no fog" rather than failing.
  static Future<FogAtlas?> load({
    required List<String> assetPaths,
    int decodeWidth = FogPalette.spriteDecodeWidth,
  }) async {
    final decoded = <ui.Image>[];

    for (final path in assetPaths) {
      final image = await _decodeAsset(rootBundle, path, decodeWidth);
      if (image != null) decoded.add(image);
    }

    if (decoded.isEmpty) return null;

    try {
      return await _bake(decoded);
    } finally {
      // The atlas owns its own composited copy; the sources are done.
      for (final image in decoded) {
        image.dispose();
      }
    }
  }

  static Future<ui.Image?> _decodeAsset(
    AssetBundle bundle,
    String path,
    int decodeWidth,
  ) async {
    try {
      final data = await bundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: decodeWidth,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      // A missing or corrupt sprite must not take the map down. The overlay
      // renders no fog if every sprite fails.
      return null;
    }
  }

  /// Composites sources into one texture, feathering edges and mirroring.
  static Future<FogAtlas> _bake(List<ui.Image> sources) async {
    final cellWidth = sources
        .map((image) => image.width)
        .reduce((a, b) => a > b ? a : b);
    final cellHeight = sources
        .map((image) => image.height)
        .reduce((a, b) => a > b ? a : b);

    final columns = sources.length * 2;
    final atlasWidth = cellWidth * columns;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rects = <Rect>[];

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];

      for (final mirrored in <bool>[false, true]) {
        final left = (i * 2 + (mirrored ? 1 : 0)) * cellWidth.toDouble();
        final cell = Rect.fromLTWH(
          left,
          0,
          cellWidth.toDouble(),
          cellHeight.toDouble(),
        );

        canvas
          ..save()
          ..clipRect(cell)
          // Isolate the sprite so the feather multiplies only its own alpha
          // and not whatever has already been drawn into the atlas.
          ..saveLayer(cell, ui.Paint());

        if (mirrored) {
          canvas
            ..translate(cell.right, cell.top)
            ..scale(-1.0, 1.0);
        } else {
          canvas.translate(cell.left, cell.top);
        }

        _drawSpriteCentred(canvas, source, cellWidth, cellHeight);
        _applyEdgeFeather(canvas, cellWidth.toDouble(), cellHeight.toDouble());

        canvas
          ..restore()
          ..restore();

        rects.add(cell);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(atlasWidth, cellHeight);
    picture.dispose();

    return FogAtlas(image: image, sprites: rects);
  }

  static void _drawSpriteCentred(
    ui.Canvas canvas,
    ui.Image source,
    int cellWidth,
    int cellHeight,
  ) {
    final offsetX = (cellWidth - source.width) / 2.0;
    final offsetY = (cellHeight - source.height) / 2.0;

    canvas.drawImage(
      source,
      Offset(offsetX, offsetY),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  /// Multiplies the sprite's alpha by a separable edge falloff.
  ///
  /// Applied as two [BlendMode.dstIn] gradients rather than one radial gradient:
  /// the artwork is square-ish and fills its corners, and a radial falloff sized
  /// to trim the border band would clip those corners at 0.71 of the diagonal.
  /// The product of a horizontal and a vertical ramp trims only the border.
  static void _applyEdgeFeather(ui.Canvas canvas, double width, double height) {
    const transparentEdge = FogPalette.featherTransparentEdge;
    const opaqueEdge = FogPalette.featherOpaqueEdge;

    const stops = <double>[
      0.0,
      transparentEdge,
      opaqueEdge,
      1.0 - opaqueEdge,
      1.0 - transparentEdge,
      1.0,
    ];
    const colors = <Color>[
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0x00FFFFFF),
      Color(0x00FFFFFF),
    ];

    final rect = Rect.fromLTWH(0, 0, width, height);

    canvas
      ..drawRect(
        rect,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            rect.centerLeft,
            rect.centerRight,
            colors,
            stops,
          ),
      )
      ..drawRect(
        rect,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            colors,
            stops,
          ),
      );
  }
}
