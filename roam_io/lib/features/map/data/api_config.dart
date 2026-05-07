/*
 * Author: Rushil Patel
 * Last Modified: 28/04/2026
 * Description:
 *   Defines configuration values for the spatial API used by map and region
 *   features.
 */

/// Centralizes spatial API configuration for region lookup services.
class ApiConfig {
  /// Base URL for the spatial API, overridable with a compile-time variable.
  static const String spatialApiBaseUrl = String.fromEnvironment(
    'SPATIAL_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
