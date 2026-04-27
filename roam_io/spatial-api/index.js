require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();

app.use(cors());
app.use(express.json({ limit: '2mb' }));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  },
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

const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Spatial API running on port ${port}`);
});