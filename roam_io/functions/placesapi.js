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

/**
 * Fetch places from Google Places API for a given location.
 *
 * Uses the new Places API v1 with a field mask to avoid requesting unnecessary data.
 */
async function fetchPlacesFromGoogle({
  lat,
  lng,
  radiusmetres = 2000,
  apiKey,
}) {
  if (!apiKey) {
    throw new Error('GOOGLE_PLACES_API_KEY is not configured');
  }

  const response = await axios.post(
    NEARBY_SEARCH_URL,
    {
      includedTypes: INCLUDED_TYPES,
      maxResultCount: 20,
      locationRestriction: {
        circle: {
          center: {
            latitude: Number(lat),
            longitude: Number(lng),
          },
          radius: radiusmetres,
        },
      },
    },
    {
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
    }
  );

  return response.data.places || [];
}

function mapToCategory(types) {
  const typeSet = new Set(types || []);

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
};