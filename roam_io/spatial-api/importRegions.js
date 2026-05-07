require('dotenv').config();
const fs = require('fs');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  },
});

const geojson = JSON.parse(
  fs.readFileSync(
    '/Users/rushilpatel/Documents/FULL YEAR/SA2_2021_AUST_GDA2020.json',
    'utf8'
  )
);

async function run() {
  for (const feature of geojson.features) {
    const id = feature.properties.id;
    const name = feature.properties.name;
    const geometryObj = feature.geometry;

    if (!id || !name) {
      console.log('Skipping missing id/name:', feature.properties);
      continue;
    }

    if (!geometryObj) {
      console.log('Skipping null geometry:', id, name);
      continue;
    }

    if (
      geometryObj.type !== 'Polygon' &&
      geometryObj.type !== 'MultiPolygon'
    ) {
      console.log('Skipping unsupported geometry type:', id, name, geometryObj.type);
      continue;
    }

    const geometry = JSON.stringify(geometryObj);

    try {
      await pool.query(
        `
        INSERT INTO regions (id, name, geometry)
        VALUES ($1, $2, ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON($3), 4326)))
        ON CONFLICT (id) DO NOTHING
        `,
        [id, name, geometry]
      );
    } catch (error) {
      console.log('Failed on feature:', id, name, geometryObj.type);
      throw error;
    }
  }

  console.log('Done importing');
  await pool.end();
  process.exit();
}

run().catch(async (error) => {
  console.error('Import failed:', error);
  await pool.end();
  process.exit(1);
});