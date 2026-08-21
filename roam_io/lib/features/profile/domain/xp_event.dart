/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Timestamped XP gain events stored under profiles/{uid}/xp_events for
 *   reactive weekly XP Gained analytics. Events are secondary to canonical
 *   profiles/{uid} XP/level and accumulate only from the point tracking was
 *   introduced; aggregate profile XP is never reverse-engineered into
 *   fabricated history.
 */

/// Origin of an XP award recorded after the user's aggregate XP update.
enum XpEventSource {
  visit,
  tileUnlock,
  journey,
  unknown;

  /// Firestore wire value for this source.
  String get wireValue {
    switch (this) {
      case XpEventSource.visit:
        return 'visit';
      case XpEventSource.tileUnlock:
        return 'tileUnlock';
      case XpEventSource.journey:
        return 'journey';
      case XpEventSource.unknown:
        return 'unknown';
    }
  }

  /// Parses a Firestore source string; unknown values map to [unknown].
  static XpEventSource fromWire(String? value) {
    switch (value) {
      case 'visit':
        return XpEventSource.visit;
      case 'tileUnlock':
        return XpEventSource.tileUnlock;
      case 'journey':
        return XpEventSource.journey;
      default:
        return XpEventSource.unknown;
    }
  }
}

/// A single XP gain recorded when XP is awarded to a user.
class XpEvent {
  const XpEvent({
    required this.id,
    required this.amount,
    required this.earnedAt,
    required this.source,
    this.sourceId,
  });

  final String id;
  final int amount;
  final DateTime earnedAt;
  final XpEventSource source;
  final String? sourceId;

  /// Serialises this event for Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'amount': amount,
      'earnedAt': earnedAt.toIso8601String(),
      'source': source.wireValue,
      if (sourceId != null) 'sourceId': sourceId,
    };
  }

  /// Creates an event from a Firestore document.
  factory XpEvent.fromMap(String id, Map<String, dynamic> data) {
    return XpEvent(
      id: id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      earnedAt:
          DateTime.tryParse(data['earnedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: XpEventSource.fromWire(data['source'] as String?),
      sourceId: data['sourceId'] as String?,
    );
  }
}
