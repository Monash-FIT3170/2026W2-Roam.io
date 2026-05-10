
// Centralizes the map feature's API base URLs so network endpoints live in one
// place. This keeps service files simpler and makes environment changes safer.

class ApiConfig {
  static const String spatialApiBaseUrl = String.fromEnvironment(
    'SPATIAL_API_BASE_URL',
    defaultValue:
        'https://australia-southeast1-roam-io-71e2c.cloudfunctions.net/api',
  );
}
