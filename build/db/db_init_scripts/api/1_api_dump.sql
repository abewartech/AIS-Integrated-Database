
CREATE SCHEMA api_schema;
GRANT USAGE ON SCHEMA api_schema TO api_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA api_schema
GRANT SELECT ON TABLES TO api_user;

CREATE OR REPLACE FUNCTION api_schema.ais_geom_events(
	mmsi text,
	begin_time timestamp without time zone,
	end_time timestamp without time zone)
    RETURNS TABLE(mmsi text, geom_name character varying, geom_type character varying, geom_level integer, first_msg_in_geom timestamp with time zone, duration_at_geom interval, last_msg_in_geom timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$ 
 with flat_ais as 
(SELECT 
 	geoname as geom_name, 
 	level as geom_level,
 	pol_type as geom_type,
	mmsi,
 	ST_ASText(position), 
 	bucket as bucket_time,
 	cog,
 	sog,
	dense_rank() OVER (PARTITION BY level ORDER BY ais.event_time DESC) AS geom_rank,
	dense_rank() OVER (PARTITION BY level, geoname ORDER BY ais.event_time DESC) AS in_geom_rank,
 	event_time - lag(event_time) OVER (ORDER BY event_time) as time_to_next_msg
FROM ais.hourly_pos_cagg AS ais
JOIN geo.ocean_geom 
ON ST_Within(position, geom)
WHERE mmsi = $1
AND bucket BETWEEN $2 AND $3
ORDER BY bucket_time, geom_rank DESC
)
SELECT 
	mmsi,
	geom_name,
	geom_type,
	geom_level,
	last(bucket_time, in_geom_rank) as first_msg_in_geom,
	first(bucket_time, in_geom_rank) - last(bucket_time, in_geom_rank) as duration_in_geom,
	first(bucket_time, in_geom_rank) as last_msg_in_geom 
FROM flat_ais
GROUP BY geom_name, mmsi, geom_type, geom_level, (geom_rank - in_geom_rank)
ORDER BY last(bucket_time, in_geom_rank) ASC
$BODY$;

ALTER FUNCTION api_schema.ais_geom_events(text, timestamp without time zone, timestamp without time zone)
    OWNER TO rory;

GRANT EXECUTE ON FUNCTION api_schema.ais_geom_events(text, timestamp without time zone, timestamp without time zone) TO api_user;

GRANT EXECUTE ON FUNCTION api_schema.ais_geom_events(text, timestamp without time zone, timestamp without time zone) TO PUBLIC;

GRANT EXECUTE ON FUNCTION api_schema.ais_geom_events(text, timestamp without time zone, timestamp without time zone) TO rory;


-- FUNCTION: api_schema.fuzzy_name_search(text, integer)

-- DROP FUNCTION api_schema.fuzzy_name_search(text, integer);

CREATE OR REPLACE FUNCTION api_schema.fuzzy_name_search(
	fuzzy_name text,
	page_offset integer)
    RETURNS TABLE(mmsi text, imo text, name text, callsign text, to_bow smallint, to_stern smallint, to_port smallint, to_starboard smallint, type_and_cargo character varying, type_and_cargo_text text, flag_state text, routing_key text, event_time timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$

SELECT 
    aa.mmsi,
    aa.imo,
    aa.name,
    aa.callsign,
    aa.to_bow,
    aa.to_stern,
    aa.to_port,
    aa.to_starboard,
    aa.type_and_cargo,
    num.description AS type_and_cargo_text,
    mid.country AS flag_state,
    aa.routing_key,
    aa.event_time
   FROM ((ais.ship_details_agg as aa
     LEFT JOIN ais.ais_num_to_type num ON (((num.ais_num)::text = (aa.type_and_cargo)::text)))
     LEFT JOIN ais.mid_to_country mid ON (("left"(aa.mmsi, 3) = (mid.mid)::text)))
   WHERE SIMILARITY(name,$1) > 0.2 
  ORDER by SIMILARITY(name,$1) DESC
  limit 10 offset $2 
 
$BODY$;

ALTER FUNCTION api_schema.fuzzy_name_search(text, integer)
    OWNER TO rory;

GRANT EXECUTE ON FUNCTION api_schema.fuzzy_name_search(text, integer) TO api_user;

GRANT EXECUTE ON FUNCTION api_schema.fuzzy_name_search(text, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION api_schema.fuzzy_name_search(text, integer) TO rory;

CREATE OR REPLACE FUNCTION api_schema.port_history(
	mmsi text,
	begin_time timestamp without time zone,
	end_time timestamp without time zone)
    RETURNS TABLE(country character varying, port_name character varying, mmsi text, avg_speed_in_port numeric, duration_at_port interval, first_msg_in_port timestamp with time zone, last_msg_in_port timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$ 
 WITH flat_data AS (
         SELECT port.country,
            port.port_name,
            st_distance(st_setsrid(port.geom, 4326), st_setsrid(ais."position", 4326)) AS degree_distance_to_port,
            ais.mmsi,
            ais.sog,
            ais.event_time,
            dense_rank() OVER (ORDER BY ais.event_time DESC) AS port_rank,
            dense_rank() OVER (PARTITION BY port.port_name ORDER BY ais.event_time DESC) AS in_port_rank
           FROM ais.daily_pos_cagg ais
             JOIN LATERAL ( SELECT port_1.gid,
                    port_1.index_no,
                    port_1.region_no,
                    port_1.port_name,
                    port_1.country,
                    port_1.latitude,
                    port_1.longitude,
                    port_1.lat_deg,
                    port_1.lat_min,
                    port_1.lat_hemi,
                    port_1.long_deg,
                    port_1.long_min,
                    port_1.long_hemi,
                    port_1.pub,
                    port_1.chart,
                    port_1.harborsize,
                    port_1.harbortype,
                    port_1.shelter,
                    port_1.entry_tide,
                    port_1.entryswell,
                    port_1.entry_ice,
                    port_1.entryother,
                    port_1.overhd_lim,
                    port_1.chan_depth,
                    port_1.anch_depth,
                    port_1.cargodepth,
                    port_1.oil_depth,
                    port_1.tide_range,
                    port_1.max_vessel,
                    port_1.holdground,
                    port_1.turn_basin,
                    port_1.portofentr,
                    port_1.us_rep,
                    port_1.etamessage,
                    port_1.pilot_reqd,
                    port_1.pilotavail,
                    port_1.loc_assist,
                    port_1.pilotadvsd,
                    port_1.tugsalvage,
                    port_1.tug_assist,
                    port_1.pratique,
                    port_1.sscc_cert,
                    port_1.quar_other,
                    port_1.comm_phone,
                    port_1.comm_fax,
                    port_1.comm_radio,
                    port_1.comm_vhf,
                    port_1.comm_air,
                    port_1.comm_rail,
                    port_1.cargowharf,
                    port_1.cargo_anch,
                    port_1.cargmdmoor,
                    port_1.carbchmoor,
                    port_1.caricemoor,
                    port_1.med_facil,
                    port_1.garbage,
                    port_1.degauss,
                    port_1.drtyballst,
                    port_1.cranefixed,
                    port_1.cranemobil,
                    port_1.cranefloat,
                    port_1.lift_100_,
                    port_1.lift50_100,
                    port_1.lift_25_49,
                    port_1.lift_0_24,
                    port_1.longshore,
                    port_1.electrical,
                    port_1.serv_steam,
                    port_1.nav_equip,
                    port_1.elecrepair,
                    port_1.provisions,
                    port_1.water,
                    port_1.fuel_oil,
                    port_1.diesel,
                    port_1.decksupply,
                    port_1.eng_supply,
                    port_1.repaircode,
                    port_1.drydock,
                    port_1.railway,
                    port_1.geom
                   FROM geo.world_port_index port_1
                  ORDER BY (st_setsrid(port_1.geom, 4326) <-> ais."position")
                 LIMIT 1) port ON true
          WHERE ais.event_time BETWEEN $2 and $3 
	 	  AND ais.sog < 5::numeric AND st_distance(st_setsrid(port.geom, 4326), st_setsrid(ais."position", 4326)) < 0.2::double precision
	 	  AND  ais.mmsi = $1
          ORDER BY ais.event_time DESC
        )
 SELECT flat_data.country,
    flat_data.port_name,
    flat_data.mmsi,
    round(avg(flat_data.sog), 2) AS avg_speed_in_port,
    last(flat_data.event_time, flat_data.event_time) - first(flat_data.event_time, flat_data.event_time) AS duration_at_port,
    last(flat_data.event_time, flat_data.in_port_rank) AS last_msg_in_port,
    first(flat_data.event_time, flat_data.in_port_rank) AS first_msg_in_port
   FROM flat_data
  GROUP BY flat_data.country, flat_data.mmsi, flat_data.port_name, (flat_data.port_rank - flat_data.in_port_rank)
  ORDER BY (last(flat_data.event_time, flat_data.in_port_rank)) DESC
$BODY$;

ALTER FUNCTION api_schema.port_history(text, timestamp without time zone, timestamp without time zone)
    OWNER TO rory;

GRANT EXECUTE ON FUNCTION api_schema.port_history(text, timestamp without time zone, timestamp without time zone) TO api_user;

GRANT EXECUTE ON FUNCTION api_schema.port_history(text, timestamp without time zone, timestamp without time zone) TO PUBLIC;

GRANT EXECUTE ON FUNCTION api_schema.port_history(text, timestamp without time zone, timestamp without time zone) TO rory;

CREATE OR REPLACE FUNCTION api_schema.vessel_trajectory_daily(
	mmsi text,
	begin_time timestamp with time zone,
	end_time timestamp with time zone)
    RETURNS TABLE(mmsi text, traj geometry, traj_text text, traj_valid boolean, first_time timestamp with time zone, last_time timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$
WITH pos_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.daily_pos_cagg gps
	  WHERE gps.event_time BETWEEN $2 AND $3
	  AND gps.mmsi = $1
	LIMIT 1000)
 SELECT 
    gps.mmsi,
    ST_MakeValid(st_setsrid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326)) AS traj,
    st_astext(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_text,
    st_isvalidtrajectory(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_valid,
    first(gps.event_time, gps.event_time) AS first_time,
    last(gps.event_time, gps.event_time) AS last_time
   FROM pos_data as gps
  WHERE gps.event_time BETWEEN $2 AND $3
  AND gps.mmsi = $1
  GROUP BY gps.mmsi; 
$BODY$;

ALTER FUNCTION api_schema.vessel_trajectory_daily(text, timestamp with time zone, timestamp with time zone)
    OWNER TO rory;

CREATE OR REPLACE FUNCTION api_schema.vessel_trajectory_hourly(
	mmsi text,
	begin_time timestamp with time zone,
	end_time timestamp with time zone)
    RETURNS TABLE(mmsi text, traj geometry, traj_text text, traj_valid boolean, first_time timestamp with time zone, last_time timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$
WITH pos_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.hourly_pos_cagg gps
	  WHERE gps.event_time BETWEEN $2 AND $3
	  AND gps.mmsi = $1
	LIMIT 1000)
 SELECT 
    gps.mmsi,
    ST_MakeValid(st_setsrid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326)) AS traj,
    st_astext(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_text,
    st_isvalidtrajectory(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_valid,
    first(gps.event_time, gps.event_time) AS first_time,
    last(gps.event_time, gps.event_time) AS last_time
   FROM pos_data as gps
  WHERE gps.event_time BETWEEN $2 AND $3
  AND gps.mmsi = $1
  GROUP BY gps.mmsi; 
$BODY$;

ALTER FUNCTION api_schema.vessel_trajectory_hourly(text, timestamp with time zone, timestamp with time zone)
    OWNER TO rory;

CREATE OR REPLACE FUNCTION api_schema.vessel_trajectory_mixed(
	mmsi text,
	begin_time timestamp with time zone,
	end_time timestamp with time zone)
    RETURNS TABLE(mmsi text, traj geometry, traj_text text, traj_valid boolean, first_time timestamp with time zone, last_time timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$
WITH raw_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.pos_reports gps
	  WHERE gps.event_time BETWEEN $2 AND $3
	  AND gps.mmsi = $1
	LIMIT 100),
	
	hourly_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.hourly_pos_cagg gps
	   INNER JOIN 
	 	(SELECT mmsi, last(raw_data.event_time, raw_data.event_time) as max_time  FROM raw_data GROUP BY mmsi) as grouped_raw
	  ON grouped_raw.mmsi = gps.mmsi
	  WHERE gps.event_time BETWEEN grouped_raw.max_time AND $3
	  AND gps.mmsi = $1
	LIMIT 100),
	
	daily_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.daily_pos_cagg gps
	  INNER JOIN 
	 	(SELECT mmsi, last(hourly_data.event_time, hourly_data.event_time) as max_time  FROM hourly_data GROUP BY mmsi) as grouped_raw
	  ON grouped_raw.mmsi = gps.mmsi
	  WHERE gps.event_time BETWEEN grouped_raw.max_time AND $3 
	  AND gps.mmsi = $1
	LIMIT 800),
	
	pos_data as
	(SELECT * FROM raw_data
	 UNION ALL
	 SELECT * FROM hourly_data
	 UNION ALL
	 SELECT * FROM daily_data
	)
	
 SELECT 
    gps.mmsi,
    ST_MakeValid(st_setsrid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326)) AS traj,
    st_astext(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_text,
    st_isvalidtrajectory(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_valid,
    first(gps.event_time, gps.event_time) AS first_time,
    last(gps.event_time, gps.event_time) AS last_time
   FROM pos_data as gps
  WHERE gps.event_time BETWEEN $2 AND $3
  AND gps.mmsi = $1
  GROUP BY gps.mmsi; 
$BODY$;

ALTER FUNCTION api_schema.vessel_trajectory_mixed(text, timestamp with time zone, timestamp with time zone)
    OWNER TO rory;


CREATE OR REPLACE FUNCTION api_schema.vessel_trajectory_mixed(
	mmsi text,
	begin_time timestamp with time zone,
	end_time timestamp with time zone)
    RETURNS TABLE(mmsi text, traj geometry, traj_text text, traj_valid boolean, first_time timestamp with time zone, last_time timestamp with time zone) 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
    
AS $BODY$
WITH raw_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.pos_reports gps
	  WHERE gps.event_time BETWEEN $2 AND $3
	  AND gps.mmsi = $1
	LIMIT 100),
	
	hourly_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.hourly_pos_cagg gps
	   INNER JOIN 
	 	(SELECT mmsi, last(raw_data.event_time, raw_data.event_time) as max_time  FROM raw_data GROUP BY mmsi) as grouped_raw
	  ON grouped_raw.mmsi = gps.mmsi
	  WHERE gps.event_time BETWEEN grouped_raw.max_time AND $3
	  AND gps.mmsi = $1
	LIMIT 100),
	
	daily_data as 
	(SELECT 
		gps.mmsi,
		gps."position",
		gps.event_time
	   FROM ais.daily_pos_cagg gps
	  INNER JOIN 
	 	(SELECT mmsi, last(hourly_data.event_time, hourly_data.event_time) as max_time  FROM hourly_data GROUP BY mmsi) as grouped_raw
	  ON grouped_raw.mmsi = gps.mmsi
	  WHERE gps.event_time BETWEEN grouped_raw.max_time AND $3 
	  AND gps.mmsi = $1
	LIMIT 800),
	
	pos_data as
	(SELECT * FROM raw_data
	 UNION ALL
	 SELECT * FROM hourly_data
	 UNION ALL
	 SELECT * FROM daily_data
	)
	
 SELECT 
    gps.mmsi,
    ST_MakeValid(st_setsrid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326)) AS traj,
    st_astext(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_text,
    st_isvalidtrajectory(ST_MakeValid(st_makeline(st_makepoint(st_x(gps."position"), st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time))) AS traj_valid,
    first(gps.event_time, gps.event_time) AS first_time,
    last(gps.event_time, gps.event_time) AS last_time
   FROM pos_data as gps
  WHERE gps.event_time BETWEEN $2 AND $3
  AND gps.mmsi = $1
  GROUP BY gps.mmsi; 
$BODY$;

ALTER FUNCTION api_schema.vessel_trajectory_mixed(text, timestamp with time zone, timestamp with time zone) OWNER TO rory;

