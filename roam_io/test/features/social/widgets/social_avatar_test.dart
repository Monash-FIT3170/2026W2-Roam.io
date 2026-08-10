/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 9 August 2026
 * Description:
 *   Tests for shared social avatar URL normalization and Storage URL support.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/widgets/social_avatar.dart';

void main() {
  tearDown(() {
    SocialAvatar.debugStorageUrlResolverForTests = null;
    SocialAvatar.clearResolvedUrlCacheForTests();
  });

  test('uses http download URLs directly', () async {
    var resolverCalls = 0;
    SocialAvatar.debugStorageUrlResolverForTests = (rawUrl) async {
      resolverCalls += 1;
      return 'https://cdn.example.com/resolved.jpg';
    };

    final resolved = await SocialAvatar.resolvePhotoUrlForTests(
      '  https://firebasestorage.googleapis.com/photo.jpg  ',
    );

    expect(resolved, 'https://firebasestorage.googleapis.com/photo.jpg');
    expect(resolverCalls, 0);
  });

  testWidgets('renders direct http avatars with Image.network', (tester) async {
    var resolverCalls = 0;
    SocialAvatar.debugStorageUrlResolverForTests = (rawUrl) async {
      resolverCalls += 1;
      return 'https://cdn.example.com/resolved.jpg';
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: SocialAvatar(
          displayName: 'Sanjevan',
          photoUrl: 'https://firebasestorage.googleapis.com/avatar.jpg',
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'https://firebasestorage.googleapis.com/avatar.jpg',
    );
    expect(resolverCalls, 0);
  });

  test('resolves gs urls through Firebase Storage resolver once', () async {
    var resolverCalls = 0;
    SocialAvatar.debugStorageUrlResolverForTests = (rawUrl) async {
      resolverCalls += 1;
      expect(rawUrl, 'gs://bucket/profile_photos/user/avatar.jpg');
      return 'https://firebasestorage.googleapis.com/avatar.jpg';
    };

    final first = await SocialAvatar.resolvePhotoUrlForTests(
      'gs://bucket/profile_photos/user/avatar.jpg',
    );
    final second = await SocialAvatar.resolvePhotoUrlForTests(
      'gs://bucket/profile_photos/user/avatar.jpg',
    );

    expect(first, 'https://firebasestorage.googleapis.com/avatar.jpg');
    expect(second, first);
    expect(resolverCalls, 1);
  });

  test(
    'resolves relative storage paths through Firebase Storage resolver',
    () async {
      SocialAvatar.debugStorageUrlResolverForTests = (rawUrl) async {
        expect(rawUrl, '/profile_photos/user/avatar.jpg');
        return 'https://firebasestorage.googleapis.com/path-avatar.jpg';
      };

      final resolved = await SocialAvatar.resolvePhotoUrlForTests(
        '/profile_photos/user/avatar.jpg',
      );

      expect(
        resolved,
        'https://firebasestorage.googleapis.com/path-avatar.jpg',
      );
    },
  );

  test('rejects unsupported non-storage schemes', () async {
    var resolverCalls = 0;
    SocialAvatar.debugStorageUrlResolverForTests = (rawUrl) async {
      resolverCalls += 1;
      return 'https://firebasestorage.googleapis.com/avatar.jpg';
    };

    final resolved = await SocialAvatar.resolvePhotoUrlForTests(
      'file:///tmp/avatar.jpg',
    );

    expect(resolved, isNull);
    expect(resolverCalls, 0);
  });
}
