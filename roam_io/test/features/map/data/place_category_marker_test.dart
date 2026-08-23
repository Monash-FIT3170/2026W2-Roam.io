import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/theme/app_colours.dart';

void main() {
  test('every Google Place category uses the app sage marker colour', () {
    for (final category in PlaceCategory.values) {
      expect(category.markerColor, AppColors.sage, reason: category.name);
    }
  });
}
