/*
 * Author: Alvin Liong
 * Last Modified: 15/08/2026
 * Description:
 *   Maps profile level to explorer rank title and badge artwork.
 */

/// Explorer rank tier for the Stats level badge hero.
class ExplorerRank {
  const ExplorerRank({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  /// Returns the rank for [level] (clamped to 1+).
  static ExplorerRank forLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;

    if (safeLevel <= 4) {
      return const ExplorerRank(
        title: 'Scout',
        assetPath: 'assets/badges/scout.png',
      );
    }
    if (safeLevel <= 7) {
      return const ExplorerRank(
        title: 'Wayfinder',
        assetPath: 'assets/badges/wayfinder.png',
      );
    }
    if (safeLevel <= 10) {
      return const ExplorerRank(
        title: 'Local Guide',
        assetPath: 'assets/badges/local_guide.png',
      );
    }
    if (safeLevel <= 15) {
      return const ExplorerRank(
        title: 'Pathfinder',
        assetPath: 'assets/badges/pathfinder.png',
      );
    }
    if (safeLevel <= 20) {
      return const ExplorerRank(
        title: 'Urban Expert',
        assetPath: 'assets/badges/urban_expert.png',
      );
    }
    if (safeLevel <= 30) {
      return const ExplorerRank(
        title: 'Master Navigator',
        assetPath: 'assets/badges/master_navigator.png',
      );
    }
    if (safeLevel <= 40) {
      return const ExplorerRank(
        title: 'Grand Cartographer',
        assetPath: 'assets/badges/grand_cartographer.png',
      );
    }

    return const ExplorerRank(
      title: 'Omniscient Mapper',
      assetPath: 'assets/badges/omniscient_mapper.png',
    );
  }
}
