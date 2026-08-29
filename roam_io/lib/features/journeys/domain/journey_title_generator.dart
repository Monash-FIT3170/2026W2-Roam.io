/*
 * Author: OpenAI Codex
 * Last Modified: 19/08/2026
 * Description:
 *   Generates default user-facing titles for completed journeys.
 */

/// Generates the default title shown when reviewing a completed Journey.
String generateJourneyTitle(DateTime startedAt) {
  final hour = startedAt.toLocal().hour;
  if (hour < 12) return 'Morning Journey';
  if (hour < 18) return 'Afternoon Journey';
  return 'Evening Journey';
}
