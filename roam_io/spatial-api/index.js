/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Local spatial API that returns region geometry and square-metre area for map
 *   unlock XP rewards.
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const {
  fetchPlacesFromGoogle,
  mapToCategory,
  TRANSPORT_TYPES,
} = require('./placesService');

const app = express();

app.use(cors());
app.use(express.json({ limit: '2mb' }));

function countTransportPlaces(places) {
  return places.reduce(
    (counts, place) => {
      const types = new Set(place.types || []);
      if (types.has('train_station')) counts.trainStations += 1;
      if (types.has('bus_stop') || types.has('bus_station')) counts.busStops += 1;
      if (types.has('tram_stop') || types.has('light_rail_station')) {
        counts.tramStops += 1;
      }
      return counts;
    },
    { trainStations: 0, busStops: 0, tramStops: 0 }
  );
}

function logTileTransportCounts(regionId, places) {
  const counts = countTransportPlaces(places);
  console.log(
    `[Transport] Tile ${regionId}: ${counts.trainStations} train stations, ` +
    `${counts.busStops} bus stops, ${counts.tramStops} tram stops`
  );
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true' 
    ? { rejectUnauthorized: false } 
    : false,
});

app.get('/health', async (req, res) => {
  try {
    const result = await pool.query('select now()');
    res.json({
      ok: true,
      service: 'roam-spatial-api',
      dbTime: result.rows[0].now,
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(500).json({ ok: false, error: 'Database connection failed' });
  }
});

app.post('/region/contains', async (req, res) => {
  try {
    const { lat, lng } = req.body;

    if (lat == null || lng == null) {
      return res.status(400).json({ error: 'lat and lng are required' });
    }

    const query = `
      SELECT
        id,
        name,
        ST_Area(geography(geometry)) AS area_square_metres,
        ST_AsGeoJSON(geometry) AS geometry
      FROM regions
      WHERE ST_Contains(
        geometry,
        ST_SetSRID(ST_Point($1, $2), 4326)
      )
      LIMIT 1;
    `;

    const result = await pool.query(query, [lng, lat]);
    return res.json(result.rows[0] ?? null);
  } catch (error) {
    console.error('Error in /region/contains:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/regions/viewport', async (req, res) => {
  try {
    const { south, west, north, east } = req.body;

    if ([south, west, north, east].some((v) => v == null)) {
      return res.status(400).json({
        error: 'south, west, north, and east are required',
      });
    }

    const query = `
      SELECT
        id,
        name,
        ST_Area(geography(geometry)) AS area_square_metres,
        ST_AsGeoJSON(geometry) AS geometry
      FROM regions
      WHERE ST_Intersects(
        geometry,
        ST_MakeEnvelope($1, $2, $3, $4, 4326)
      )
      LIMIT 80;
    `;

    const result = await pool.query(query, [west, south, east, north]);
    return res.json(result.rows);
  } catch (error) {
    console.error('Error in /regions/viewport:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});


// ═══════════════════════════════════════════════════════════════════════════════
// PLACES ENDPOINTS
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * GET /places/region/:regionId
 * 
 * Returns places for a specific region.
 * - If cached in DB: returns immediately
 * - If not cached: fetches from Google Places API, caches, then returns
 * 
 * This endpoint should be called when a user unlocks a region.
 */
app.get('/places/region/:regionId', async (req, res) => {
  const { regionId } = req.params;

  try {
    // 1. Check if this region's places have already been fetched
    const cacheCheck = await pool.query(
      `SELECT fetched_at FROM region_places_cache
       WHERE region_id = $1
         AND fetched_at >= TIMESTAMPTZ '2026-07-31 00:00:00+10'`,
      [regionId]
    );

    if (cacheCheck.rows.length > 0) {
      // Cache HIT - return places that are ACTUALLY within the region's polygon
      // This uses ST_Contains for accurate spatial filtering (not just radius-based)
      const places = await pool.query(
        `SELECT 
          p.id, p.google_place_id, p.name, p.category, p.types,
          ST_AsGeoJSON(p.location) as location,
          p.region_id, p.rating, p.user_ratings_total, p.address, p.photo_reference
        FROM places p
        JOIN regions r ON ST_Contains(r.geometry, p.location)
        WHERE r.id = $1`,
        [regionId]
      );

      console.log(`[Places] Cache HIT for region ${regionId}: ${places.rows.length} places (spatially filtered)`);
      logTileTransportCounts(regionId, places.rows);
      return res.json({
        cached: true,
        places: places.rows,
      });
    }

    // 2. Cache MISS - need to fetch from Google from several points in the tile
    // for better coverage than centroid-only searching.
    const regionResult = await pool.query(
      `WITH tile AS (
        SELECT geometry, name FROM regions WHERE id = $1
      ),
      bbox AS (
        SELECT
          ST_XMin(geometry) AS xmin,
          ST_XMax(geometry) AS xmax,
          ST_YMin(geometry) AS ymin,
          ST_YMax(geometry) AS ymax,
          ST_X(ST_Centroid(geometry)) AS cx,
          ST_Y(ST_Centroid(geometry)) AS cy,
          geometry,
          name
        FROM tile
      )
      SELECT
        name,
        json_agg(json_build_object('lat', lat, 'lng', lng)) AS search_points,
        CEIL(GREATEST(xmax - xmin, ymax - ymin) * 111320 * 0.6) AS radius_meters
      FROM bbox,
      LATERAL (VALUES
        (cy, cx),
        (cy + (ymax - cy) * 0.5, cx + (xmax - cx) * 0.5),
        (cy + (ymax - cy) * 0.5, cx - (cx - xmin) * 0.5),
        (cy - (cy - ymin) * 0.5, cx + (xmax - cx) * 0.5),
        (cy - (cy - ymin) * 0.5, cx - (cx - xmin) * 0.5)
      ) AS points(lat, lng)
      GROUP BY name, xmin, xmax, ymin, ymax`,
      [regionId]
    );

    if (regionResult.rows.length === 0) {
      return res.status(404).json({ error: 'Region not found' });
    }

    const { name: regionName, search_points, radius_meters } = regionResult.rows[0];
    const searchRadius = Math.min(50000, Math.max(300, Number(radius_meters)));

    console.log(
      `[Places] Cache MISS for region ${regionId} (${regionName}). Multi-point search with ${search_points.length} points, radius ${searchRadius}m...`
    );

    // 3. Fetch from Google Places API, deduping by Google place id
    const placesMap = new Map();
    for (const point of search_points) {
      try {
        console.log(`[Places] Searching from point (${point.lat.toFixed(4)}, ${point.lng.toFixed(4)})`);

        const [venues, transportStops] = await Promise.all([
          fetchPlacesFromGoogle({
            lat: point.lat,
            lng: point.lng,
            radiusMeters: searchRadius,
          }),
          fetchPlacesFromGoogle({
            lat: point.lat,
            lng: point.lng,
            radiusMeters: searchRadius,
            includedTypes: TRANSPORT_TYPES,
            rankPreference: 'DISTANCE',
          }),
        ]);
        const places = [...venues, ...transportStops];

        for (const place of places) {
          if (!placesMap.has(place.id)) {
            placesMap.set(place.id, place);
          }
        }

        console.log(`[Places] Found ${places.length} places, total unique: ${placesMap.size}`);
      } catch (googleError) {
        console.error(
          `[Places] Google API error at point (${point.lat}, ${point.lng}):`,
          googleError.message,
          googleError.response?.data || ''
        );
      }
    }

    const googlePlaces = Array.from(placesMap.values());
    console.log(`[Places] Total unique places from all points: ${googlePlaces.length}`);

    // Filter places to only those inside the tile, sort by rating, take top 20.
    const placesWithinTile = [];
    for (const place of googlePlaces) {
      if (!place.location?.longitude || !place.location?.latitude) continue;

      const containsResult = await pool.query(
        `SELECT ST_Contains(
          (SELECT geometry FROM regions WHERE id = $1),
          ST_SetSRID(ST_Point($2, $3), 4326)
        ) AS within`,
        [regionId, place.location.longitude, place.location.latitude]
      );

      if (containsResult.rows[0]?.within) {
        placesWithinTile.push(place);
      }
    }

    placesWithinTile.sort((a, b) => {
      const ratingA = a.rating || 0;
      const ratingB = b.rating || 0;
      if (ratingB !== ratingA) return ratingB - ratingA;
      return (b.userRatingCount || 0) - (a.userRatingCount || 0);
    });

    const isTransport = (place) =>
      (place.types || []).some((type) => TRANSPORT_TYPES.includes(type));
    const transportPlaces = placesWithinTile.filter(isTransport);
    const topVenuePlaces = placesWithinTile.filter((place) => !isTransport(place)).slice(0, 20);
    const selectedPlaces = [...transportPlaces, ...topVenuePlaces];
    console.log(
      `[Places] Filtered to ${placesWithinTile.length} places within tile, keeping ${selectedPlaces.length} (${transportPlaces.length} transport)`
    );
    logTileTransportCounts(regionId, transportPlaces);

    // 4. Store each selected place in database
    for (const place of selectedPlaces) {
      const category = mapToCategory(place.types);
      const photoRef = place.photos?.[0]?.name || null;

      try {
        await pool.query(
          `INSERT INTO places (
            google_place_id, name, category, types, location,
            region_id, rating, user_ratings_total, address, photo_reference
          ) VALUES (
            $1, $2, $3, $4, ST_SetSRID(ST_Point($5, $6), 4326),
            $7, $8, $9, $10, $11
          ) ON CONFLICT (google_place_id) DO UPDATE SET
            category = EXCLUDED.category,
            types = EXCLUDED.types,
            name = EXCLUDED.name,
            address = EXCLUDED.address`,
          [
            place.id,
            place.displayName?.text || 'Unknown',
            category,
            place.types || [],
            place.location?.longitude,
            place.location?.latitude,
            regionId,
            place.rating || null,
            place.userRatingCount || null,
            place.formattedAddress || null,
            photoRef,
          ]
        );
      } catch (insertError) {
        console.error(`[Places] Failed to insert place ${place.id}:`, insertError.message);
      }
    }

    // 5. Mark region as fetched (even if 0 places found)
    await pool.query(
      `INSERT INTO region_places_cache (region_id, place_count)
       VALUES ($1, $2)
       ON CONFLICT (region_id) DO UPDATE SET fetched_at = NOW(), place_count = $2`,
      [regionId, selectedPlaces.length]
    );

    // 6. Return places that are ACTUALLY within the region's polygon
    // Uses ST_Contains for accurate spatial filtering
    const storedPlaces = await pool.query(
      `SELECT 
        p.id, p.google_place_id, p.name, p.category, p.types,
        ST_AsGeoJSON(p.location) as location,
        p.region_id, p.rating, p.user_ratings_total, p.address, p.photo_reference
      FROM places p
      JOIN regions r ON ST_Contains(r.geometry, p.location)
      WHERE r.id = $1`,
      [regionId]
    );

    return res.json({
      cached: false,
      places: storedPlaces.rows,
    });
  } catch (error) {
    console.error(`[Places] Error fetching places for region ${regionId}:`, error.message);
    return res.status(500).json({ error: 'Failed to fetch places' });
  }
});


/**
 * POST /places/regions
 * 
 * Batch endpoint - get places for multiple regions at once.
 * Only returns cached places (won't trigger Google API calls).
 * Use this for loading places when user opens app with existing unlocks.
 * Uses ST_Contains for accurate spatial filtering within SA2 boundaries.
 */
app.post('/places/regions', async (req, res) => {
  const { regionIds } = req.body;

  if (!Array.isArray(regionIds) || regionIds.length === 0) {
    return res.status(400).json({ error: 'regionIds array required' });
  }

  try {
    // Use ST_Contains to get places actually within each region's polygon
    const places = await pool.query(
      `SELECT 
        p.id, p.google_place_id, p.name, p.category, p.types,
        ST_AsGeoJSON(p.location) as location,
        r.id as region_id,
        p.rating, p.user_ratings_total, p.address, p.photo_reference
      FROM places p
      JOIN regions r ON ST_Contains(r.geometry, p.location)
      WHERE r.id = ANY($1)`,
      [regionIds]
    );

    // Group by region (now using the spatially-determined region_id)
    const byRegion = {};
    for (const place of places.rows) {
      if (!byRegion[place.region_id]) {
        byRegion[place.region_id] = [];
      }
      byRegion[place.region_id].push(place);
    }

    return res.json(byRegion);
  } catch (error) {
    console.error('[Places] Error fetching batch places:', error.message);
    return res.status(500).json({ error: 'Failed to fetch places' });
  }
});


// ═══════════════════════════════════════════════════════════════════════════════
// NEARBY PLACES ENDPOINT (for Journey Mode)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Haversine formula to calculate distance between two points in meters.
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Earth's radius in meters
  const toRad = (deg) => (deg * Math.PI) / 180;
  
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * POST /places/nearby
 * 
 * Returns up to 5 nearest places within the specified radius of a location.
 * Used by Journey Mode for selecting start/end locations.
 * 
 * Request body: { lat, lng, radiusMeters: 25 }
 * Response: [{ placeId, name, address, location: {lat, lng}, distanceMeters }]
 */
app.post('/places/nearby', async (req, res) => {
  try {
    const { lat, lng, radiusMeters = 25 } = req.body;

    if (lat == null || lng == null) {
      return res.status(400).json({ error: 'lat and lng are required' });
    }

    console.log(`[NearbyPlaces] Searching at (${lat}, ${lng}) with radius ${radiusMeters}m`);

    // Fetch places from Google Places API
    let places = [];
    try {
      const [venues, transportStops] = await Promise.all([
        fetchPlacesFromGoogle({
          lat: Number(lat),
          lng: Number(lng),
          radiusMeters: Number(radiusMeters),
          maxResults: 20,
          rankPreference: 'DISTANCE',
        }),
        fetchPlacesFromGoogle({
          lat: Number(lat),
          lng: Number(lng),
          radiusMeters: Number(radiusMeters),
          maxResults: 20,
          includedTypes: TRANSPORT_TYPES,
          rankPreference: 'DISTANCE',
        }),
      ]);
      places = Array.from(
        new Map(
          [...venues, ...transportStops].map((place) => [place.id, place])
        ).values()
      );
    } catch (googleError) {
      console.error('[NearbyPlaces] Google API error:', googleError.message);
      // Return empty array on Google API failure (graceful degradation)
      return res.json([]);
    }

    if (!places || places.length === 0) {
      console.log('[NearbyPlaces] No places found');
      return res.json([]);
    }

    // Calculate distance for each place and filter to those within radius
    const placesWithDistance = places
      .filter((place) => place.location?.latitude && place.location?.longitude)
      .map((place) => {
        const distance = haversineDistance(
          lat,
          lng,
          place.location.latitude,
          place.location.longitude
        );
        return {
          placeId: place.id,
          name: place.displayName?.text || 'Unknown',
          address: place.formattedAddress || '',
          location: {
            lat: place.location.latitude,
            lng: place.location.longitude,
          },
          distanceMeters: Math.round(distance),
        };
      })
      .filter((place) => place.distanceMeters <= radiusMeters);

    // Sort by distance ascending, take top 5
    placesWithDistance.sort((a, b) => a.distanceMeters - b.distanceMeters);
    const top5 = placesWithDistance.slice(0, 5);

    console.log(`[NearbyPlaces] Found ${places.length} places, ${placesWithDistance.length} within ${radiusMeters}m, returning top ${top5.length}`);

    return res.json(top5);
  } catch (error) {
    console.error('[NearbyPlaces] Error:', error.message);
    return res.status(500).json({ error: 'Failed to fetch nearby places' });
  }
});


const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Spatial API running on port ${port}`);
});
