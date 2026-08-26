/*
 * Description:
 *   Represents the structured result returned by AI photo verification.
 */

class QuestPhotoVerificationResult {
  const QuestPhotoVerificationResult({
    required this.verified,
    required this.confidence,
    required this.feedback,
  });

  final bool verified;
  final double confidence;
  final String feedback;

  factory QuestPhotoVerificationResult.fromMap(Map<String, dynamic> map) {
    return QuestPhotoVerificationResult(
      verified: map['verified'] as bool? ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      feedback:
          map['feedback'] as String? ?? 'The photo could not be verified.',
    );
  }
}
