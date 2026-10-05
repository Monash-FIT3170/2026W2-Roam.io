/*
 * Author: Amarprit Singh
 * Last Updated: 5 October 2026
 * Description:
 *   Tests for the Profile tab's one-row photo preview.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/activity_feed/models/activity_media_item.dart';
import 'package:roam_io/features/you/widgets/profile/photo_strip.dart';

void main() {
  testWidgets('shows four photos, folding the rest into a +N tile', (
    tester,
  ) async {
    var galleryOpens = 0;
    final openedPhotos = <int>[];
    await tester.pumpWidget(
      _host(
        ProfilePhotoStrip(
          media: [for (var index = 0; index < 6; index++) _photo(index)],
          onOpenGallery: () => galleryOpens++,
          onOpenPhoto: openedPhotos.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Open photo').first);
    await tester.tap(find.text('+2'));
    await tester.tap(find.text('Photos'));

    expect(openedPhotos, [0]);
    expect(galleryOpens, 2);
  });

  testWidgets('keeps tile size and drops the +N with few photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ProfilePhotoStrip(
          media: [_photo(0), _photo(1)],
          moreAvailable: true,
          onOpenGallery: () {},
          onOpenPhoto: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2+'), findsOneWidget);
    expect(find.textContaining('+', findRichText: false), findsOneWidget);
    expect(find.bySemanticsLabel('Open photo'), findsNWidgets(2));
    final tiles = tester.getSize(find.bySemanticsLabel('Open photo').first);
    // A quarter of the 360pt row, less the gaps between tiles.
    expect(tiles.width, closeTo((360 - 3 * 6) / 4, 0.5));
  });

  testWidgets('renders nothing without photos', (tester) async {
    await tester.pumpWidget(
      _host(
        ProfilePhotoStrip(
          media: const [],
          onOpenGallery: () {},
          onOpenPhoto: (_) {},
        ),
      ),
    );

    expect(find.text('Photos'), findsNothing);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

ActivityMediaItem _photo(int index) {
  return ActivityMediaItem(
    id: 'media_$index',
    type: ActivityMediaType.photo,
    url: 'https://example.com/photo_$index.jpg',
    storagePath: 'activity_media/user-1/a/media_$index.jpg',
    order: index,
    createdAt: DateTime(2026, 10, 1),
  );
}
