const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error(`
Missing DATABASE_URL.

Run like this:

DATABASE_URL="your_supabase_connection_string" node import_sa3.js
`);
  process.exit(1);
}

const GEOJSON_PATH = '/Users/rushilpatel/Downloads/SA3_2021_AUST_GDA2020.json'

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  },
});

function getSa3Id(properties) {
  return (
    properties.SA3_CODE21 ||
    properties.SA3_CODE_2021 ||
    properties.sa3_code21 ||
    properties.sa3_code_2021
  );
}

function getSa3Name(properties, sa3Id) {
  return (
    properties.SA3_NAME21 ||
    properties.SA3_NAME_2021 ||
    properties.sa3_name21 ||
    `SA3 ${sa3Id}`
  );
}

async function main() {
  console.log(`Reading GeoJSON from: ${GEOJSON_PATH}`);

  if (!fs.existsSync(GEOJSON_PATH)) {
    throw new Error(`GeoJSON file not found at ${GEOJSON_PATH}`);
  }

  const raw = fs.readFileSync(GEOJSON_PATH, 'utf8');
  const geojson = JSON.parse(raw);
  const features = geojson.features || [];

  console.log(`Found ${features.length} SA3 features`);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    await client.query('TRUNCATE TABLE sa3_regions;');

    for (let i = 0; i < features.length; i++) {
      const feature = features[i];
      const properties = feature.properties || {};
      const geometry = feature.geometry;

      const sa3Id = getSa3Id(properties);

      if (!sa3Id || !geometry) {
        console.warn(`Skipping feature ${i}: missing SA3 id or geometry`);
        continue;
      }

      const id = String(sa3Id);
      const name = getSa3Name(properties, id);

      await client.query(
        `
        INSERT INTO sa3_regions (
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
        [id, name, JSON.stringify(geometry)]
      );

      if ((i + 1) % 100 === 0) {
        console.log(`Imported ${i + 1}/${features.length}`);
      }
    }

    await client.query('COMMIT');

    await pool.query(`
      CREATE INDEX IF NOT EXISTS sa3_regions_geometry_idx
      ON sa3_regions
      USING GIST (geometry);
    `);

    await pool.query('ANALYZE sa3_regions;');

    const countResult = await pool.query('SELECT COUNT(*) FROM sa3_regions;');
    console.log(`SA3 import complete. count = ${countResult.rows[0].count}`);
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