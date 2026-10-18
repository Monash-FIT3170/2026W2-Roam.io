/*
 * Author: Sam Sutherland
 * Last Modified: 06/10/2026
 * Description:
 *   Provides non-blocking text-to-speech output for supported Roammate
 *   messages across Android, iOS, web/PWA, macOS and Windows.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Small abstraction around the platform TTS implementation so voice behaviour
/// can be unit-tested without invoking native or browser speech APIs.
abstract interface class RoammateSpeechEngine {
  Future<void> speak(String text);

  Future<void> stop();
}

/// Production speech engine backed by the flutter_tts plugin.
class FlutterTtsRoammateSpeechEngine implements RoammateSpeechEngine {
  FlutterTtsRoammateSpeechEngine({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;
  bool _configured = false;

  Future<void> _configureIfNeeded() async {
    if (_configured) return;

    // Web speech uses 1.0 as a natural rate, while the native engines exposed
    // by flutter_tts use approximately 0.5 as a normal conversational rate.
    await _flutterTts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _configureIfNeeded();

    // Replace any older Roammate message instead of allowing multiple messages
    // to overlap when map events occur close together.
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

/// Coordinates Roammate speech without owning the user's enable/disable
/// preference. The preference is stored with the user's profile.
class RoammateVoiceService {
  RoammateVoiceService({RoammateSpeechEngine? speechEngine})
    : _speechEngine = speechEngine ?? FlutterTtsRoammateSpeechEngine();

  static final RoammateVoiceService instance = RoammateVoiceService();

  final RoammateSpeechEngine _speechEngine;

  /// Queues [text] for speech. Returns false for blank text or when the
  /// platform speech engine cannot start playback.
  Future<bool> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    try {
      await _speechEngine.speak(trimmed);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[RoammateVoiceService] Could not speak message: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  /// Stops any current Roammate speech. Errors are intentionally contained so
  /// disabling voice can never interfere with the rest of the application.
  Future<void> stop() async {
    try {
      await _speechEngine.stop();
    } catch (error, stackTrace) {
      debugPrint(
        '[RoammateVoiceService] Could not stop speech: '
        '$error\n$stackTrace',
      );
    }
  }
}
