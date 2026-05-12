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

    const regionResult = await getPool().query(
      `
      SELECT 
        ST_Y(ST_Centroid(geometry)) AS lat,
        ST_X(ST_Centroid(geometry)) AS lng,
        name
      FROM regions 
      WHERE id = $1
      `,
      [regionId]
    );

    if (regionResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Region not found',
      });
    }

    const { lat, lng, name: regionName } = regionResult.rows[0];

    console.log(
      `[Places] Cache MISS for region ${regionId} (${regionName}). Fetching from Google...`
    );

    let googlePlaces = [];

    try {
      googlePlaces = await fetchPlacesFromGoogle({
        lat,
        lng,
        radiusMetres: 2000,
        apiKey: GOOGLE_PLACES_API_KEY.value(),
      });

      console.log(
        `[Places] Fetched ${googlePlaces.length} places from Google for ${regionName}`
      );
    } catch (googleError) {
      console.error(
        `[Places] Google API error for ${regionId}:`,
        googleError.message
      );
    }

    for (const place of googlePlaces) {
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
      [regionId, googlePlaces.length]
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
