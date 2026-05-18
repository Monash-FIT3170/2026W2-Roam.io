/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Firebase spatial API that returns region geometry and square-metre area for
 *   map unlock XP rewards.
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const {
  fetchPlacesFromGoogle,
  mapToCategory,
} = require('./placesapi');

const DATABASE_URL = defineSecret('DATABASE_URL');
const GOOGLE_PLACES_API_KEY = defineSecret('GOOGLE_PLACES_API_KEY');

const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: '2mb' }));

let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({
      connectionString: DATABASE_URL.value(),
      ssl: {
        rejectUnauthorized: false,
      },
    });
  }

  return pool;
}

app.get('/health', async (req, res) => {
  try {
    const result = await getPool().query('select now()');

    return res.json({
      ok: true,
      service: 'roam-spatial-api',
      dbTime: result.rows[0].now,
    });
  } catch (error) {
    console.error('Health check failed:', error);
    return res.status(500).json({
      ok: false,
      error: 'Database connection failed',
    });
  }
});

// get the polygon we are in right now

app.post('/region/contains', async (req, res) => {
  try {
    const { lat, lng } = req.body;

    if (lat == null || lng == null) {
      return res.status(400).json({
        error: 'lat and lng are required',
      });
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

    const result = await getPool().query(query, [lng, lat]);
    return res.json(result.rows[0] ?? null);
  } catch (error) {
    console.error('Error in /region/contains:', error);
    return res.status(500).json({
      error: 'Internal server error',
    });
  }
});


// get all polygons in viewport

app.post('/regions/viewport', async (req, res) => {
  try {
    const { south, west, north, east } = req.body;

    if ([south, west, north, east].some((value) => value == null)) {
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

    const result = await getPool().query(query, [west, south, east, north]);
    return res.json(result.rows);
  } catch (error) {
    console.error('Error in /regions/viewport:', error);
    return res.status(500).json({
      error: 'Internal server error',
    });
  }
});



// get places 


app.get('/places/region/:regionId', async (req, res) => {
  const { regionId } = req.params;

  try {
    const cacheCheck = await getPool().query(
      'SELECT fetched_at FROM region_places_cache WHERE region_id = $1',
      [regionId]
    );

    if (cacheCheck.rows.length > 0) {
      const places = await getPool().query(
        `
        SELECT
          p.id,
          p.google_place_id,
          p.name,
          p.category,
          p.types,
          ST_AsGeoJSON(p.location) AS location,
          p.region_id,
          p.rating,
          p.user_ratings_total,
          p.address,
          p.photo_reference
        FROM places p
        JOIN regions r ON ST_Contains(r.geometry, p.location)
        WHERE r.id = $1
        `,
        [regionId]
      );

      console.log(
        `[Places] Cache HIT for region ${regionId}: ${places.rows.length} places`
      );

      return res.json({
        cached: true,
        places: places.rows,
      });
    }

    // Get multiple search points within the tile for better coverage:
    // - Centroid (center)
    // - 4 points at 50% distance toward each corner of the bounding box
    const regionResult = await getPool().query(
      `
      WITH tile AS (
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
        -- Use smaller radius since we're doing multiple searches
        CEIL(GREATEST(xmax - xmin, ymax - ymin) * 111320 * 0.6) AS radius_meters
      FROM bbox,
      LATERAL (VALUES
        (cy, cx),  -- centroid
        (cy + (ymax - cy) * 0.5, cx + (xmax - cx) * 0.5),  -- toward NE
        (cy + (ymax - cy) * 0.5, cx - (cx - xmin) * 0.5),  -- toward NW
        (cy - (cy - ymin) * 0.5, cx + (xmax - cx) * 0.5),  -- toward SE
        (cy - (cy - ymin) * 0.5, cx - (cx - xmin) * 0.5)   -- toward SW
      ) AS points(lat, lng)
      GROUP BY name, xmin, xmax, ymin, ymax
      `,
      [regionId]
    );

    if (regionResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Region not found',
      });
    }

    const { name: regionName, search_points, radius_meters } = regionResult.rows[0];
    // Cap radius, minimum 300m for multi-point search
    const searchRadius = Math.min(50000, Math.max(300, Number(radius_meters)));

    console.log(
      `[Places] Cache MISS for region ${regionId} (${regionName}). Multi-point search with ${search_points.length} points, radius ${searchRadius}m...`
    );

    // Collect all places from multiple search points, dedupe by google_place_id
    const placesMap = new Map(); // google_place_id -> place object

    for (const point of search_points) {
      try {
        console.log(`[Places] Searching from point (${point.lat.toFixed(4)}, ${point.lng.toFixed(4)})`);

        const places = await fetchPlacesFromGoogle({
          lat: point.lat,
          lng: point.lng,
          radiusMeters: searchRadius,
          apiKey: GOOGLE_PLACES_API_KEY.value(),
        });

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

    // Filter places to only those inside the tile, sort by rating, take top 20
    const placesWithinTile = [];
    for (const place of googlePlaces) {
      if (!place.location?.longitude || !place.location?.latitude) continue;

      // Check if place is within tile boundary
      const containsResult = await getPool().query(
        `
        SELECT ST_Contains(
          (SELECT geometry FROM regions WHERE id = $1),
          ST_SetSRID(ST_Point($2, $3), 4326)
        ) AS within
        `,
        [regionId, place.location.longitude, place.location.latitude]
      );

      if (containsResult.rows[0]?.within) {
        placesWithinTile.push(place);
      }
    }

    // Sort by rating (highest first), then by user ratings count as tiebreaker
    placesWithinTile.sort((a, b) => {
      const ratingA = a.rating || 0;
      const ratingB = b.rating || 0;
      if (ratingB !== ratingA) return ratingB - ratingA;
      return (b.userRatingCount || 0) - (a.userRatingCount || 0);
    });

    // Take top 20
    const top20Places = placesWithinTile.slice(0, 20);

    console.log(
      `[Places] Filtered to ${placesWithinTile.length} places within tile, keeping top ${top20Places.length}`
    );

    // Insert the top 20 places
    for (const place of top20Places) {
      const category = mapToCategory(place.types);
      const photoRef = place.photos?.[0]?.name || null;

      try {
        await getPool().query(
          `
          INSERT INTO places (
            google_place_id,
            name,
            category,
            types,
            location,
            region_id,
            rating,
            user_ratings_total,
            address,
            photo_reference
          ) VALUES (
            $1,
            $2,
            $3,
            $4,
            ST_SetSRID(ST_Point($5, $6), 4326),
            $7,
            $8,
            $9,
            $10,
            $11
          )
          ON CONFLICT (google_place_id) DO NOTHING
          `,
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
        console.error(
          `[Places] Failed to insert place ${place.id}:`,
          insertError.message
        );
      }
    }

    await getPool().query(
      `
      INSERT INTO region_places_cache (region_id, place_count)
      VALUES ($1, $2)
      ON CONFLICT (region_id)
      DO UPDATE SET fetched_at = NOW(), place_count = $2
      `,
      [regionId, top20Places.length]
    );

    const storedPlaces = await getPool().query(
      `
      SELECT 
        p.id,
        p.google_place_id,
        p.name,
        p.category,
        p.types,
        ST_AsGeoJSON(p.location) AS location,
        p.region_id,
        p.rating,
        p.user_ratings_total,
        p.address,
        p.photo_reference
      FROM places p
      JOIN regions r ON ST_Contains(r.geometry, p.location)
      WHERE r.id = $1
      `,
      [regionId]
    );

    return res.json({
      cached: false,
      places: storedPlaces.rows,
    });
  } catch (error) {
    console.error(
      `[Places] Error fetching places for region ${regionId}:`,
      error.message
    );

    return res.status(500).json({
      error: 'Failed to fetch places',
    });
  }
});



// get places from already stored ones

app.post('/places/regions', async (req, res) => {
  const { regionIds } = req.body;

  if (!Array.isArray(regionIds) || regionIds.length === 0) {
    return res.status(400).json({
      error: 'regionIds array required',
    });
  }

  try {
    const places = await getPool().query(
      `
      SELECT 
        p.id,
        p.google_place_id,
        p.name,
        p.category,
        p.types,
        ST_AsGeoJSON(p.location) AS location,
        r.id AS region_id,
        p.rating,
        p.user_ratings_total,
        p.address,
        p.photo_reference
      FROM places p
      JOIN regions r ON ST_Contains(r.geometry, p.location)
      WHERE r.id = ANY($1)
      `,
      [regionIds]
    );

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

    return res.status(500).json({
      error: 'Failed to fetch places',
    });
  }
});

exports.api = onRequest(
  {
    region: 'australia-southeast1',
    secrets: [DATABASE_URL, GOOGLE_PLACES_API_KEY],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  app
);
