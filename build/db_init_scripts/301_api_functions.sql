
/*
SCripts to create views in postgis_ftw schema that will be used by pg_featureserv API
*/

CREATE OR REPLACE VIEW postgis_ftw.ship
 AS
 SELECT DISTINCT ON (aa.mmsi) aa.mmsi,
    bb.bucket AS time_bucket,
    aa.imo,
    aa.callsign,
    dd.country AS flag,
    aa.name,
    aa.type_and_cargo,
    ee.type,
    ee.sub_type,
    aa.draught,
    bb."position"::geometry(Point,4326) AS geom,
    bb.cog,
    bb.sog,
    bb.nav_status,
    cc.description AS nav_description
   FROM ais.vessel_details_cagg aa
     LEFT JOIN ais.hourly_pos_cagg bb ON aa.mmsi = bb.mmsi
     LEFT JOIN ais.nav_status cc ON bb.nav_status = cc.nav_status
     LEFT JOIN ais.mid_to_country dd ON "left"(aa.mmsi, 3) = dd.mid::text
     LEFT JOIN ais.ais_num_to_type ee ON aa.type_and_cargo = ee.ais_num::text
  ORDER BY aa.mmsi, aa.bucket DESC;


COMMENT ON VIEW postgis_ftw.ship IS 'Find ship details based on MMSI.';

CREATE VIEW postgis_ftw.traj AS
SELECT 
	aa.mmsi,
	aa.bucket as date,
	aa.traj_start_time,
	aa.traj_end_time,
	aa.geom_length,
	aa.geom_sinuosity,
	aa.bucket_count,
	aa.geom::geometry(Linestring, 4326)
FROM ais.daily_30min_trajectories_cagg as aa
ORDER BY aa.bucket DESC;

COMMENT ON VIEW postgis_ftw.traj IS 'Find daily ship trajectories.';