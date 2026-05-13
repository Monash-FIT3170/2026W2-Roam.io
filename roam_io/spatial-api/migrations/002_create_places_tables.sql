-- ═══════════════════════════════════════════════════════════════════════════════
-- Places Cache Tables for Google Places API Integration
-- Run this migration against your PostGIS database
-- ═══════════════════════════════════════════════════════════════════════════════

-- Places table for caching Google Places results
CREATE TABLE IF NOT EXISTS places (
  id SERIAL PRIMARY KEY,
  google_place_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT,                          -- food_drink, nature, culture, etc.
  types TEXT[],                           -- Google's type array
  location GEOMETRY(Point, 4326) NOT NULL,
  region_id TEXT NOT NULL,                -- Links to regions table
  rating DECIMAL(2,1),
  user_ratings_total INTEGER,
  address TEXT,
  photo_reference TEXT,                   -- For fetching photos later
  fetched_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_places_region ON places(region_id);
CREATE INDEX IF NOT EXISTS idx_places_location ON places USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);
CREATE INDEX IF NOT EXISTS idx_places_google_id ON places(google_place_id);

-- Track which regions have been fetched (even if 0 places found)
-- This prevents re-fetching from Google API for regions with no POIs
CREATE TABLE IF NOT EXISTS region_places_cache (
  region_id TEXT PRIMARY KEY,
  fetched_at TIMESTAMP DEFAULT NOW(),
  place_count INTEGER DEFAULT 0
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- Verification queries (run after migration)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Check tables exist:
-- SELECT table_name FROM information_schema.tables WHERE table_name IN ('places', 'region_places_cache');

-- Check indexes exist:
-- SELECT indexname FROM pg_indexes WHERE tablename = 'places';
