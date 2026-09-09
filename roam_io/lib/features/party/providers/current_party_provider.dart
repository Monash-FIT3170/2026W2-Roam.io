import 'package:flutter/foundation.dart';

import '../domain/party.dart';

/// Shares the current user's active Party Mode party across screens (the
/// party/join screen, the map overlay, dwell-ping wiring).
class CurrentPartyProvider extends ChangeNotifier {
  Party? _currentParty;

  Party? get currentParty => _currentParty;

  void setParty(Party? party) {
    _currentParty = party;
    notifyListeners();
  }
}
