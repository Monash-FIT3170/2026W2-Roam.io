import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/quests/screens/quest_photo_verification_result.dart';

void main() {
  group('QuestPhotoVerificationResult', () {
    test('parses successful AI verification result', () {
      final result = QuestPhotoVerificationResult.fromMap({
        'verified': true,
        'confidence': 0.92,
        'feedback': 'The photo matches the aquarium environment.',
      });

      expect(result.verified, isTrue);
      expect(result.confidence, 0.92);
      expect(result.feedback, 'The photo matches the aquarium environment.');
    });

    test('parses rejected AI verification result', () {
      final result = QuestPhotoVerificationResult.fromMap({
        'verified': false,
        'confidence': 0.25,
        'feedback': 'The image does not show an aquarium.',
      });

      expect(result.verified, isFalse);
      expect(result.confidence, 0.25);
      expect(result.feedback, 'The image does not show an aquarium.');
    });

    test('uses safe defaults when fields are missing', () {
      final result = QuestPhotoVerificationResult.fromMap(<String, dynamic>{});

      expect(result.verified, isFalse);
      expect(result.confidence, 0);
      expect(result.feedback, isNotEmpty);
    });

    test('numeric confidence is converted to double', () {
      final result = QuestPhotoVerificationResult.fromMap({
        'verified': true,
        'confidence': 1,
        'feedback': 'Verified.',
      });

      expect(result.confidence, 1.0);
      expect(result.confidence, isA<double>());
    });
  });
}
