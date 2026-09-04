/// Controls how long an explored area remains clear before fog may return.
enum FogDecayDifficulty {
  monthly,
  quarterly,
  yearly;

  /// Stable value stored with the user's profile.
  String get storageValue => name.toUpperCase();

  /// Parses persisted data, defaulting older profiles to Quarterly.
  static FogDecayDifficulty fromStorage(Object? value) {
    if (value is String) {
      final normalized = value.toUpperCase();
      for (final difficulty in values) {
        if (difficulty.storageValue == normalized) return difficulty;
      }
    }

    return FogDecayDifficulty.quarterly;
  }
}

/// The single source of truth for fog-decay periods.
Duration getFogDecayDuration(FogDecayDifficulty difficulty) {
  return switch (difficulty) {
    FogDecayDifficulty.monthly => const Duration(days: 30),
    FogDecayDifficulty.quarterly => const Duration(days: 90),
    FogDecayDifficulty.yearly => const Duration(days: 365),
  };
}
