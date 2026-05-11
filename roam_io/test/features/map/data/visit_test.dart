/*
 * Unit tests for Visit model data handling.
 * Tests serialization, deserialization, copyWith, and display name logic.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visit.dart';

void main() {
  group('Visit', () {
    final testDate = DateTime(2024, 5, 12, 10, 30);

    Visit createTestVisit({
      String? customName,
      String? description,
      List<String>? mediaUrls,
    }) {
      return Visit(
        placeId: 123,
        googlePlaceId: 'ChIJtest123',
        placeName: 'Test Place',
        regionId: 'SA2_12345',
        category: 'food_drink',
        visitedAt: testDate,
        customName: customName,
        description: description,
        mediaUrls: mediaUrls ?? [],
      );
    }

    group('displayName', () {
      test('returns placeName when customName is null', () {
        final visit = createTestVisit();
        expect(visit.displayName, 'Test Place');
      });

      test('returns customName when set', () {
        final visit = createTestVisit(customName: 'My Favorite Cafe');
        expect(visit.displayName, 'My Favorite Cafe');
      });

      test('returns customName even when empty string', () {
        final visit = createTestVisit(customName: '');
        expect(visit.displayName, '');
      });
    });

    group('toMap', () {
      test('serializes all required fields correctly', () {
        final visit = createTestVisit();
        final map = visit.toMap();

        expect(map['placeId'], 123);
        expect(map['googlePlaceId'], 'ChIJtest123');
        expect(map['placeName'], 'Test Place');
        expect(map['regionId'], 'SA2_12345');
        expect(map['category'], 'food_drink');
        expect(map['visitedAt'], isA<Timestamp>());
        expect((map['visitedAt'] as Timestamp).toDate(), testDate);
      });

      test('serializes optional fields when provided', () {
        final visit = createTestVisit(
          customName: 'Custom Name',
          description: 'A great visit',
          mediaUrls: ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
        );
        final map = visit.toMap();

        expect(map['customName'], 'Custom Name');
        expect(map['description'], 'A great visit');
        expect(map['mediaUrls'], ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg']);
      });

      test('serializes null optional fields as null', () {
        final visit = createTestVisit();
        final map = visit.toMap();

        expect(map['customName'], isNull);
        expect(map['description'], isNull);
        expect(map['mediaUrls'], isEmpty);
      });
    });

    group('fromMap', () {
      test('deserializes all required fields correctly', () {
        final map = {
          'placeId': 456,
          'googlePlaceId': 'ChIJabc456',
          'placeName': 'Another Place',
          'regionId': 'SA2_67890',
          'category': 'nature',
          'visitedAt': Timestamp.fromDate(testDate),
        };

        final visit = Visit.fromMap(map);

        expect(visit.placeId, 456);
        expect(visit.googlePlaceId, 'ChIJabc456');
        expect(visit.placeName, 'Another Place');
        expect(visit.regionId, 'SA2_67890');
        expect(visit.category, 'nature');
        expect(visit.visitedAt, testDate);
      });

      test('deserializes optional fields when present', () {
        final map = {
          'placeId': 456,
          'googlePlaceId': 'ChIJabc456',
          'placeName': 'Another Place',
          'regionId': 'SA2_67890',
          'category': 'nature',
          'visitedAt': Timestamp.fromDate(testDate),
          'customName': 'My Custom Name',
          'description': 'Had a great time',
          'mediaUrls': ['url1', 'url2'],
        };

        final visit = Visit.fromMap(map);

        expect(visit.customName, 'My Custom Name');
        expect(visit.description, 'Had a great time');
        expect(visit.mediaUrls, ['url1', 'url2']);
      });

      test('defaults mediaUrls to empty list when null', () {
        final map = {
          'placeId': 456,
          'googlePlaceId': 'ChIJabc456',
          'placeName': 'Another Place',
          'regionId': 'SA2_67890',
          'category': 'nature',
          'visitedAt': Timestamp.fromDate(testDate),
          'mediaUrls': null,
        };

        final visit = Visit.fromMap(map);
        expect(visit.mediaUrls, isEmpty);
      });

      test('defaults mediaUrls to empty list when missing', () {
        final map = {
          'placeId': 456,
          'googlePlaceId': 'ChIJabc456',
          'placeName': 'Another Place',
          'regionId': 'SA2_67890',
          'category': 'nature',
          'visitedAt': Timestamp.fromDate(testDate),
        };

        final visit = Visit.fromMap(map);
        expect(visit.mediaUrls, isEmpty);
      });
    });

    group('copyWith', () {
      test('returns identical visit when no parameters provided', () {
        final original = createTestVisit(
          customName: 'Original Name',
          description: 'Original Description',
          mediaUrls: ['url1'],
        );
        final copy = original.copyWith();

        expect(copy.placeId, original.placeId);
        expect(copy.googlePlaceId, original.googlePlaceId);
        expect(copy.placeName, original.placeName);
        expect(copy.regionId, original.regionId);
        expect(copy.category, original.category);
        expect(copy.visitedAt, original.visitedAt);
        expect(copy.customName, original.customName);
        expect(copy.description, original.description);
        expect(copy.mediaUrls, original.mediaUrls);
      });

      test('updates customName while preserving other fields', () {
        final original = createTestVisit(customName: 'Old Name');
        final updated = original.copyWith(customName: 'New Name');

        expect(updated.customName, 'New Name');
        expect(updated.placeId, original.placeId);
        expect(updated.placeName, original.placeName);
      });

      test('updates description while preserving other fields', () {
        final original = createTestVisit(description: 'Old description');
        final updated = original.copyWith(description: 'New description');

        expect(updated.description, 'New description');
        expect(updated.placeId, original.placeId);
      });

      test('updates mediaUrls while preserving other fields', () {
        final original = createTestVisit(mediaUrls: ['url1']);
        final updated = original.copyWith(mediaUrls: ['url1', 'url2', 'url3']);

        expect(updated.mediaUrls, ['url1', 'url2', 'url3']);
        expect(updated.placeId, original.placeId);
      });

      test('can update multiple fields at once', () {
        final original = createTestVisit();
        final updated = original.copyWith(
          customName: 'New Name',
          description: 'New Description',
          mediaUrls: ['new_url'],
        );

        expect(updated.customName, 'New Name');
        expect(updated.description, 'New Description');
        expect(updated.mediaUrls, ['new_url']);
        expect(updated.placeId, original.placeId);
      });
    });

    group('roundtrip serialization', () {
      test('toMap and fromMap preserve all data', () {
        final original = createTestVisit(
          customName: 'My Visit',
          description: 'Great place to visit',
          mediaUrls: ['https://storage.com/photo1.jpg', 'https://storage.com/video1.mp4'],
        );

        final map = original.toMap();
        final restored = Visit.fromMap(map);

        expect(restored.placeId, original.placeId);
        expect(restored.googlePlaceId, original.googlePlaceId);
        expect(restored.placeName, original.placeName);
        expect(restored.regionId, original.regionId);
        expect(restored.category, original.category);
        expect(restored.visitedAt, original.visitedAt);
        expect(restored.customName, original.customName);
        expect(restored.description, original.description);
        expect(restored.mediaUrls, original.mediaUrls);
      });

      test('toMap and fromMap preserve null optional fields', () {
        final original = createTestVisit();

        final map = original.toMap();
        final restored = Visit.fromMap(map);

        expect(restored.customName, isNull);
        expect(restored.description, isNull);
        expect(restored.mediaUrls, isEmpty);
      });
    });

    group('toString', () {
      test('includes key identifiers', () {
        final visit = createTestVisit(customName: 'Custom');
        final str = visit.toString();

        expect(str, contains('placeId: 123'));
        expect(str, contains('placeName: Test Place'));
        expect(str, contains('customName: Custom'));
        expect(str, contains('visitedAt:'));
      });
    });
  });
}
