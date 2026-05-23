const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error(`
Missing DATABASE_URL.

Run like this:

DATABASE_URL="your_supabase_connection_string" node import_sa1.js
`);
  process.exit(1);
}

const GEOJSON_PATH = '/Users/rushilpatel/Downloads/SA1_2021_AUST_GDA2020.json'

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  },
});

function getSa1Id(properties) {
  return (
    properties.SA1_CODE21 ||
    properties.SA1_CODE_2021 ||
    properties.sa1_code21 ||
    properties.sa1_code_2021
  );
}

function getRegionName(properties, sa1Id) {
  const parentSa2Name =
    properties.SA2_NAME21 ||
    properties.SA2_NAME_2021 ||
    properties.sa2_name21 ||
    'Unknown SA2';

  return `${parentSa2Name} - SA1 ${sa1Id}`;
}

async function main() {
  console.log(`Reading GeoJSON from: ${GEOJSON_PATH}`);

  if (!fs.existsSync(GEOJSON_PATH)) {
    throw new Error(`GeoJSON file not found at ${GEOJSON_PATH}`);
  }

  const raw = fs.readFileSync(GEOJSON_PATH, 'utf8');
  const geojson = JSON.parse(raw);
  const features = geojson.features || [];

  console.log(`Found ${features.length} SA1 features`);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    for (let i = 0; i < features.length; i++) {
      const feature = features[i];
      const properties = feature.properties || {};
      const geometry = feature.geometry;

      const sa1Id = getSa1Id(properties);

      if (!sa1Id || !geometry) {
        console.warn(`Skipping feature ${i}: missing SA1 id or geometry`);
        continue;
      }

      const id = String(sa1Id);
      const name = getRegionName(properties, id);

      await client.query(
  `
  INSERT INTO regions (
    id,
    name,
    geometry
  )
  VALUES (
    $1,
    $2,
    ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON($3), 4326))
  )
  ON CONFLICT (id)
  DO UPDATE SET
    name = EXCLUDED.name,
    geometry = EXCLUDED.geometry;
  `,
  [
    id,
    name,
    JSON.stringify(geometry),
  ]
);

      if ((i + 1) % 1000 === 0) {
        console.log(`Imported ${i + 1}/${features.length}`);
      }
    }

    await client.query('COMMIT');

    console.log('Creating spatial index...');
    await pool.query(`
      CREATE INDEX IF NOT EXISTS regions_geometry_idx
      ON regions
      USING GIST (geometry);
    `);

    console.log('Running ANALYZE...');
    await pool.query('ANALYZE regions;');

    const countResult = await pool.query('SELECT COUNT(*) FROM regions;');
    console.log(`Import complete. regions count = ${countResult.rows[0].count}`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Import failed:', error);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

main();