-- Migration: Add spatial index on places.location for efficient ST_Contains queries
-- This enables accurate filtering of places within SA2 region boundaries

-- Create spatial index on places.location (GIST index for geometry)
CREATE INDEX IF NOT EXISTS idx_places_location_gist 
ON places USING GIST (location);

-- Also ensure regions.geometry has a spatial index (should already exist, but just in case)
CREATE INDEX IF NOT EXISTS idx_regions_geometry_gist 
ON regions USING GIST (geometry);

-- Analyze tables to update query planner statistics
ANALYZE places;
ANALYZE regions;
