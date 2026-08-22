import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/models/explorer_rank.dart';

void main() {
  group('ExplorerRank.forLevel', () {
    test('maps level bands to titles and badge assets', () {
      expect(ExplorerRank.forLevel(1).title, 'Scout');
      expect(ExplorerRank.forLevel(4).title, 'Scout');
      expect(ExplorerRank.forLevel(5).title, 'Wayfinder');
      expect(ExplorerRank.forLevel(8).title, 'Local Guide');
      expect(ExplorerRank.forLevel(11).title, 'Pathfinder');
      expect(ExplorerRank.forLevel(16).title, 'Urban Expert');
      expect(ExplorerRank.forLevel(21).title, 'Master Navigator');
      expect(ExplorerRank.forLevel(31).title, 'Grand Cartographer');
      expect(ExplorerRank.forLevel(41).title, 'Omniscient Mapper');
      expect(ExplorerRank.forLevel(100).title, 'Omniscient Mapper');
    });

    test('uses omniscient mapper asset for levels 41+', () {
      expect(
        ExplorerRank.forLevel(41).assetPath,
        'assets/badges/omniscient_mapper.png',
      );
      expect(
        ExplorerRank.forLevel(75).assetPath,
        'assets/badges/omniscient_mapper.png',
      );
    });
  });
}
