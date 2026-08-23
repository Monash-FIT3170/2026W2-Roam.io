import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';

void main() {
  test('encodes and decodes the canonical Google polyline example', () {
    const points = [
      LatLng(38.5, -120.2),
      LatLng(40.7, -120.95),
      LatLng(43.252, -126.453),
    ];

    final encoded = PolylineCodec.encode(points);

    expect(encoded, r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(PolylineCodec.decode(encoded), points);
  });

  test('handles empty and small positive and negative changes', () {
    expect(PolylineCodec.encode(const []), isEmpty);
    expect(PolylineCodec.decode(''), isEmpty);

    const points = [LatLng(0, 0), LatLng(-0.00001, 0.00001)];
    expect(PolylineCodec.decode(PolylineCodec.encode(points)), points);
  });
}
