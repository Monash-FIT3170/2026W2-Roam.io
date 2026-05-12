const axios = require('axios');

const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;
const NEARBY_SEARCH_URL = 'https://places.googleapis.com/v1/places:searchNearby';

// Categories we care about for the app
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

/**
 * Fetch places from Google Places API for a given location.
 * Uses the new Places API (v1) with field masks to minimize cost.
 * 
 * @param {number} lat - Latitude of the center point
 * @param {number} lng - Longitude of the center point
 * @param {number} radiusMetres - Search radius in metres (default: 2000)
 * @returns {Promise<Array>} Array of place objects from Google
 */
async function fetchPlacesFromGoogle(lat, lng, radiusMetres = 2000) {
  if (!GOOGLE_PLACES_API_KEY) {
    throw new Error('GOOGLE_PLACES_API_KEY is not configured');
  }

  const response = await axios.post(
    NEARBY_SEARCH_URL,
    {
      includedTypes: INCLUDED_TYPES,
      maxResultCount: 20,
      locationRestriction: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: radiusMetres,
        },
      },
    },
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_PLACES_API_KEY,
        // Request only essential fields (cheaper/free tier)
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
    }
  );

  return response.data.places || [];
}

/**
 * Map Google's category types to our simplified categories.
 * 
 * @param {Array<string>} types - Array of Google place types
 * @returns {string} Simplified category string
 */
function mapToCategory(types) {
  const typeSet = new Set(types || []);

  if (typeSet.has('restaurant') || typeSet.has('cafe') || typeSet.has('bar')) {
    return 'food_drink';
  }
  if (typeSet.has('park') || typeSet.has('zoo') || typeSet.has('aquarium')) {
    return 'nature';
  }
  if (typeSet.has('museum') || typeSet.has('art_gallery') || typeSet.has('library')) {
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
};
