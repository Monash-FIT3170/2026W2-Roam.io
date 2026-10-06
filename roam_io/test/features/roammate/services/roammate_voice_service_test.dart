/*
 * Author: Sam Sutherland
 * Last Modified: 06/10/2026
 * Description:
 *   Unit tests for Roammate text-to-speech coordination.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/roammate/services/roammate_voice_service.dart';

void main() {
  test('speak sends non-empty text to the speech engine', () async {
    final engine = _FakeSpeechEngine();
    final service = RoammateVoiceService(speechEngine: engine);

    final result = await service.speak('New region unlocked.');

    expect(result, isTrue);
    expect(engine.spoken, <String>['New region unlocked.']);
  });

  test('speak trims text before sending it to the speech engine', () async {
    final engine = _FakeSpeechEngine();
    final service = RoammateVoiceService(speechEngine: engine);

    await service.speak('  Keep moving safely.  ');

    expect(engine.spoken, <String>['Keep moving safely.']);
  });

  test('speak ignores blank messages', () async {
    final engine = _FakeSpeechEngine();
    final service = RoammateVoiceService(speechEngine: engine);

    final result = await service.speak('   ');

    expect(result, isFalse);
    expect(engine.spoken, isEmpty);
  });

  test('speak contains speech engine failures', () async {
    final engine = _FakeSpeechEngine(throwOnSpeak: true);
    final service = RoammateVoiceService(speechEngine: engine);

    final result = await service.speak('New region unlocked.');

    expect(result, isFalse);
  });

  test('stop forwards to the speech engine', () async {
    final engine = _FakeSpeechEngine();
    final service = RoammateVoiceService(speechEngine: engine);

    await service.stop();

    expect(engine.stopCalls, 1);
  });

  test('stop contains speech engine failures', () async {
    final engine = _FakeSpeechEngine(throwOnStop: true);
    final service = RoammateVoiceService(speechEngine: engine);

    await expectLater(service.stop(), completes);
  });
}

class _FakeSpeechEngine implements RoammateSpeechEngine {
  _FakeSpeechEngine({this.throwOnSpeak = false, this.throwOnStop = false});

  final bool throwOnSpeak;
  final bool throwOnStop;
  final List<String> spoken = <String>[];
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) {
      throw StateError('Speech failed');
    }
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (throwOnStop) {
      throw StateError('Stop failed');
    }
  }
}
