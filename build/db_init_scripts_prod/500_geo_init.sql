CREATE SCHEMA IF NOT EXISTS geo;
CREATE EXTENSION IF NOT EXISTS postgis;


-----------------------------------------------------------------------
-- Create some helper funcs and build up a global grid
--RAISE NOTICE 'Create grid function and create 10x10km global grid';


BEGIN;
CREATE OR REPLACE FUNCTION ST_CreateFishnet(
        nrow integer, ncol integer,
        xsize float8, ysize float8,
        x0 float8 DEFAULT 0, y0 float8 DEFAULT 0,
        OUT "row" integer, OUT col integer,
        OUT geom geometry)
    RETURNS SETOF record AS
$$
SELECT i + 1 AS row, j + 1 AS col, ST_Translate(cell, j * $3 + $5, i * $4 + $6) AS geom
FROM generate_series(0, $1 - 1) AS i,
     generate_series(0, $2 - 1) AS j,
(
SELECT ('POLYGON((0 0, 0 '||$4||', '||$3||' '||$4||', '||$3||' 0,0 0))')::geometry AS cell
) AS foo;
$$ LANGUAGE sql IMMUTABLE STRICT;


-- No real nead for this. 
-- 
-- CREATE TABLE geo.world_100km_grid AS
--   SELECT *
--   FROM ST_CreateFishnet(3600, 1800, 0.01, 0.01,-180,-90) AS cells;

-- CREATE INDEX grid_10km_index_geom
--    ON geo.world_10km_grid USING gist
--    (geom);

COMMIT;
