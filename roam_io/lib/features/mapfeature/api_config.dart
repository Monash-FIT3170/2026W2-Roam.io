
class ApiConfig {
  static const String spatialApiBaseUrl = String.fromEnvironment(
    'SPATIAL_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}