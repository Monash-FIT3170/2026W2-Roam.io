import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/map_viewport_policy.dart';

void main() {
  test('viewport loading is supported at and above zoom 14.5', () {
    final policy = MapViewportPolicy();

    expect(policy.supportsViewportLoading(14.49), isFalse);
    expect(policy.supportsViewportLoading(14.5), isTrue);
    expect(policy.supportsViewportLoading(16), isTrue);
  });
}
