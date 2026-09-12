import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/party_service.dart';
import '../domain/party.dart';

/// Shares the current user's active Party Mode party across screens (the
/// party/join screen, the map overlay, dwell-ping wiring).
///
/// When a [PartyService] is supplied the party doc is watched here rather than
/// on the party screen, so roster changes keep arriving while that screen is
/// closed.
class CurrentPartyProvider extends ChangeNotifier {
  CurrentPartyProvider({PartyService? partyService})
    : _partyService = partyService;

  final PartyService? _partyService;
  Party? _currentParty;
  StreamSubscription<Party?>? _partySubscription;

  Party? get currentParty => _currentParty;

  void setParty(Party? party) {
    // Re-setting the same party (e.g. the party screen echoing its own live
    // updates) must not tear down and rebuild the subscription.
    final isSameParty =
        party != null &&
        party.id == _currentParty?.id &&
        _partySubscription != null;
    _currentParty = party;
    notifyListeners();
    if (isSameParty) return;

    unawaited(_partySubscription?.cancel());
    _partySubscription = null;

    final service = _partyService;
    if (party == null || service == null) return;
    _partySubscription = service.watchParty(party.id).listen((live) {
      _currentParty = live;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_partySubscription?.cancel());
    super.dispose();
  }
}
