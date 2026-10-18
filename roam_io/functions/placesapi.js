const axios = require('axios');

const NEARBY_SEARCH_URL = 'https://places.googleapis.com/v1/places:searchNearby';

const INCLUDED_TYPES = [
  'restaurant',
  'cafe',
  'bar',
  'park',
  'museum',
  'tourist_attraction',
  'shopping_mall',
  'movie_theater',
  'library',
  'art_gallery',
  'zoo',
  'aquarium',
  'amusement_park',
  'stadium',
  'night_club',
];

const TRANSPORT_TYPES = [
  'bus_stop',
  'bus_station',
  'train_station',
  'tram_stop',
  'light_rail_station',
  'subway_station',
  'transit_station',
];

// Table A types only — Places Nearby Search rejects some Table B types
// (e.g. transit_station) when used in includedTypes.
const TRANSPORT_FILTER_TYPES = [
  'bus_stop',
  'bus_station',
  'train_station',
  'tram_stop',
  'light_rail_station',
  'subway_station',
];

/**
 * Fetch places from Google Places API for a given location.
 *
 * Uses the new Places API v1 with a field mask to avoid requesting unnecessary data.
 * Note: Google Places API (New) Nearby Search doesn't support pagination,
 * so we request the max of 20 per call.
 *
 * Pass `includedTypes: null` to omit type filters (required when ranking by
 * DISTANCE). Google rejects requests that combine rankPreference=DISTANCE with
 * includedTypes / includedPrimaryTypes.
 */
async function fetchPlacesFromGoogle({
  lat,
  lng,
  radiusMetres = 2000,
  radiusMeters,
  apiKey,
  maxResults = 20,
  includedTypes = INCLUDED_TYPES,
  rankPreference,
}) {
  if (!apiKey) {
    throw new Error('GOOGLE_PLACES_API_KEY is not configured');
  }

  const searchRadius = radiusMeters ?? radiusMetres;
  const typeFilters =
    includedTypes === null || includedTypes === undefined
      ? null
      : includedTypes;
  // DISTANCE ranking is incompatible with type filters in Places API (New).
  const effectiveRankPreference =
    rankPreference === 'DISTANCE' && typeFilters && typeFilters.length > 0
      ? undefined
      : rankPreference;

  // Google Places API (New) Nearby Search max is 20, no pagination available
  const requestBody = {
    maxResultCount: Math.min(20, maxResults),
    locationRestriction: {
      circle: {
        center: {
          latitude: Number(lat),
          longitude: Number(lng),
        },
        radius: Number(searchRadius),
      },
    },
  };
  if (typeFilters && typeFilters.length > 0) {
    requestBody.includedTypes = typeFilters;
  }
  if (effectiveRankPreference) {
    requestBody.rankPreference = effectiveRankPreference;
  }

  console.log(`[PlacesAPI] Requesting places at (${lat}, ${lng}) with radius ${searchRadius}m`);
  console.log(`[PlacesAPI] Request body:`, JSON.stringify(requestBody, null, 2));

  try {
    const response = await axios.post(NEARBY_SEARCH_URL, requestBody, {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': [
          'places.id',
          'places.displayName',
          'places.types',
          'places.location',
          'places.rating',
          'places.userRatingCount',
          'places.formattedAddress',
          'places.photos',
        ].join(','),
      },
    });

    const places = response.data.places || [];
    console.log(`[PlacesAPI] Response status: ${response.status}`);
    console.log(`[PlacesAPI] Places returned: ${places.length}`);
    if (places.length > 0) {
      console.log(`[PlacesAPI] First place: ${places[0].displayName?.text} at (${places[0].location?.latitude}, ${places[0].location?.longitude})`);
      console.log(`[PlacesAPI] Place types sample:`, places.slice(0, 3).map(p => `${p.displayName?.text}: ${p.types?.join(', ')}`));
    }

    return places;
  } catch (error) {
    const details = error.response?.data || error.message;
    console.error('[PlacesAPI] Request failed:', JSON.stringify(details));
    throw error;
  }
}

function mapToCategory(types) {
  const typeSet = new Set(types || []);

  if (TRANSPORT_TYPES.some((type) => typeSet.has(type))) {
    return 'public_transport';
  }

  if (
    typeSet.has('restaurant') ||
    typeSet.has('cafe') ||
    typeSet.has('bar')
  ) {
    return 'food_drink';
  }

  if (
    typeSet.has('park') ||
    typeSet.has('zoo') ||
    typeSet.has('aquarium')
  ) {
    return 'nature';
  }

  if (
    typeSet.has('museum') ||
    typeSet.has('art_gallery') ||
    typeSet.has('library')
  ) {
    return 'culture';
  }

  if (typeSet.has('shopping_mall')) {
    return 'shopping';
  }

  if (
    typeSet.has('movie_theater') ||
    typeSet.has('stadium') ||
    typeSet.has('amusement_park') ||
    typeSet.has('bowling_alley') ||
    typeSet.has('night_club')
  ) {
    return 'entertainment';
  }

  if (typeSet.has('gym') || typeSet.has('spa')) {
    return 'health_fitness';
  }

  if (typeSet.has('tourist_attraction')) {
    return 'attraction';
  }

  return 'other';
}

module.exports = {
  fetchPlacesFromGoogle,
  mapToCategory,
  INCLUDED_TYPES,
  TRANSPORT_TYPES,
  TRANSPORT_FILTER_TYPES,
};
