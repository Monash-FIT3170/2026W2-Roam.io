/*
 * Description:
 *   Represents the result of validating a quest completion attempt.
 */

class QuestVerificationResult {
  const QuestVerificationResult({
    required this.isVerified,
    required this.message,
  });

  final bool isVerified;
  final String message;
}