
// Centralizes the map feature's API base URLs so network endpoints live in one
// place. This keeps service files simpler and makes environment changes safer.

class ApiConfig {
  static const String spatialApiBaseUrl = String.fromEnvironment(
    'SPATIAL_API_BASE_URL',
    defaultValue: 'http://localhost:3000', //'http://10.0.2.2:3000', // use local host for ios and 10.0.2.2 for android runs
  );
}
