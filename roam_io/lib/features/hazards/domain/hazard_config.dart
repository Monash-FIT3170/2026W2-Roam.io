/// Runtime configuration for temporary community hazards.
class HazardConfig {
  const HazardConfig._();

  static const int expirySeconds = int.fromEnvironment(
    'HAZARD_EXPIRY_SECONDS',
    defaultValue: 43200,
  );

  static const Duration expiryDuration = Duration(seconds: expirySeconds);
  static const Duration maximumExpiry = Duration(hours: 12);
}
