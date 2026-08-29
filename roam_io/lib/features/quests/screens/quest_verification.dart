/*
 * Description:
 *   Represents the final result of checking quest completion evidence.
 */

class QuestVerificationResult {
  const QuestVerificationResult({
    required this.isVerified,
    required this.message,
  });

  final bool isVerified;
  final String message;
}
