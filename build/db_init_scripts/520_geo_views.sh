#!/bin/bash
# set -e

# Check if FETCH_GEOM environment variable exists
# and is anything other than "false"
run_script="${FETCH_GEOM:-False}"
if [ $run_script = "False" ]; then
   echo "--- Skipping all GEOM Views..."
   exit 0
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL


CREATE MATERIALIZED VIEW IF NOT EXISTS geo.maritime_boundaries
TABLESPACE pg_default
AS
 WITH z0a AS (
         SELECT st_setsrid(st_simplify(oceans_world.geom, 0.001::double precision), 4326) AS geom,
            oceans_world.name AS geoname,
            'ocean'::text AS pol_type,
            'ocean'::text AS territory,
            NULL::text AS iso_ter,
            0 AS level
           FROM geo.oceans_world
        ), z0b AS (
         SELECT st_setsrid(st_simplify(admin_0_countries.geom, 0.001::double precision), 4326) AS geom,
            admin_0_countries.sovereignt AS geoname,
            admin_0_countries.type AS pol_type,
            admin_0_countries.brk_name AS territory,
            admin_0_countries.adm0_a3 AS iso_ter,
            0 AS level
           FROM geo.admin_0_countries
        ), z2a AS (
         SELECT st_setsrid(st_simplify(eez_12nm.geom, 0.001::double precision), 4326) AS geom,
            eez_12nm.geoname,
            eez_12nm.pol_type,
            eez_12nm.territory1 AS territory,
            eez_12nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_12nm
        ), z2b AS (
         SELECT st_setsrid(st_simplify(eez_24nm.geom, 0.001::double precision), 4326) AS geom,
            eez_24nm.geoname,
            eez_24nm.pol_type,
            eez_24nm.territory1 AS territory,
            eez_24nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_24nm
        ), z2c AS (
         SELECT st_setsrid(st_simplify(eez_archipelagic_waters.geom, 0.001::double precision), 4326) AS geom,
            eez_archipelagic_waters.geoname,
            eez_archipelagic_waters.pol_type,
            eez_archipelagic_waters.territory1 AS territory,
            eez_archipelagic_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_archipelagic_waters
        ), z2d AS (
         SELECT st_setsrid(st_simplify(eez_internal_waters.geom, 0.001::double precision), 4326) AS geom,
            eez_internal_waters.geoname,
            eez_internal_waters.pol_type,
            eez_internal_waters.territory1 AS territory,
            eez_internal_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_internal_waters
        ), z1a AS (
         SELECT st_setsrid(st_simplify(world_eez.geom, 0.001::double precision), 4326) AS geom,
            world_eez.geoname,
            world_eez.pol_type,
            world_eez.territory1 AS territory,
            world_eez.iso_ter1 AS iso_ter,
            1 AS level
           FROM geo.world_eez
        ), z_all AS (
         SELECT z0a.geom,
            z0a.geoname,
            z0a.pol_type,
            z0a.territory,
            z0a.iso_ter,
            z0a.level
           FROM z0a
        UNION ALL
         SELECT z0b.geom,
            z0b.geoname,
            z0b.pol_type,
            z0b.territory,
            z0b.iso_ter,
            z0b.level
           FROM z0b
        UNION ALL
         SELECT z1a.geom,
            z1a.geoname,
            z1a.pol_type,
            z1a.territory,
            z1a.iso_ter,
            z1a.level
           FROM z1a
        UNION ALL
         SELECT z2a.geom,
            z2a.geoname,
            z2a.pol_type,
            z2a.territory,
            z2a.iso_ter,
            z2a.level
           FROM z2a
        UNION ALL
         SELECT z2b.geom,
            z2b.geoname,
            z2b.pol_type,
            z2b.territory,
            z2b.iso_ter,
            z2b.level
           FROM z2b
        UNION ALL
         SELECT z2c.geom,
            z2c.geoname,
            z2c.pol_type,
            z2c.territory,
            z2c.iso_ter,
            z2c.level
           FROM z2c
        UNION ALL
         SELECT z2d.geom,
            z2d.geoname,
            z2d.pol_type,
            z2d.territory,
            z2d.iso_ter,
            z2d.level
           FROM z2d
        )
 SELECT row_number() OVER () AS gid,
    st_setsrid(z_all.geom, 4326)::geometry(MultiPolygon,4326) AS geom,
    z_all.geoname,
    z_all.pol_type,
    z_all.territory,
    z_all.iso_ter,
    z_all.level
   FROM z_all
WITH DATA;
 
COMMENT ON MATERIALIZED VIEW geo.maritime_boundaries
    IS 'Maritime boundaries ordered by level, similar to administrative divisions on land.';
 
CREATE INDEX maritime_boundaries_geom_idx
    ON geo.maritime_boundaries USING gist
    (geom)
    TABLESPACE pg_default;


EOSQL
