
/*
██████╗░███████╗██████╗░██████╗░███████╗░█████╗░░█████╗░████████╗███████╗██████╗░
██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗
██║░░██║█████╗░░██████╔╝██████╔╝█████╗░░██║░░╚═╝███████║░░░██║░░░█████╗░░██║░░██║
██║░░██║██╔══╝░░██╔═══╝░██╔══██╗██╔══╝░░██║░░██╗██╔══██║░░░██║░░░██╔══╝░░██║░░██║
██████╔╝███████╗██║░░░░░██║░░██║███████╗╚█████╔╝██║░░██║░░░██║░░░███████╗██████╔╝
╚═════╝░╚══════╝╚═╝░░░░░╚═╝░░╚═╝╚══════╝░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░╚══════╝╚═════╝░
*/

-- FUNCTION: ais.acoustic_impact(numeric, numeric, numeric, timestamp with time zone, timestamp with time zone)

-- DROP FUNCTION IF EXISTS ais.acoustic_impact(numeric, numeric, numeric, timestamp with time zone, timestamp with time zone);

CREATE OR REPLACE FUNCTION ais.acoustic_impact(
	lon numeric,
	lat numeric,
	buffer_meters numeric DEFAULT 1000,
	start_time timestamp with time zone DEFAULT (CURRENT_TIMESTAMP - '00:10:00'::interval),
	end_time timestamp with time zone DEFAULT (CURRENT_TIMESTAMP - '00:05:00'::interval))
    RETURNS TABLE("MMSI" text, "Time Delta" double precision, "Segment Start Time" timestamp with time zone, "Segment End Time" timestamp with time zone, "SOG" numeric, "Segment" geometry, "Segment Length" double precision, "Distance to Center" double precision, "Vessel Name" text, "To Bow" smallint, "To Stern" smallint, "To Port" smallint, "To Starboard" smallint, "TypeAndCargo" text, "Cargo Class" text, "Cargo SubClass" text) 
    LANGUAGE 'sql'
    COST 100
    VOLATILE PARALLEL SAFE 
    ROWS 1000

AS $BODY$
WITH 
-- Create Area of Interest from point and buffer
aoi as
  (SELECT ST_SetSRID(ST_Point($1,$2),4326) as point_geom,
   ST_Transform(ST_Buffer(ST_Transform(ST_SetSRID(ST_Point($1,$2),4326),3857),$3),4326) as geom),
  voi as
  (SELECT
    mmsi,
    event_time as time1,
    date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) AS delta_secs,
    position as pos1,
    sog,
    lead(ais."position") OVER time_order AS pos2,
    lead(ais.event_time) OVER time_order AS time2
  FROM ais.pos_reports as ais, aoi
  WHERE event_time > $4
  AND event_time < $5
  AND ST_Within(position, ST_Buffer(aoi.geom,0.2))
  WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)
  )
-- Find segments where the start or end point are inside the AOI
SELECT
  voi.mmsi,
  delta_secs,
  voi.time1,
  voi.time2,
  sog,
  ST_SetSRID(st_makeline(voi.pos1, voi.pos2),4326) AS segment_geom,
--   ST_AsText(st_makeline(voi.pos1, voi.pos2)) AS segment_WKT,
  ST_distance(ST_Transform(voi.pos1,3857), ST_Transform(voi.pos2,3857)) AS segment_length,
  ST_Distance(ST_Transform(aoi.point_geom,3857), ST_Transform(ST_SetSRID(st_makeline(voi.pos1, voi.pos2),4326),3857)) as dist_to_sensor,
  det.name,
  det.to_bow,
  det.to_stern,
  det.to_port,
  det.to_starboard,
  det.type_and_cargo,
  typ.type,
  typ.sub_type
FROM  aoi,voi
LEFT JOIN ais.latest_voy_reports as det
ON voi.mmsi = det.mmsi
LEFT JOIN ais.ais_num_to_type as typ
ON typ.ais_num = det.type_and_cargo
WHERE (ST_Within(pos1, aoi.geom) OR ST_Within(pos2, aoi.geom))
AND delta_secs > 0
AND delta_secs is not Null
$BODY$;