/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Compact relative timestamps for social notification rows (e.g. 2m, 1h).
 */

/// Formats [date] as a short relative string against [now].
String formatRelativeTimestamp(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = reference.difference(date);
  if (delta.inSeconds < 60) return '${delta.inSeconds.clamp(0, 59)}s';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  if (delta.inDays < 7) return '${delta.inDays}d';
  final weeks = (delta.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w';
  return '${date.day}/${date.month}/${date.year}';
}
