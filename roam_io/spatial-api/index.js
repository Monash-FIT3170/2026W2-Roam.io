require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const { fetchPlacesFromGoogle, mapToCategory } = require('./placesService');

const app = express();

app.use(cors());
app.use(express.json({ limit: '2mb' }));

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
      'SELECT fetched_at FROM region_places_cache WHERE region_id = $1',
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
      return res.json({
        cached: true,
        places: places.rows,
      });
    }

    // 2. Cache MISS - need to fetch from Google
    // First, get the region's centroid
    const regionResult = await pool.query(
      `SELECT 
        ST_Y(ST_Centroid(geometry)) as lat,
        ST_X(ST_Centroid(geometry)) as lng,
        name
      FROM regions 
      WHERE id = $1`,
      [regionId]
    );

    if (regionResult.rows.length === 0) {
      return res.status(404).json({ error: 'Region not found' });
    }

    const { lat, lng, name: regionName } = regionResult.rows[0];
    console.log(`[Places] Cache MISS for region ${regionId} (${regionName}). Fetching from Google...`);

    // 3. Fetch from Google Places API
    let googlePlaces = [];
    try {
      googlePlaces = await fetchPlacesFromGoogle(lat, lng);
      console.log(`[Places] Fetched ${googlePlaces.length} places from Google for ${regionName}`);
    } catch (googleError) {
      console.error(`[Places] Google API error for ${regionId}:`, googleError.message);
      // Continue with empty places - we'll still mark it as cached
    }

    // 4. Store each place in database
    for (const place of googlePlaces) {
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
          ) ON CONFLICT (google_place_id) DO NOTHING`,
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
      [regionId, googlePlaces.length]
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


const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Spatial API running on port ${port}`);
});