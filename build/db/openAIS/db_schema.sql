--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3 (Debian 13.3-1.pgdg100+1)
-- Dumped by pg_dump version 13.7 (Ubuntu 13.7-0ubuntu0.21.10.1)

-- Started on 2023-03-21 11:30:20 EDT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7422 (class 1262 OID 16384)
-- Name: vessels; Type: DATABASE; Schema: -; Owner: vliz
--

CREATE DATABASE vessels WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C.UTF-8';


ALTER DATABASE vessels OWNER TO vliz;

\connect vessels

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 3079 OID 17402)
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- TOC entry 7425 (class 0 OID 0)
-- Dependencies: 5
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data';


--
-- TOC entry 14 (class 2615 OID 16386)
-- Name: ais; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA ais;


ALTER SCHEMA ais OWNER TO vliz;

--
-- TOC entry 21 (class 2615 OID 16385)
-- Name: geo; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA geo;


ALTER SCHEMA geo OWNER TO vliz;

--
-- TOC entry 19 (class 2615 OID 17550719)
-- Name: geoserver; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA geoserver;


ALTER SCHEMA geoserver OWNER TO vliz;

--
-- TOC entry 7428 (class 0 OID 0)
-- Dependencies: 19
-- Name: SCHEMA geoserver; Type: COMMENT; Schema: -; Owner: vliz
--

COMMENT ON SCHEMA geoserver IS 'This schema is intended for views that are published via geoserver. ';


--
-- TOC entry 17 (class 2615 OID 24613)
-- Name: postgisftw; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA postgisftw;


ALTER SCHEMA postgisftw OWNER TO vliz;

--
-- TOC entry 20 (class 2615 OID 52043)
-- Name: rory; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA rory;


ALTER SCHEMA rory OWNER TO vliz;

--
-- TOC entry 7431 (class 0 OID 0)
-- Dependencies: 20
-- Name: SCHEMA rory; Type: COMMENT; Schema: -; Owner: vliz
--

COMMENT ON SCHEMA rory IS 'This is a place for Rory to work out sql and views before placing them into a production schema.';


--
-- TOC entry 16 (class 2615 OID 23014250)
-- Name: schelde; Type: SCHEMA; Schema: -; Owner: vliz
--

CREATE SCHEMA schelde;


ALTER SCHEMA schelde OWNER TO vliz;

--
-- TOC entry 7433 (class 0 OID 0)
-- Dependencies: 16
-- Name: SCHEMA schelde; Type: COMMENT; Schema: -; Owner: vliz
--

COMMENT ON SCHEMA schelde IS 'Schema to hold products and R&D for schelde monitoring project';


--
-- TOC entry 4 (class 3079 OID 174113)
-- Name: timescaledb_toolkit; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit WITH SCHEMA public;


--
-- TOC entry 7434 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION timescaledb_toolkit; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION timescaledb_toolkit IS 'timescaledb_toolkit';


--
-- TOC entry 3 (class 3079 OID 73210)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 7435 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 2 (class 3079 OID 16387)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 7436 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- TOC entry 1666 (class 1255 OID 5913574)
-- Name: ais_aggregation_1km_full(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: ais; Owner: vliz
--

CREATE FUNCTION ais.ais_aggregation_1km_full(begin_time timestamp without time zone, end_time timestamp without time zone) RETURNS TABLE(gid double precision, event_date date, type_and_cargo character varying, cardinal_seg numeric, sog_bin numeric, track_count bigint, avg_time_delta double precision, cum_time_in_grid double precision)
    LANGUAGE sql ROWS 1e+06 PARALLEL SAFE
    AS $_$
  
 SELECT 
    grid.gid,
    traj.event_date, 
    det.type_and_cargo, 
	trunc((mod(traj.cog + 22.5, 360) / (45)::numeric)) AS cardinal_seg,
	FLOOR(traj.sog) AS sog_bin,
	count(traj.traj) AS track_count,
    avg(traj.time_delta) AS avg_time_delta,
    sum(((st_length(st_intersection(traj.traj, grid.geom)) * traj.time_delta) / traj.traj_dist)) AS cum_time_in_grid
   FROM ((rory.aoi_hex_grid_1km2 grid
     LEFT JOIN ( SELECT subquery.mmsi,
            subquery.event_date,
            subquery.cog,
            subquery.sog,
            subquery.time_delta,
            st_makeline(subquery.pos, subquery.pos2) AS traj,
            st_distance(subquery.pos, subquery.pos2) AS traj_dist
           FROM ( SELECT ais.mmsi,
                    date(ais.event_time) AS event_date,
                    date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) AS time_delta,
                    ais."position" AS pos,
                    NULLIF(ais.sog, 102.3) AS sog,
                    NULLIF(ais.cog, 360.0) AS cog,
                    ais.navigation_status,
                    lead(ais."position") OVER time_order AS pos2
                   FROM ais.pos_reports ais
 WHERE ((ais.event_time >= $1) 
	  AND (ais.event_time <= $2))
                  WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)) subquery
          WHERE (subquery.pos2 IS NOT NULL)) traj ON (st_intersects(traj.traj, grid.geom)))
     LEFT JOIN ais.latest_voy_reports det ON ((traj.mmsi = det.mmsi)))
  WHERE ((traj.traj_dist > (0)::double precision) AND (traj.time_delta > (0)::double precision) AND (traj.traj_dist < (0.05)::double precision))
  GROUP BY grid.gid, det.type_and_cargo, traj.event_date, FLOOR(traj.sog), trunc((mod(traj.cog + 22.5, 360) / (45)::numeric))
 
$_$;


ALTER FUNCTION ais.ais_aggregation_1km_full(begin_time timestamp without time zone, end_time timestamp without time zone) OWNER TO vliz;

--
-- TOC entry 1523 (class 1255 OID 127712)
-- Name: build_trajectories(integer, jsonb); Type: PROCEDURE; Schema: ais; Owner: vliz
--

CREATE PROCEDURE ais.build_trajectories(job_id integer, config jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
  WITH lead_lag AS (
         SELECT ais.mmsi,
            ais."position",
            ais.event_time,
            ais.sog,
            lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time) <= (ais.event_time - '01:00:00'::interval) AS time_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) < 0::double precision OR st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) > 0.1::double precision AS dist_step,
            (st_distancesphere(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) / NULLIF(date_part('epoch'::text, ais.event_time - lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)), 0::double precision)) >= (2::numeric * (ais.sog + 0.5))::double precision AS sog_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) AS dist
           FROM ais.pos_reports ais
          WHERE ais.event_time >= date(now()) - interval '1 day' AND ais.event_time <= date(now()) 
        ), lead_lag_groups AS (
         SELECT lead_lag_1.mmsi,
            lead_lag_1."position",
            lead_lag_1.event_time,
            lead_lag_1.sog,
            lead_lag_1.time_step,
            lead_lag_1.dist_step,
            lead_lag_1.dist,
            lead_lag_1.sog_step,
            count(*) FILTER (WHERE lead_lag_1.time_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS time_grp,
            count(*) FILTER (WHERE lead_lag_1.dist_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS dist_grp,
            count(*) FILTER (WHERE lead_lag_1.sog_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS sog_grp
           FROM lead_lag lead_lag_1
          WHERE lead_lag_1.dist > 0::double precision
        )
	  INSERT INTO ais.trajectories 
 SELECT 
		  lead_lag.mmsi,
		lead_lag.time_grp,
		lead_lag.dist_grp,
		lead_lag.sog_grp,
		first(lead_lag.event_time, lead_lag.event_time) AS first_time,
		last(lead_lag.event_time, lead_lag.event_time) AS last_time,
		st_length(st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS geom_length,
		st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326) AS geom
	   FROM lead_lag_groups lead_lag 
  GROUP BY lead_lag.mmsi, lead_lag.time_grp, lead_lag.dist_grp, lead_lag.sog_grp;
END
$$;


ALTER PROCEDURE ais.build_trajectories(job_id integer, config jsonb) OWNER TO vliz;

--
-- TOC entry 1672 (class 1255 OID 18795716)
-- Name: create_yesterday_density(integer, jsonb); Type: PROCEDURE; Schema: ais; Owner: vliz
--

CREATE PROCEDURE ais.create_yesterday_density(job_id integer, config jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
INSERT INTO ais.vessel_density_agg
SELECT 
    ais_heatmap.gid,
    ais_heatmap.event_date, 
    ais_heatmap.type_and_cargo,
    ais_heatmap.cardinal_seg,
    ais_heatmap.sog_bin,
    ais_heatmap.track_count, 
    ais_heatmap.avg_time_delta,
    ais_heatmap.cum_time_in_grid
   FROM ais.ais_aggregation_1km_full((current_date - INTERVAL '2 day')::date,
									 (current_date - INTERVAL '1 day')::date) as ais_heatmap ;
END
$$;


ALTER PROCEDURE ais.create_yesterday_density(job_id integer, config jsonb) OWNER TO vliz;

--
-- TOC entry 1524 (class 1255 OID 129969)
-- Name: vessel_details_upsert_func(); Type: FUNCTION; Schema: ais; Owner: vliz
--

CREATE FUNCTION ais.vessel_details_upsert_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ais.latest_voy_reports AS aa 
	VALUES(NEW.mmsi,
		   NEW.imo,
		   NEW.callsign,
		   NEW.name,
		   NEW.type_and_cargo,
		   NEW.to_bow,
		   NEW.to_stern,
		   NEW.to_port,
		   NEW.to_starboard,
		   NEW.fix_type,
		   NEW.eta_month,
		   NEW.eta_day,
		   NEW.eta_hour, 
		   NEW.eta_minute,
		   NEW.eta,
		   NEW.draught,
		   NEW.destination,
		   NEW.server_time,
		   NEW.event_time,
		   NEW.msg_type,
		   NEW.routing_key)
	ON CONFLICT (mmsi, routing_key)
	DO UPDATE SET 
		mmsi = COALESCE(EXCLUDED.mmsi, aa.mmsi), 
		imo = COALESCE(EXCLUDED.imo, aa.imo),
		callsign= COALESCE(EXCLUDED.callsign, aa.callsign),
		name= COALESCE(EXCLUDED.name, aa.name),
		type_and_cargo= COALESCE(EXCLUDED.type_and_cargo, aa.type_and_cargo),
		to_bow= COALESCE(EXCLUDED.to_bow, aa.to_bow),
		to_stern= COALESCE(EXCLUDED.to_stern, aa.to_stern),
		to_port= COALESCE(EXCLUDED.to_port, aa.to_port),
		to_starboard= COALESCE(EXCLUDED.to_starboard, aa.to_starboard),
		fix_type= COALESCE(EXCLUDED.fix_type, aa.fix_type),
		eta_month= COALESCE(EXCLUDED.eta_month, aa.eta_month),
		eta_day= COALESCE(EXCLUDED.eta_day, aa.eta_day),
		eta_hour = COALESCE(EXCLUDED.eta_hour, aa.eta_hour),
		eta_minute = COALESCE(EXCLUDED.eta_minute, aa.eta_minute),
		eta = COALESCE(EXCLUDED.eta, aa.eta),
		draught = COALESCE(EXCLUDED.draught, aa.draught),
		destination = COALESCE(EXCLUDED.destination, aa.destination),
		server_time = COALESCE(EXCLUDED.server_time, aa.server_time),
		event_time = COALESCE(EXCLUDED.event_time, aa.event_time),
		msg_type = COALESCE(EXCLUDED.msg_type, aa.msg_type),
		routing_key = COALESCE(EXCLUDED.routing_key, aa.routing_key);
RETURN NEW;
END;
$$;


ALTER FUNCTION ais.vessel_details_upsert_func() OWNER TO vliz;

--
-- TOC entry 1669 (class 1255 OID 7148651)
-- Name: acoustic_impact(numeric, numeric, numeric, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.acoustic_impact(lon numeric, lat numeric, buffer_meters numeric DEFAULT 1000, start_time timestamp with time zone DEFAULT (CURRENT_TIMESTAMP - '00:10:00'::interval), end_time timestamp with time zone DEFAULT (CURRENT_TIMESTAMP - '00:05:00'::interval)) RETURNS TABLE("MMSI" text, "Time Delta" double precision, "Segment Start Time" timestamp with time zone, "Segment End Time" timestamp with time zone, "SOG" numeric, "Segment" public.geometry, "Segment Length" double precision, "Distance to Center" double precision, "Vessel Name" text, "To Bow" smallint, "To Stern" smallint, "To Port" smallint, "To Starboard" smallint, "TypeAndCargo" text, "Cargo Class" text, "Cargo SubClass" text)
    LANGUAGE sql PARALLEL SAFE
    AS $_$
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
$_$;


ALTER FUNCTION postgisftw.acoustic_impact(lon numeric, lat numeric, buffer_meters numeric, start_time timestamp with time zone, end_time timestamp with time zone) OWNER TO vliz;

--
-- TOC entry 1487 (class 1255 OID 73205)
-- Name: ais_geom_events(timestamp without time zone, timestamp without time zone, text); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.ais_geom_events(start_time timestamp without time zone DEFAULT '2020-01-01'::date, end_time timestamp without time zone DEFAULT '2020-02-01'::date, input_mmsi text DEFAULT '601986000'::text) RETURNS TABLE(mmsi text, geom_name character varying, geom_type character varying, geom_level integer, first_msg_in_geom timestamp with time zone, duration_at_geom interval, last_msg_in_geom timestamp with time zone)
    LANGUAGE sql
    AS $_$ 
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
FROM ais.pos_reports_1h_cagg AS ais
JOIN geo.levels 
ON ST_Within(position, geom)
WHERE mmsi = $3
AND bucket BETWEEN $1 AND $2
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
$_$;


ALTER FUNCTION postgisftw.ais_geom_events(start_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text) OWNER TO vliz;

--
-- TOC entry 7437 (class 0 OID 0)
-- Dependencies: 1487
-- Name: FUNCTION ais_geom_events(start_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.ais_geom_events(start_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text) IS 'Return the human readable geometery events for vessel <MMSI> between the start and end dates.';


--
-- TOC entry 1519 (class 1255 OID 73289)
-- Name: fuzzy_name_search(text); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.fuzzy_name_search(fuzzy_name text) RETURNS TABLE(mmsi text, imo text, name text, callsign text, to_bow smallint, to_stern smallint, to_port smallint, to_starboard smallint, type_and_cargo character varying, type_and_cargo_text text, flag_state text, routing_key text, event_time timestamp with time zone)
    LANGUAGE sql
    AS $_$

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
    aa.bucket
   FROM ((ais.latest_vessel_details as aa
     LEFT JOIN ais.ais_num_to_type num ON (((num.ais_num)::text = (aa.type_and_cargo)::text)))
     LEFT JOIN ais.mid_to_country mid ON (("left"(aa.mmsi, 3) = (mid.mid)::text)))
   WHERE SIMILARITY(name,$1) > 0.2 
  ORDER by SIMILARITY(name,$1) DESC 
 
$_$;


ALTER FUNCTION postgisftw.fuzzy_name_search(fuzzy_name text) OWNER TO vliz;

--
-- TOC entry 7438 (class 0 OID 0)
-- Dependencies: 1519
-- Name: FUNCTION fuzzy_name_search(fuzzy_name text); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.fuzzy_name_search(fuzzy_name text) IS 'Tries to match details of a vessel to the input name by a fuzzy string search.';


--
-- TOC entry 1520 (class 1255 OID 73294)
-- Name: port_history(timestamp without time zone, timestamp without time zone, text); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.port_history(begin_time timestamp without time zone DEFAULT '2020-01-01'::date, end_time timestamp without time zone DEFAULT '2020-02-01'::date, input_mmsi text DEFAULT '601986000'::text) RETURNS TABLE(country character varying, port_name character varying, mmsi text, avg_speed_in_port numeric, duration_at_port interval, first_msg_in_port timestamp with time zone, last_msg_in_port timestamp with time zone)
    LANGUAGE sql
    AS $_$ 
 WITH flat_data AS (
         SELECT port.country,
            port.port_name,
            st_distance(st_setsrid(port.geom, 4326), st_setsrid(ais."position", 4326)) AS degree_distance_to_port,
            ais.mmsi,
            ais.sog,
            ais.event_time,
            dense_rank() OVER (ORDER BY ais.event_time DESC) AS port_rank,
            dense_rank() OVER (PARTITION BY port.port_name ORDER BY ais.event_time DESC) AS in_port_rank
           FROM ais.pos_reports_1h_cagg ais
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
          WHERE ais.event_time BETWEEN $1 and $2 
	 	  AND ais.sog < 5::numeric AND st_distance(st_setsrid(port.geom, 4326), st_setsrid(ais."position", 4326)) < 0.2::double precision
	 	  AND  ais.mmsi = $3
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
$_$;


ALTER FUNCTION postgisftw.port_history(begin_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text) OWNER TO vliz;

--
-- TOC entry 7439 (class 0 OID 0)
-- Dependencies: 1520
-- Name: FUNCTION port_history(begin_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.port_history(begin_time timestamp without time zone, end_time timestamp without time zone, input_mmsi text) IS 'Return a list of ports visited by vessel <MMSI> between the start and end timestamps.';


--
-- TOC entry 1671 (class 1255 OID 14693022)
-- Name: priors(numeric, numeric, date, integer); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.priors(lon numeric DEFAULT 1.61, lat numeric DEFAULT 51.05, end_time date DEFAULT '2022-02-01'::date, days_window integer DEFAULT 1) RETURNS TABLE(gid double precision, event_date date, type_and_cargo character varying, class character varying, cardinal_seg numeric, sog_bin numeric, track_count bigint, avg_time_delta double precision, cum_time_in_grid double precision, geom public.geometry)
    LANGUAGE sql PARALLEL SAFE
    AS $_$
with cell_of_interest as 
	(SELECT 
	 	gid, 
	 	geom 
	 FROM rory.aoi_hex_grid_1km2
	 WHERE ST_WITHIN(ST_SetSRID(ST_MakePoint($1, $2),4326), geom)
	 )

SELECT 
	ais_agg_ver2.gid ,
	ais_agg_ver2.event_date ,
	ais_agg_ver2.type_and_cargo ,
	cc.type as class,
	ais_agg_ver2.cardinal_seg ,
	ais_agg_ver2.sog_bin ,
	ais_agg_ver2.track_count ,
	ais_agg_ver2.avg_time_delta ,
	ais_agg_ver2.cum_time_in_grid ,
	cell_of_interest. geom as geom
FROM cell_of_interest LEFT JOIN rory.ais_agg_ver2
ON cell_of_interest.gid = ais_agg_ver2.gid
LEFT JOIN ais.ais_num_to_type as cc
ON ais_agg_ver2.type_and_cargo = cc.ais_num
WHERE event_date BETWEEN $3::timestamp - ($4::text ||' days')::INTERVAL AND  $3::timestamp
$_$;


ALTER FUNCTION postgisftw.priors(lon numeric, lat numeric, end_time date, days_window integer) OWNER TO vliz;

--
-- TOC entry 7440 (class 0 OID 0)
-- Dependencies: 1671
-- Name: FUNCTION priors(lon numeric, lat numeric, end_time date, days_window integer); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.priors(lon numeric, lat numeric, end_time date, days_window integer) IS 'Get prior aggregate for position (<lon>, <lat>, SRID: 4326) between <end_date> and <end_date> - <days_window>.';


--
-- TOC entry 1670 (class 1255 OID 7834571)
-- Name: vessel_details(text); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.vessel_details(mmsi text) RETURNS TABLE("MMSI" text, "IMO" text, "Callsign" text, "Name" text, "AIS Cargo Code" text, "AIS Cargo Class" text, "AIS Cargo SubClass" text, "Length" text, "Width" text, "Destination" text, "Message Time" timestamp with time zone, "Data Source" text, history public.geometry)
    LANGUAGE sql
    AS $_$
SELECT 
    pos.mmsi AS "MMSI",
    last(replace(voy.imo, '@'::text, ''::text), voy.event_time) AS "IMO",
    last(replace(voy.callsign, '@'::text, ''::text), voy.event_time) AS "Callsign",
    last(replace(voy.name, '@'::text, ''::text), voy.event_time) AS "Name",
    last(voy.type_and_cargo, voy.event_time) AS "AIS Cargo Code",
    last(num.type, voy.event_time) AS "AIS Cargo Class",
    last(num.sub_type, voy.event_time) AS "AIS Cargo SubClass",
    last(voy.to_bow + voy.to_stern, voy.event_time) AS "Length",
    last(voy.to_port + voy.to_starboard, voy.event_time) AS "Width",
    last(voy.destination, voy.event_time) AS "Destination",
    last(voy.event_time, voy.event_time) AS "Message Time",
    last(voy.routing_key, voy.event_time) AS "Data Source",
    st_setsrid(st_makeline(pos."position" ORDER BY pos.bucket), 4326)::geometry(LineString,4326) AS history
   FROM ais.pos_reports_1h_cagg pos
     LEFT JOIN ais.latest_voy_reports voy ON voy.mmsi = pos.mmsi
     LEFT JOIN ais.ais_num_to_type num ON voy.type_and_cargo::text = num.ais_num::text
  WHERE pos.bucket >= (now() - '24:00:00'::interval) AND pos.bucket <= now()
  AND pos.mmsi = $1
  GROUP BY pos.mmsi
  ORDER BY pos.mmsi
$_$;


ALTER FUNCTION postgisftw.vessel_details(mmsi text) OWNER TO vliz;

--
-- TOC entry 7441 (class 0 OID 0)
-- Dependencies: 1670
-- Name: FUNCTION vessel_details(mmsi text); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.vessel_details(mmsi text) IS 'Returns latest vessel voyage report details based off of <MMSI>.';


--
-- TOC entry 1667 (class 1255 OID 6217981)
-- Name: vessel_history(text, timestamp with time zone, integer); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.vessel_history(mmsi text, end_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP, hours_window integer DEFAULT 24) RETURNS TABLE("MMSI" text, "Navigation Status" text, "Rate of Turn" smallint, "Speed over Ground" numeric, "Course over Ground" numeric, "Heading" numeric, "Message Time" timestamp with time zone, geom public.geometry)
    LANGUAGE sql PARALLEL SAFE
    AS $_$
SELECT  
	mmsi as "MMSI",
	nav_status.description as "Navigation Status",
	rot as "Rate of Turn",
	sog as "Speed over Ground",
	cog as "Course over Ground",
	hdg as "Heading",
	event_time as "Message Time",
	ST_SetSRID(position,4326) as geom
FROM ais.pos_reports_1h_cagg
LEFT JOIN ais.nav_status
ON pos_reports_1h_cagg.navigation_status = nav_status.nav_status
WHERE bucket BETWEEN $2::timestamp - ($3::text ||' hours')::INTERVAL AND  $2::timestamp
AND mmsi = $1
ORDER BY mmsi, event_time DESC
$_$;


ALTER FUNCTION postgisftw.vessel_history(mmsi text, end_time timestamp with time zone, hours_window integer) OWNER TO vliz;

--
-- TOC entry 7442 (class 0 OID 0)
-- Dependencies: 1667
-- Name: FUNCTION vessel_history(mmsi text, end_time timestamp with time zone, hours_window integer); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.vessel_history(mmsi text, end_time timestamp with time zone, hours_window integer) IS 'Get 1 AIS position per hour for the vessel <MMSI> for the time window <end time> - <hours window> to <end time>';


--
-- TOC entry 1521 (class 1255 OID 73301)
-- Name: vessel_trajectory(date, date, interval, text); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.vessel_trajectory(start_date date DEFAULT '2020-01-01'::date, end_date date DEFAULT '2020-02-01'::date, gap_interval interval DEFAULT '04:00:00'::interval, input_mmsi text DEFAULT '601986000'::text) RETURNS TABLE(mmsi text, time_group bigint, traj public.geometry, group_start timestamp with time zone, group_end timestamp with time zone)
    LANGUAGE plpgsql STABLE PARALLEL SAFE
    AS $_$
 
BEGIN
	RETURN QUERY
		WITH ais_data as 
	(
		SELECT 
			aa.mmsi, 
			event_time,
			longitude,
			latitude,
			(lag(event_time) OVER (PARTITION BY aa.mmsi ORDER BY event_time) <= event_time - $3::interval) AS step
		FROM ais.pos_reports_1h_cagg as aa
		WHERE aa.mmsi = $4
		AND bucket between $1 and $2
	),
time_groups as 
	(
	SELECT
		bb.mmsi,
		bb.event_time,
		bb.longitude,
		bb.latitude,
		count(*) FILTER (WHERE step) OVER (ORDER BY event_time) as time_group
	FROM ais_data as bb 
		)
SELECT
		cc.mmsi,
		cc.time_group,
-- 		ST_AsText(ST_MakeLine( ST_MakePointM(cc.longitude, cc.latitude, EXTRACT(epoch FROM event_time)) order by event_time)) as wkt, 
		ST_SetSRID(ST_MakeLine( ST_MakePointM(cc.longitude, cc.latitude, EXTRACT(epoch FROM event_time)) order by event_time), 4326) as traj,
		first(event_time,event_time) as traj_start,
		last(event_time,event_time) as traj_end
	FROM time_groups as cc 
GROUP BY cc.mmsi, cc.time_group;
END;
$_$;


ALTER FUNCTION postgisftw.vessel_trajectory(start_date date, end_date date, gap_interval interval, input_mmsi text) OWNER TO vliz;

--
-- TOC entry 7443 (class 0 OID 0)
-- Dependencies: 1521
-- Name: FUNCTION vessel_trajectory(start_date date, end_date date, gap_interval interval, input_mmsi text); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.vessel_trajectory(start_date date, end_date date, gap_interval interval, input_mmsi text) IS 'Return the trajectory of a vessel, split by time gaps of GAP_INTERVAL.';


--
-- TOC entry 1668 (class 1255 OID 6520326)
-- Name: vessels(timestamp with time zone, integer); Type: FUNCTION; Schema: postgisftw; Owner: vliz
--

CREATE FUNCTION postgisftw.vessels(end_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP, hours_window integer DEFAULT 1) RETURNS TABLE("MMSI" text, "Navigation Status" text, "Rate of Turn" smallint, "Speed over Ground" numeric, "Course over Ground" numeric, "Heading" numeric, type_and_cargo character varying, "Class" text, "SubClass" text, "Message Time" timestamp with time zone, geom public.geometry)
    LANGUAGE sql PARALLEL SAFE
    AS $_$
SELECT DISTINCT ON (aa.mmsi)
	aa.mmsi as "MMSI",
	nav_status.description as "Navigation Status",
	rot as "Rate of Turn",
	sog as "Speed over Ground",
	cog as "Course over Ground",
	hdg as "Heading",
	bb.type_and_cargo ,
	cc.type as "Class",
	cc.sub_type as "SubClass",
	aa.event_time as "Message Time",
	ST_SetSRID(position,4326) as geom
FROM ais.pos_reports_1h_cagg as aa
LEFT JOIN ais.nav_status
ON aa.navigation_status = nav_status.nav_status
LEFT JOIN ais.latest_voy_reports as bb
ON aa.mmsi = bb.mmsi
LEFT JOIN ais.ais_num_to_type as cc
ON bb.type_and_cargo = cc.ais_num
WHERE bucket BETWEEN $1::timestamp - ($2::text ||' hours')::INTERVAL AND  $1::timestamp
ORDER BY aa.mmsi, aa.event_time DESC
$_$;


ALTER FUNCTION postgisftw.vessels(end_time timestamp with time zone, hours_window integer) OWNER TO vliz;

--
-- TOC entry 7444 (class 0 OID 0)
-- Dependencies: 1668
-- Name: FUNCTION vessels(end_time timestamp with time zone, hours_window integer); Type: COMMENT; Schema: postgisftw; Owner: vliz
--

COMMENT ON FUNCTION postgisftw.vessels(end_time timestamp with time zone, hours_window integer) IS 'Get positions of vessel between <end_time> and <end_time> - <hours_window>.';


--
-- TOC entry 1525 (class 1255 OID 141455)
-- Name: ais_aggregation(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: rory; Owner: vliz
--

CREATE FUNCTION rory.ais_aggregation(begin_time timestamp without time zone, end_time timestamp without time zone) RETURNS TABLE(id double precision, event_date date, geom public.geometry, type_and_cargo character varying, cardinal_seg numeric, track_count bigint, avg_y_disturbance double precision, var_y_disturbance double precision, avg_x_disturbance double precision, var_x_disturbance double precision, avg_cog numeric, avg_hdg numeric, avg_sog numeric, max_sog numeric, avg_time_delta double precision, cum_time_in_grid double precision)
    LANGUAGE sql
    AS $_$
 
 SELECT 
    grid.gid,
    traj.event_date,
    grid.geom, 
    det.type_and_cargo,
    trunc((traj.cog / (45)::numeric)) AS cardinal_seg,
	count(traj.sog) AS track_count,
    (avg((((traj.sog)::double precision * sin(radians((traj.cog)::double precision))) - ((traj.sog)::double precision * sin(radians((traj.hdg)::double precision))))) * (0.514444)::double precision) AS avg_y_disturbance,
    (variance((((traj.sog)::double precision * sin(radians((traj.cog)::double precision))) - ((traj.sog)::double precision * sin(radians((traj.hdg)::double precision))))) * (0.514444)::double precision) AS var_y_disturbance,
    (avg((((traj.sog)::double precision * cos(radians((traj.cog)::double precision))) - ((traj.sog)::double precision * cos(radians((traj.hdg)::double precision))))) * (0.514444)::double precision) AS avg_x_disturbance,
    (variance((((traj.sog)::double precision * cos(radians((traj.cog)::double precision))) - ((traj.sog)::double precision * cos(radians((traj.hdg)::double precision))))) * (0.514444)::double precision) AS var_x_disturbance,
    
    avg(NULLIF(traj.cog, 511.0)) AS avg_cog,
	avg(NULLIF(traj.hdg, 511.0)) AS avg_hdg,
    avg(NULLIF(traj.sog, 102.3)) AS avg_sog,
    max(NULLIF(traj.sog, 102.3)) AS max_sog,
    avg(traj.time_delta) AS avg_time_delta,
    sum(((st_length(st_intersection(traj.traj, grid.geom)) * traj.time_delta) / traj.traj_dist)) AS cum_time_in_grid
   FROM ((rory.aoi_hex_grid_1km2 grid
     LEFT JOIN ( SELECT subquery.mmsi,
            subquery.event_date,
            subquery.cog,
            subquery.hdg,
            subquery.sog,
            subquery.time_delta,
            st_makeline(subquery.pos, subquery.pos2) AS traj,
            st_distance(subquery.pos, subquery.pos2) AS traj_dist
           FROM ( SELECT ais.mmsi,
                    date(ais.event_time) AS event_date,
                    date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) AS time_delta,
                    ais."position" AS pos,
                    NULLIF(ais.sog, 102.3) AS sog,
                    NULLIF(ais.cog, 360.0) AS cog,
                    NULLIF(ais.hdg, 511.0) AS hdg,
                    ais.navigation_status,
                    ais.rot,
                    lead(ais."position") OVER time_order AS pos2
                   FROM ais.pos_reports ais
                  WHERE ((ais.event_time >= $1::timestamp with time zone) AND (ais.event_time <= $2::timestamp with time zone))
                  WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)) subquery
          WHERE (subquery.pos2 IS NOT NULL)) traj ON (st_intersects(traj.traj, grid.geom)))
     LEFT JOIN ais.latest_voy_reports det ON ((traj.mmsi = det.mmsi)))
  WHERE ((traj.traj_dist > (0)::double precision) AND (traj.time_delta > (0)::double precision) AND (traj.traj_dist < (0.05)::double precision))
  GROUP BY grid.gid, grid.geom, det.type_and_cargo, traj.event_date, (trunc((traj.cog / (45)::numeric)))
$_$;


ALTER FUNCTION rory.ais_aggregation(begin_time timestamp without time zone, end_time timestamp without time zone) OWNER TO vliz;

--
-- TOC entry 1522 (class 1255 OID 78370)
-- Name: do_ais_agg_yesterday(timestamp without time zone, timestamp without time zone); Type: PROCEDURE; Schema: rory; Owner: vliz
--

CREATE PROCEDURE rory.do_ais_agg_yesterday(start_time timestamp without time zone, end_time timestamp without time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN 
	INSERT INTO rory.belgium_trajectories
	 WITH lead_lag AS (
         SELECT ais.mmsi,
            ais."position",
            ais.event_time,
            ais.sog,
            lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time) <= (ais.event_time - '01:00:00'::interval) AS time_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) NOT BETWEEN 0 AND 0.1 AS dist_step,
	       (st_distancesphere(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) / NULLIF(date_part('epoch'::text, ais.event_time - lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)), 0::double precision)) >= (2::numeric * (ais.sog + 0.1))::double precision AS sog_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) AS dist
           FROM ais.pos_reports ais,
            rory.belgium_eez_bounding_box
          WHERE ais.event_time >= $1::timestamp with time zone 
	        AND ais.event_time <= $2::timestamp with time zone 
	        AND st_within(ais."position", belgium_eez_bounding_box.geom)
        ), lead_lag_groups AS (
         SELECT lead_lag_1.mmsi,
            lead_lag_1."position",
            lead_lag_1.event_time,
            lead_lag_1.sog,
            lead_lag_1.time_step,
            lead_lag_1.dist_step,
            lead_lag_1.dist,
            lead_lag_1.sog_step,
            count(*) FILTER (WHERE lead_lag_1.time_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS time_grp,
            count(*) FILTER (WHERE lead_lag_1.dist_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS dist_grp,
            count(*) FILTER (WHERE lead_lag_1.sog_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS sog_grp
           FROM lead_lag lead_lag_1
          WHERE lead_lag_1.dist > 0::double precision
        )
 SELECT 
    lead_lag.mmsi,
    lead_lag.time_grp,
    lead_lag.dist_grp,
    lead_lag.sog_grp, 
	first(event_time, event_time) as first_time,
	last(event_time, event_time) as last_time,
	st_length(st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS geom_length,
    st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326) AS geom,
    st_astext(st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS st_astext
   FROM lead_lag_groups AS lead_lag 
  GROUP BY lead_lag.mmsi, lead_lag.time_grp, lead_lag.dist_grp, lead_lag.sog_grp;
END
$_$;


ALTER PROCEDURE rory.do_ais_agg_yesterday(start_time timestamp without time zone, end_time timestamp without time zone) OWNER TO vliz;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 379 (class 1259 OID 180181)
-- Name: _compressed_hypertable_6; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._compressed_hypertable_6 (
    mmsi text,
    imo _timescaledb_internal.compressed_data,
    callsign _timescaledb_internal.compressed_data,
    name _timescaledb_internal.compressed_data,
    type_and_cargo _timescaledb_internal.compressed_data,
    to_bow _timescaledb_internal.compressed_data,
    to_stern _timescaledb_internal.compressed_data,
    to_port _timescaledb_internal.compressed_data,
    to_starboard _timescaledb_internal.compressed_data,
    fix_type _timescaledb_internal.compressed_data,
    eta_month _timescaledb_internal.compressed_data,
    eta_day _timescaledb_internal.compressed_data,
    eta_hour _timescaledb_internal.compressed_data,
    eta_minute _timescaledb_internal.compressed_data,
    eta _timescaledb_internal.compressed_data,
    draught _timescaledb_internal.compressed_data,
    destination _timescaledb_internal.compressed_data,
    event_time _timescaledb_internal.compressed_data,
    server_time _timescaledb_internal.compressed_data,
    msg_type _timescaledb_internal.compressed_data,
    routing_key _timescaledb_internal.compressed_data,
    _ts_meta_count integer,
    _ts_meta_sequence_num integer,
    _ts_meta_min_1 timestamp with time zone,
    _ts_meta_max_1 timestamp with time zone
)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal._compressed_hypertable_6 ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal._compressed_hypertable_6 OWNER TO vliz;

--
-- TOC entry 262 (class 1259 OID 17948)
-- Name: pos_reports; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.pos_reports (
    mmsi text NOT NULL,
    navigation_status character varying(3),
    rot smallint,
    sog numeric(4,1),
    longitude double precision NOT NULL,
    latitude double precision NOT NULL,
    "position" public.geometry,
    cog numeric(4,1),
    hdg numeric(4,1),
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    msg_type character varying(3),
    routing_key text
)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE ais.pos_reports OWNER TO vliz;

--
-- TOC entry 288 (class 1259 OID 24874)
-- Name: _direct_view_4; Type: VIEW; Schema: _timescaledb_internal; Owner: vliz
--

CREATE VIEW _timescaledb_internal._direct_view_4 AS
 SELECT pos_reports.mmsi,
    pos_reports.routing_key,
    public.time_bucket('01:00:00'::interval, pos_reports.event_time) AS bucket,
    public.last(pos_reports.navigation_status, pos_reports.event_time) AS navigation_status,
    public.last(pos_reports.rot, pos_reports.event_time) AS rot,
    public.last(pos_reports.sog, pos_reports.event_time) AS sog,
    public.last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    public.last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    public.last(pos_reports."position", pos_reports.event_time) AS "position",
    public.last(pos_reports.cog, pos_reports.event_time) AS cog,
    public.last(pos_reports.hdg, pos_reports.event_time) AS hdg,
    public.last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    public.last(pos_reports.msg_type, pos_reports.event_time) AS msg_type,
    avg(pos_reports.sog) AS sog_avg,
    min(pos_reports.sog) AS sog_min,
    max(pos_reports.sog) AS sog_max,
    avg(pos_reports.cog) AS cog_avg,
    min(pos_reports.cog) AS cog_min,
    max(pos_reports.cog) AS cog_max,
    avg(pos_reports.hdg) AS hdg_avg,
    min(pos_reports.hdg) AS hdg_min,
    max(pos_reports.hdg) AS hdg_max
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, pos_reports.routing_key, (public.time_bucket('01:00:00'::interval, pos_reports.event_time));


ALTER TABLE _timescaledb_internal._direct_view_4 OWNER TO vliz;

--
-- TOC entry 263 (class 1259 OID 17958)
-- Name: voy_reports; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.voy_reports (
    mmsi text NOT NULL,
    imo text,
    callsign text,
    name text,
    type_and_cargo character varying(3),
    to_bow smallint,
    to_stern smallint,
    to_port smallint,
    to_starboard smallint,
    fix_type smallint,
    eta_month smallint,
    eta_day smallint,
    eta_hour smallint,
    eta_minute smallint,
    eta timestamp with time zone,
    draught numeric(4,1),
    destination text,
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    msg_type character varying(3),
    routing_key text
);


ALTER TABLE ais.voy_reports OWNER TO vliz;

--
-- TOC entry 292 (class 1259 OID 24902)
-- Name: _direct_view_5; Type: VIEW; Schema: _timescaledb_internal; Owner: vliz
--

CREATE VIEW _timescaledb_internal._direct_view_5 AS
 SELECT voy_reports.mmsi,
    voy_reports.routing_key,
    public.time_bucket('06:00:00'::interval, voy_reports.event_time) AS bucket,
    public.last(voy_reports.imo, voy_reports.event_time) AS imo,
    public.last(voy_reports.callsign, voy_reports.event_time) AS callsign,
    public.last(voy_reports.name, voy_reports.event_time) AS name,
    public.last(voy_reports.type_and_cargo, voy_reports.event_time) AS type_and_cargo,
    public.last(voy_reports.to_bow, voy_reports.event_time) AS to_bow,
    public.last(voy_reports.to_stern, voy_reports.event_time) AS to_stern,
    public.last(voy_reports.to_port, voy_reports.event_time) AS to_port,
    public.last(voy_reports.to_starboard, voy_reports.event_time) AS to_starboard,
    public.last(voy_reports.fix_type, voy_reports.event_time) AS fix_type,
    public.last(voy_reports.eta, voy_reports.event_time) AS eta,
    public.last(voy_reports.draught, voy_reports.event_time) AS draught,
    public.last(voy_reports.destination, voy_reports.event_time) AS destination,
    public.last(voy_reports.event_time, voy_reports.event_time) AS event_time,
    public.last(voy_reports.msg_type, voy_reports.event_time) AS msg_type
   FROM ais.voy_reports
  GROUP BY voy_reports.mmsi, voy_reports.routing_key, (public.time_bucket('06:00:00'::interval, voy_reports.event_time));


ALTER TABLE _timescaledb_internal._direct_view_5 OWNER TO vliz;

--
-- TOC entry 414 (class 1259 OID 6521415)
-- Name: _hyper_1_100_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_100_chunk (
    CONSTRAINT constraint_77 CHECK (((event_time >= '2022-05-12 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-19 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_100_chunk OWNER TO vliz;

--
-- TOC entry 421 (class 1259 OID 6819868)
-- Name: _hyper_1_118_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_118_chunk (
    CONSTRAINT constraint_94 CHECK (((event_time >= '2019-07-18 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-07-25 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_118_chunk OWNER TO vliz;

--
-- TOC entry 422 (class 1259 OID 6819879)
-- Name: _hyper_1_119_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_119_chunk (
    CONSTRAINT constraint_95 CHECK (((event_time >= '2019-06-27 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-07-04 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_119_chunk OWNER TO vliz;

--
-- TOC entry 303 (class 1259 OID 25873)
-- Name: _hyper_1_11_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_11_chunk (
    CONSTRAINT constraint_11 CHECK (((event_time >= '2021-10-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_11_chunk OWNER TO vliz;

--
-- TOC entry 423 (class 1259 OID 6819890)
-- Name: _hyper_1_120_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_120_chunk (
    CONSTRAINT constraint_96 CHECK (((event_time >= '2019-09-26 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-10-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_120_chunk OWNER TO vliz;

--
-- TOC entry 424 (class 1259 OID 6819901)
-- Name: _hyper_1_121_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_121_chunk (
    CONSTRAINT constraint_97 CHECK (((event_time >= '2019-08-08 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-08-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_121_chunk OWNER TO vliz;

--
-- TOC entry 425 (class 1259 OID 6819912)
-- Name: _hyper_1_122_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_122_chunk (
    CONSTRAINT constraint_98 CHECK (((event_time >= '2019-08-22 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-08-29 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_122_chunk OWNER TO vliz;

--
-- TOC entry 426 (class 1259 OID 6819923)
-- Name: _hyper_1_123_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_123_chunk (
    CONSTRAINT constraint_99 CHECK (((event_time >= '2019-07-11 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-07-18 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_123_chunk OWNER TO vliz;

--
-- TOC entry 427 (class 1259 OID 6819934)
-- Name: _hyper_1_124_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_124_chunk (
    CONSTRAINT constraint_100 CHECK (((event_time >= '2019-08-29 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-09-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_124_chunk OWNER TO vliz;

--
-- TOC entry 428 (class 1259 OID 6819945)
-- Name: _hyper_1_125_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_125_chunk (
    CONSTRAINT constraint_101 CHECK (((event_time >= '2019-08-01 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-08-08 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_125_chunk OWNER TO vliz;

--
-- TOC entry 429 (class 1259 OID 6819956)
-- Name: _hyper_1_126_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_126_chunk (
    CONSTRAINT constraint_102 CHECK (((event_time >= '2019-08-15 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-08-22 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_126_chunk OWNER TO vliz;

--
-- TOC entry 430 (class 1259 OID 6819967)
-- Name: _hyper_1_127_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_127_chunk (
    CONSTRAINT constraint_103 CHECK (((event_time >= '2019-09-19 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-09-26 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_127_chunk OWNER TO vliz;

--
-- TOC entry 431 (class 1259 OID 6819978)
-- Name: _hyper_1_128_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_128_chunk (
    CONSTRAINT constraint_104 CHECK (((event_time >= '2019-09-05 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-09-12 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_128_chunk OWNER TO vliz;

--
-- TOC entry 432 (class 1259 OID 6819989)
-- Name: _hyper_1_129_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_129_chunk (
    CONSTRAINT constraint_105 CHECK (((event_time >= '2019-07-04 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-07-11 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_129_chunk OWNER TO vliz;

--
-- TOC entry 433 (class 1259 OID 6820000)
-- Name: _hyper_1_130_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_130_chunk (
    CONSTRAINT constraint_106 CHECK (((event_time >= '2019-07-25 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-08-01 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_130_chunk OWNER TO vliz;

--
-- TOC entry 434 (class 1259 OID 6820011)
-- Name: _hyper_1_131_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_131_chunk (
    CONSTRAINT constraint_107 CHECK (((event_time >= '2019-09-12 00:00:00+00'::timestamp with time zone) AND (event_time < '2019-09-19 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_131_chunk OWNER TO vliz;

--
-- TOC entry 435 (class 1259 OID 6820022)
-- Name: _hyper_1_132_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_132_chunk (
    CONSTRAINT constraint_108 CHECK (((event_time >= '2020-05-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2020-05-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_132_chunk OWNER TO vliz;

--
-- TOC entry 436 (class 1259 OID 6820033)
-- Name: _hyper_1_133_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_133_chunk (
    CONSTRAINT constraint_109 CHECK (((event_time >= '2020-05-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2020-05-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_133_chunk OWNER TO vliz;

--
-- TOC entry 437 (class 1259 OID 6820044)
-- Name: _hyper_1_134_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_134_chunk (
    CONSTRAINT constraint_110 CHECK (((event_time >= '2020-04-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2020-05-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_134_chunk OWNER TO vliz;

--
-- TOC entry 438 (class 1259 OID 6820055)
-- Name: _hyper_1_135_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_135_chunk (
    CONSTRAINT constraint_111 CHECK (((event_time >= '2017-08-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-08-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_135_chunk OWNER TO vliz;

--
-- TOC entry 439 (class 1259 OID 6820066)
-- Name: _hyper_1_136_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_136_chunk (
    CONSTRAINT constraint_112 CHECK (((event_time >= '2017-08-31 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-09-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_136_chunk OWNER TO vliz;

--
-- TOC entry 440 (class 1259 OID 6820077)
-- Name: _hyper_1_137_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_137_chunk (
    CONSTRAINT constraint_113 CHECK (((event_time >= '2017-08-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-08-31 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_137_chunk OWNER TO vliz;

--
-- TOC entry 441 (class 1259 OID 6820088)
-- Name: _hyper_1_138_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_138_chunk (
    CONSTRAINT constraint_114 CHECK (((event_time >= '2017-09-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-09-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_138_chunk OWNER TO vliz;

--
-- TOC entry 442 (class 1259 OID 6820099)
-- Name: _hyper_1_139_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_139_chunk (
    CONSTRAINT constraint_115 CHECK (((event_time >= '2017-08-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-08-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_139_chunk OWNER TO vliz;

--
-- TOC entry 305 (class 1259 OID 36427)
-- Name: _hyper_1_13_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_13_chunk (
    CONSTRAINT constraint_13 CHECK (((event_time >= '2021-10-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_13_chunk OWNER TO vliz;

--
-- TOC entry 443 (class 1259 OID 6820110)
-- Name: _hyper_1_140_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_140_chunk (
    CONSTRAINT constraint_116 CHECK (((event_time >= '2017-09-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-09-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_140_chunk OWNER TO vliz;

--
-- TOC entry 444 (class 1259 OID 6820121)
-- Name: _hyper_1_141_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_141_chunk (
    CONSTRAINT constraint_117 CHECK (((event_time >= '2017-08-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-08-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_141_chunk OWNER TO vliz;

--
-- TOC entry 445 (class 1259 OID 6820132)
-- Name: _hyper_1_142_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_142_chunk (
    CONSTRAINT constraint_118 CHECK (((event_time >= '2017-09-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-10-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_142_chunk OWNER TO vliz;

--
-- TOC entry 446 (class 1259 OID 6820143)
-- Name: _hyper_1_143_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_143_chunk (
    CONSTRAINT constraint_119 CHECK (((event_time >= '2017-09-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2017-09-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_143_chunk OWNER TO vliz;

--
-- TOC entry 447 (class 1259 OID 6820154)
-- Name: _hyper_1_144_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_144_chunk (
    CONSTRAINT constraint_120 CHECK (((event_time >= '2020-07-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2020-07-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_144_chunk OWNER TO vliz;

--
-- TOC entry 448 (class 1259 OID 6820165)
-- Name: _hyper_1_145_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_145_chunk (
    CONSTRAINT constraint_121 CHECK (((event_time >= '2020-07-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2020-07-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_145_chunk OWNER TO vliz;

--
-- TOC entry 451 (class 1259 OID 6822271)
-- Name: _hyper_1_148_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_148_chunk (
    CONSTRAINT constraint_124 CHECK (((event_time >= '2022-05-19 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-26 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_148_chunk OWNER TO vliz;

--
-- TOC entry 454 (class 1259 OID 7148765)
-- Name: _hyper_1_151_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_151_chunk (
    CONSTRAINT constraint_126 CHECK (((event_time >= '2022-05-26 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_151_chunk OWNER TO vliz;

--
-- TOC entry 457 (class 1259 OID 7479141)
-- Name: _hyper_1_154_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_154_chunk (
    CONSTRAINT constraint_128 CHECK (((event_time >= '2022-06-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_154_chunk OWNER TO vliz;

--
-- TOC entry 460 (class 1259 OID 7839715)
-- Name: _hyper_1_157_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_157_chunk (
    CONSTRAINT constraint_130 CHECK (((event_time >= '2022-06-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_157_chunk OWNER TO vliz;

--
-- TOC entry 307 (class 1259 OID 36808)
-- Name: _hyper_1_15_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_15_chunk (
    CONSTRAINT constraint_15 CHECK (((event_time >= '2021-10-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-04 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_15_chunk OWNER TO vliz;

--
-- TOC entry 465 (class 1259 OID 8547900)
-- Name: _hyper_1_162_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_162_chunk (
    CONSTRAINT constraint_133 CHECK (((event_time >= '2022-06-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_162_chunk OWNER TO vliz;

--
-- TOC entry 467 (class 1259 OID 8980667)
-- Name: _hyper_1_164_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_164_chunk (
    CONSTRAINT constraint_134 CHECK (((event_time >= '2022-06-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_164_chunk OWNER TO vliz;

--
-- TOC entry 470 (class 1259 OID 9267738)
-- Name: _hyper_1_167_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_167_chunk (
    CONSTRAINT constraint_136 CHECK (((event_time >= '2022-07-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_167_chunk OWNER TO vliz;

--
-- TOC entry 475 (class 1259 OID 9736625)
-- Name: _hyper_1_172_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_172_chunk (
    CONSTRAINT constraint_140 CHECK (((event_time >= '2022-07-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_172_chunk OWNER TO vliz;

--
-- TOC entry 478 (class 1259 OID 10228139)
-- Name: _hyper_1_175_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_175_chunk (
    CONSTRAINT constraint_142 CHECK (((event_time >= '2022-07-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_175_chunk OWNER TO vliz;

--
-- TOC entry 481 (class 1259 OID 10732077)
-- Name: _hyper_1_178_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_178_chunk (
    CONSTRAINT constraint_144 CHECK (((event_time >= '2022-07-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-04 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_178_chunk OWNER TO vliz;

--
-- TOC entry 309 (class 1259 OID 37183)
-- Name: _hyper_1_17_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_17_chunk (
    CONSTRAINT constraint_17 CHECK (((event_time >= '2021-11-04 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-11 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_17_chunk OWNER TO vliz;

--
-- TOC entry 484 (class 1259 OID 11235457)
-- Name: _hyper_1_181_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_181_chunk (
    CONSTRAINT constraint_146 CHECK (((event_time >= '2022-08-04 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-11 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_181_chunk OWNER TO vliz;

--
-- TOC entry 487 (class 1259 OID 11758310)
-- Name: _hyper_1_184_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_184_chunk (
    CONSTRAINT constraint_148 CHECK (((event_time >= '2022-08-11 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-18 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_184_chunk OWNER TO vliz;

--
-- TOC entry 490 (class 1259 OID 12285402)
-- Name: _hyper_1_187_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_187_chunk (
    CONSTRAINT constraint_150 CHECK (((event_time >= '2022-08-18 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-25 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_187_chunk OWNER TO vliz;

--
-- TOC entry 493 (class 1259 OID 12492978)
-- Name: _hyper_1_190_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_190_chunk (
    CONSTRAINT constraint_152 CHECK (((event_time >= '2022-08-25 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-01 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_190_chunk OWNER TO vliz;

--
-- TOC entry 495 (class 1259 OID 12498846)
-- Name: _hyper_1_192_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_192_chunk (
    CONSTRAINT constraint_154 CHECK (((event_time >= '2022-09-01 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-08 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_192_chunk OWNER TO vliz;

--
-- TOC entry 498 (class 1259 OID 13022937)
-- Name: _hyper_1_195_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_195_chunk (
    CONSTRAINT constraint_156 CHECK (((event_time >= '2022-09-08 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_195_chunk OWNER TO vliz;

--
-- TOC entry 511 (class 1259 OID 14137170)
-- Name: _hyper_1_198_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_198_chunk (
    CONSTRAINT constraint_158 CHECK (((event_time >= '2022-09-15 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-22 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_198_chunk OWNER TO vliz;

--
-- TOC entry 314 (class 1259 OID 52083)
-- Name: _hyper_1_19_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_19_chunk (
    CONSTRAINT constraint_19 CHECK (((event_time >= '2021-11-11 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-18 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_19_chunk OWNER TO vliz;

--
-- TOC entry 283 (class 1259 OID 24576)
-- Name: _hyper_1_1_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_1_chunk (
    CONSTRAINT constraint_1 CHECK (((event_time >= '2021-09-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-09-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_1_chunk OWNER TO vliz;

--
-- TOC entry 516 (class 1259 OID 14694308)
-- Name: _hyper_1_203_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_203_chunk (
    CONSTRAINT constraint_162 CHECK (((event_time >= '2022-09-22 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-29 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_203_chunk OWNER TO vliz;

--
-- TOC entry 519 (class 1259 OID 15270998)
-- Name: _hyper_1_206_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_206_chunk (
    CONSTRAINT constraint_164 CHECK (((event_time >= '2022-09-29 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-06 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_206_chunk OWNER TO vliz;

--
-- TOC entry 522 (class 1259 OID 15848136)
-- Name: _hyper_1_209_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_209_chunk (
    CONSTRAINT constraint_166 CHECK (((event_time >= '2022-10-06 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_209_chunk OWNER TO vliz;

--
-- TOC entry 526 (class 1259 OID 16429898)
-- Name: _hyper_1_212_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_212_chunk (
    CONSTRAINT constraint_168 CHECK (((event_time >= '2022-10-13 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-20 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_212_chunk OWNER TO vliz;

--
-- TOC entry 532 (class 1259 OID 16996371)
-- Name: _hyper_1_216_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_216_chunk (
    CONSTRAINT constraint_171 CHECK (((event_time >= '2022-10-20 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-27 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_216_chunk OWNER TO vliz;

--
-- TOC entry 538 (class 1259 OID 17552486)
-- Name: _hyper_1_218_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_218_chunk (
    CONSTRAINT constraint_172 CHECK (((event_time >= '2022-10-27 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_218_chunk OWNER TO vliz;

--
-- TOC entry 317 (class 1259 OID 52546)
-- Name: _hyper_1_21_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_21_chunk (
    CONSTRAINT constraint_21 CHECK (((event_time >= '2021-11-18 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-25 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_21_chunk OWNER TO vliz;

--
-- TOC entry 541 (class 1259 OID 18081985)
-- Name: _hyper_1_221_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_221_chunk (
    CONSTRAINT constraint_174 CHECK (((event_time >= '2022-11-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_221_chunk OWNER TO vliz;

--
-- TOC entry 545 (class 1259 OID 18797336)
-- Name: _hyper_1_224_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_224_chunk (
    CONSTRAINT constraint_176 CHECK (((event_time >= '2022-11-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_224_chunk OWNER TO vliz;

--
-- TOC entry 548 (class 1259 OID 20176721)
-- Name: _hyper_1_227_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_227_chunk (
    CONSTRAINT constraint_178 CHECK (((event_time >= '2022-11-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_227_chunk OWNER TO vliz;

--
-- TOC entry 551 (class 1259 OID 21597015)
-- Name: _hyper_1_230_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_230_chunk (
    CONSTRAINT constraint_180 CHECK (((event_time >= '2022-11-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-01 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_230_chunk OWNER TO vliz;

--
-- TOC entry 556 (class 1259 OID 23006074)
-- Name: _hyper_1_235_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_235_chunk (
    CONSTRAINT constraint_184 CHECK (((event_time >= '2022-12-01 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-08 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_235_chunk OWNER TO vliz;

--
-- TOC entry 564 (class 1259 OID 25832588)
-- Name: _hyper_1_239_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_239_chunk (
    CONSTRAINT constraint_186 CHECK (((event_time >= '2022-12-08 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_239_chunk OWNER TO vliz;

--
-- TOC entry 319 (class 1259 OID 52918)
-- Name: _hyper_1_23_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_23_chunk (
    CONSTRAINT constraint_23 CHECK (((event_time >= '2021-11-25 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_23_chunk OWNER TO vliz;

--
-- TOC entry 567 (class 1259 OID 27178890)
-- Name: _hyper_1_242_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_242_chunk (
    CONSTRAINT constraint_188 CHECK (((event_time >= '2022-12-15 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-22 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_242_chunk OWNER TO vliz;

--
-- TOC entry 570 (class 1259 OID 28545437)
-- Name: _hyper_1_245_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_245_chunk (
    CONSTRAINT constraint_190 CHECK (((event_time >= '2022-12-22 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-29 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_245_chunk OWNER TO vliz;

--
-- TOC entry 573 (class 1259 OID 29876891)
-- Name: _hyper_1_248_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_248_chunk (
    CONSTRAINT constraint_192 CHECK (((event_time >= '2022-12-29 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_248_chunk OWNER TO vliz;

--
-- TOC entry 576 (class 1259 OID 31351410)
-- Name: _hyper_1_251_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_251_chunk (
    CONSTRAINT constraint_194 CHECK (((event_time >= '2023-01-05 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-12 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_251_chunk OWNER TO vliz;

--
-- TOC entry 580 (class 1259 OID 32687032)
-- Name: _hyper_1_255_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_255_chunk (
    CONSTRAINT constraint_197 CHECK (((event_time >= '2023-01-12 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-19 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_255_chunk OWNER TO vliz;

--
-- TOC entry 582 (class 1259 OID 34050998)
-- Name: _hyper_1_257_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_257_chunk (
    CONSTRAINT constraint_198 CHECK (((event_time >= '2023-01-19 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-26 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_257_chunk OWNER TO vliz;

--
-- TOC entry 321 (class 1259 OID 66582)
-- Name: _hyper_1_25_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_25_chunk (
    CONSTRAINT constraint_25 CHECK (((event_time >= '2021-12-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_25_chunk OWNER TO vliz;

--
-- TOC entry 585 (class 1259 OID 35482469)
-- Name: _hyper_1_260_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_260_chunk (
    CONSTRAINT constraint_200 CHECK (((event_time >= '2023-01-26 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_260_chunk OWNER TO vliz;

--
-- TOC entry 587 (class 1259 OID 35494459)
-- Name: _hyper_1_262_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_262_chunk (
    CONSTRAINT constraint_202 CHECK (((event_time >= '2023-02-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_262_chunk OWNER TO vliz;

--
-- TOC entry 592 (class 1259 OID 36945270)
-- Name: _hyper_1_267_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_267_chunk (
    CONSTRAINT constraint_206 CHECK (((event_time >= '2023-02-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_267_chunk OWNER TO vliz;

--
-- TOC entry 595 (class 1259 OID 38434291)
-- Name: _hyper_1_270_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_270_chunk (
    CONSTRAINT constraint_208 CHECK (((event_time >= '2023-02-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_270_chunk OWNER TO vliz;

--
-- TOC entry 598 (class 1259 OID 40050740)
-- Name: _hyper_1_273_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_273_chunk (
    CONSTRAINT constraint_210 CHECK (((event_time >= '2023-02-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_273_chunk OWNER TO vliz;

--
-- TOC entry 601 (class 1259 OID 41383276)
-- Name: _hyper_1_276_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_276_chunk (
    CONSTRAINT constraint_212 CHECK (((event_time >= '2023-03-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_276_chunk OWNER TO vliz;

--
-- TOC entry 323 (class 1259 OID 67003)
-- Name: _hyper_1_27_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_27_chunk (
    CONSTRAINT constraint_27 CHECK (((event_time >= '2021-12-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_27_chunk OWNER TO vliz;

--
-- TOC entry 605 (class 1259 OID 44240089)
-- Name: _hyper_1_280_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_280_chunk (
    CONSTRAINT constraint_214 CHECK (((event_time >= '2023-03-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_280_chunk OWNER TO vliz;

--
-- TOC entry 608 (class 1259 OID 45689975)
-- Name: _hyper_1_283_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_283_chunk (
    CONSTRAINT constraint_216 CHECK (((event_time >= '2023-03-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_283_chunk OWNER TO vliz;

--
-- TOC entry 327 (class 1259 OID 67580)
-- Name: _hyper_1_31_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_31_chunk (
    CONSTRAINT constraint_31 CHECK (((event_time >= '2021-12-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_31_chunk OWNER TO vliz;

--
-- TOC entry 334 (class 1259 OID 76851)
-- Name: _hyper_1_33_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_33_chunk (
    CONSTRAINT constraint_33 CHECK (((event_time >= '2021-12-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_33_chunk OWNER TO vliz;

--
-- TOC entry 337 (class 1259 OID 123151)
-- Name: _hyper_1_35_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_35_chunk (
    CONSTRAINT constraint_35 CHECK (((event_time >= '2021-12-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-06 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_35_chunk OWNER TO vliz;

--
-- TOC entry 339 (class 1259 OID 123525)
-- Name: _hyper_1_37_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_37_chunk (
    CONSTRAINT constraint_37 CHECK (((event_time >= '2022-01-06 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_37_chunk OWNER TO vliz;

--
-- TOC entry 342 (class 1259 OID 123911)
-- Name: _hyper_1_39_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_39_chunk (
    CONSTRAINT constraint_39 CHECK (((event_time >= '2022-01-13 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-20 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_39_chunk OWNER TO vliz;

--
-- TOC entry 344 (class 1259 OID 126253)
-- Name: _hyper_1_41_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_41_chunk (
    CONSTRAINT constraint_41 CHECK (((event_time >= '2022-01-20 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-27 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_41_chunk OWNER TO vliz;

--
-- TOC entry 347 (class 1259 OID 126656)
-- Name: _hyper_1_43_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_43_chunk (
    CONSTRAINT constraint_43 CHECK (((event_time >= '2022-01-27 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_43_chunk OWNER TO vliz;

--
-- TOC entry 349 (class 1259 OID 127027)
-- Name: _hyper_1_45_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_45_chunk (
    CONSTRAINT constraint_45 CHECK (((event_time >= '2022-02-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_45_chunk OWNER TO vliz;

--
-- TOC entry 354 (class 1259 OID 133015)
-- Name: _hyper_1_47_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_47_chunk (
    CONSTRAINT constraint_47 CHECK (((event_time >= '2022-02-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_47_chunk OWNER TO vliz;

--
-- TOC entry 357 (class 1259 OID 137231)
-- Name: _hyper_1_49_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_49_chunk (
    CONSTRAINT constraint_49 CHECK (((event_time >= '2022-02-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_49_chunk OWNER TO vliz;

--
-- TOC entry 361 (class 1259 OID 141184)
-- Name: _hyper_1_53_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_53_chunk (
    CONSTRAINT constraint_53 CHECK (((event_time >= '2022-02-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_53_chunk OWNER TO vliz;

--
-- TOC entry 366 (class 1259 OID 145603)
-- Name: _hyper_1_55_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_55_chunk (
    CONSTRAINT constraint_55 CHECK (((event_time >= '2022-03-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_55_chunk OWNER TO vliz;

--
-- TOC entry 368 (class 1259 OID 150383)
-- Name: _hyper_1_57_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_57_chunk (
    CONSTRAINT constraint_57 CHECK (((event_time >= '2022-03-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_57_chunk OWNER TO vliz;

--
-- TOC entry 370 (class 1259 OID 156231)
-- Name: _hyper_1_59_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_59_chunk (
    CONSTRAINT constraint_59 CHECK (((event_time >= '2022-03-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_59_chunk OWNER TO vliz;

--
-- TOC entry 295 (class 1259 OID 24958)
-- Name: _hyper_1_5_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_5_chunk (
    CONSTRAINT constraint_5 CHECK (((event_time >= '2021-09-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_5_chunk OWNER TO vliz;

--
-- TOC entry 372 (class 1259 OID 162843)
-- Name: _hyper_1_61_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_61_chunk (
    CONSTRAINT constraint_61 CHECK (((event_time >= '2022-03-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-31 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_61_chunk OWNER TO vliz;

--
-- TOC entry 374 (class 1259 OID 170229)
-- Name: _hyper_1_63_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_63_chunk (
    CONSTRAINT constraint_63 CHECK (((event_time >= '2022-03-31 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_63_chunk OWNER TO vliz;

--
-- TOC entry 377 (class 1259 OID 176684)
-- Name: _hyper_1_65_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_65_chunk (
    CONSTRAINT constraint_65 CHECK (((event_time >= '2022-04-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_65_chunk OWNER TO vliz;

--
-- TOC entry 400 (class 1259 OID 5625466)
-- Name: _hyper_1_87_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_87_chunk (
    CONSTRAINT constraint_67 CHECK (((event_time >= '2022-04-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_87_chunk OWNER TO vliz;

--
-- TOC entry 403 (class 1259 OID 5912400)
-- Name: _hyper_1_90_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_90_chunk (
    CONSTRAINT constraint_69 CHECK (((event_time >= '2022-04-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_90_chunk OWNER TO vliz;

--
-- TOC entry 408 (class 1259 OID 6212211)
-- Name: _hyper_1_94_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_94_chunk (
    CONSTRAINT constraint_72 CHECK (((event_time >= '2022-04-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_94_chunk OWNER TO vliz;

--
-- TOC entry 411 (class 1259 OID 6216970)
-- Name: _hyper_1_97_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_97_chunk (
    CONSTRAINT constraint_75 CHECK (((event_time >= '2022-05-05 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-12 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_97_chunk OWNER TO vliz;

--
-- TOC entry 301 (class 1259 OID 25481)
-- Name: _hyper_1_9_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_1_9_chunk (
    CONSTRAINT constraint_9 CHECK (((event_time >= '2021-10-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.pos_reports)
WITH (autovacuum_analyze_scale_factor='0.01');


ALTER TABLE _timescaledb_internal._hyper_1_9_chunk OWNER TO vliz;

--
-- TOC entry 415 (class 1259 OID 6521426)
-- Name: _hyper_2_101_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_101_chunk (
    CONSTRAINT constraint_78 CHECK (((event_time >= '2022-05-12 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-19 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_101_chunk OWNER TO vliz;

--
-- TOC entry 302 (class 1259 OID 25608)
-- Name: _hyper_2_10_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_10_chunk (
    CONSTRAINT constraint_10 CHECK (((event_time >= '2021-10-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_10_chunk OWNER TO vliz;

--
-- TOC entry 304 (class 1259 OID 25884)
-- Name: _hyper_2_12_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_12_chunk (
    CONSTRAINT constraint_12 CHECK (((event_time >= '2021-10-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_12_chunk OWNER TO vliz;

--
-- TOC entry 452 (class 1259 OID 6822282)
-- Name: _hyper_2_149_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_149_chunk (
    CONSTRAINT constraint_125 CHECK (((event_time >= '2022-05-19 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-26 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_149_chunk OWNER TO vliz;

--
-- TOC entry 306 (class 1259 OID 36438)
-- Name: _hyper_2_14_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_14_chunk (
    CONSTRAINT constraint_14 CHECK (((event_time >= '2021-10-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_14_chunk OWNER TO vliz;

--
-- TOC entry 455 (class 1259 OID 7148776)
-- Name: _hyper_2_152_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_152_chunk (
    CONSTRAINT constraint_127 CHECK (((event_time >= '2022-05-26 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_152_chunk OWNER TO vliz;

--
-- TOC entry 458 (class 1259 OID 7479152)
-- Name: _hyper_2_155_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_155_chunk (
    CONSTRAINT constraint_129 CHECK (((event_time >= '2022-06-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_155_chunk OWNER TO vliz;

--
-- TOC entry 461 (class 1259 OID 7839726)
-- Name: _hyper_2_158_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_158_chunk (
    CONSTRAINT constraint_131 CHECK (((event_time >= '2022-06-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_158_chunk OWNER TO vliz;

--
-- TOC entry 464 (class 1259 OID 8547889)
-- Name: _hyper_2_161_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_161_chunk (
    CONSTRAINT constraint_132 CHECK (((event_time >= '2022-06-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-06-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_161_chunk OWNER TO vliz;

--
-- TOC entry 468 (class 1259 OID 8980678)
-- Name: _hyper_2_165_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_165_chunk (
    CONSTRAINT constraint_135 CHECK (((event_time >= '2022-06-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_165_chunk OWNER TO vliz;

--
-- TOC entry 471 (class 1259 OID 9267749)
-- Name: _hyper_2_168_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_168_chunk (
    CONSTRAINT constraint_137 CHECK (((event_time >= '2022-07-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_168_chunk OWNER TO vliz;

--
-- TOC entry 308 (class 1259 OID 36819)
-- Name: _hyper_2_16_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_16_chunk (
    CONSTRAINT constraint_16 CHECK (((event_time >= '2021-10-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-04 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_16_chunk OWNER TO vliz;

--
-- TOC entry 476 (class 1259 OID 9736636)
-- Name: _hyper_2_173_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_173_chunk (
    CONSTRAINT constraint_141 CHECK (((event_time >= '2022-07-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_173_chunk OWNER TO vliz;

--
-- TOC entry 479 (class 1259 OID 10228150)
-- Name: _hyper_2_176_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_176_chunk (
    CONSTRAINT constraint_143 CHECK (((event_time >= '2022-07-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-07-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_176_chunk OWNER TO vliz;

--
-- TOC entry 482 (class 1259 OID 10732088)
-- Name: _hyper_2_179_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_179_chunk (
    CONSTRAINT constraint_145 CHECK (((event_time >= '2022-07-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-04 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_179_chunk OWNER TO vliz;

--
-- TOC entry 485 (class 1259 OID 11235468)
-- Name: _hyper_2_182_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_182_chunk (
    CONSTRAINT constraint_147 CHECK (((event_time >= '2022-08-04 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-11 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_182_chunk OWNER TO vliz;

--
-- TOC entry 488 (class 1259 OID 11758321)
-- Name: _hyper_2_185_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_185_chunk (
    CONSTRAINT constraint_149 CHECK (((event_time >= '2022-08-11 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-18 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_185_chunk OWNER TO vliz;

--
-- TOC entry 491 (class 1259 OID 12285413)
-- Name: _hyper_2_188_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_188_chunk (
    CONSTRAINT constraint_151 CHECK (((event_time >= '2022-08-18 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-08-25 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_188_chunk OWNER TO vliz;

--
-- TOC entry 310 (class 1259 OID 37194)
-- Name: _hyper_2_18_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_18_chunk (
    CONSTRAINT constraint_18 CHECK (((event_time >= '2021-11-04 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-11 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_18_chunk OWNER TO vliz;

--
-- TOC entry 494 (class 1259 OID 12492989)
-- Name: _hyper_2_191_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_191_chunk (
    CONSTRAINT constraint_153 CHECK (((event_time >= '2022-08-25 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-01 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_191_chunk OWNER TO vliz;

--
-- TOC entry 496 (class 1259 OID 12498857)
-- Name: _hyper_2_193_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_193_chunk (
    CONSTRAINT constraint_155 CHECK (((event_time >= '2022-09-01 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-08 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_193_chunk OWNER TO vliz;

--
-- TOC entry 499 (class 1259 OID 13022948)
-- Name: _hyper_2_196_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_196_chunk (
    CONSTRAINT constraint_157 CHECK (((event_time >= '2022-09-08 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_196_chunk OWNER TO vliz;

--
-- TOC entry 512 (class 1259 OID 14137181)
-- Name: _hyper_2_199_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_199_chunk (
    CONSTRAINT constraint_159 CHECK (((event_time >= '2022-09-15 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-22 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_199_chunk OWNER TO vliz;

--
-- TOC entry 517 (class 1259 OID 14694319)
-- Name: _hyper_2_204_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_204_chunk (
    CONSTRAINT constraint_163 CHECK (((event_time >= '2022-09-22 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-09-29 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_204_chunk OWNER TO vliz;

--
-- TOC entry 520 (class 1259 OID 15271009)
-- Name: _hyper_2_207_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_207_chunk (
    CONSTRAINT constraint_165 CHECK (((event_time >= '2022-09-29 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-06 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_207_chunk OWNER TO vliz;

--
-- TOC entry 315 (class 1259 OID 52094)
-- Name: _hyper_2_20_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_20_chunk (
    CONSTRAINT constraint_20 CHECK (((event_time >= '2021-11-11 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-18 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_20_chunk OWNER TO vliz;

--
-- TOC entry 523 (class 1259 OID 15848147)
-- Name: _hyper_2_210_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_210_chunk (
    CONSTRAINT constraint_167 CHECK (((event_time >= '2022-10-06 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_210_chunk OWNER TO vliz;

--
-- TOC entry 527 (class 1259 OID 16429909)
-- Name: _hyper_2_213_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_213_chunk (
    CONSTRAINT constraint_169 CHECK (((event_time >= '2022-10-13 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-20 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_213_chunk OWNER TO vliz;

--
-- TOC entry 531 (class 1259 OID 16996360)
-- Name: _hyper_2_215_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_215_chunk (
    CONSTRAINT constraint_170 CHECK (((event_time >= '2022-10-20 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-10-27 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_215_chunk OWNER TO vliz;

--
-- TOC entry 539 (class 1259 OID 17552497)
-- Name: _hyper_2_219_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_219_chunk (
    CONSTRAINT constraint_173 CHECK (((event_time >= '2022-10-27 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_219_chunk OWNER TO vliz;

--
-- TOC entry 542 (class 1259 OID 18081996)
-- Name: _hyper_2_222_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_222_chunk (
    CONSTRAINT constraint_175 CHECK (((event_time >= '2022-11-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_222_chunk OWNER TO vliz;

--
-- TOC entry 546 (class 1259 OID 18797347)
-- Name: _hyper_2_225_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_225_chunk (
    CONSTRAINT constraint_177 CHECK (((event_time >= '2022-11-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_225_chunk OWNER TO vliz;

--
-- TOC entry 549 (class 1259 OID 20176732)
-- Name: _hyper_2_228_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_228_chunk (
    CONSTRAINT constraint_179 CHECK (((event_time >= '2022-11-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-11-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_228_chunk OWNER TO vliz;

--
-- TOC entry 318 (class 1259 OID 52557)
-- Name: _hyper_2_22_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_22_chunk (
    CONSTRAINT constraint_22 CHECK (((event_time >= '2021-11-18 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-11-25 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_22_chunk OWNER TO vliz;

--
-- TOC entry 552 (class 1259 OID 21597026)
-- Name: _hyper_2_231_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_231_chunk (
    CONSTRAINT constraint_181 CHECK (((event_time >= '2022-11-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-01 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_231_chunk OWNER TO vliz;

--
-- TOC entry 557 (class 1259 OID 23006085)
-- Name: _hyper_2_236_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_236_chunk (
    CONSTRAINT constraint_185 CHECK (((event_time >= '2022-12-01 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-08 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_236_chunk OWNER TO vliz;

--
-- TOC entry 565 (class 1259 OID 25832599)
-- Name: _hyper_2_240_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_240_chunk (
    CONSTRAINT constraint_187 CHECK (((event_time >= '2022-12-08 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_240_chunk OWNER TO vliz;

--
-- TOC entry 568 (class 1259 OID 27178901)
-- Name: _hyper_2_243_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_243_chunk (
    CONSTRAINT constraint_189 CHECK (((event_time >= '2022-12-15 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-22 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_243_chunk OWNER TO vliz;

--
-- TOC entry 571 (class 1259 OID 28545448)
-- Name: _hyper_2_246_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_246_chunk (
    CONSTRAINT constraint_191 CHECK (((event_time >= '2022-12-22 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-12-29 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_246_chunk OWNER TO vliz;

--
-- TOC entry 574 (class 1259 OID 29876902)
-- Name: _hyper_2_249_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_249_chunk (
    CONSTRAINT constraint_193 CHECK (((event_time >= '2022-12-29 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_249_chunk OWNER TO vliz;

--
-- TOC entry 320 (class 1259 OID 52929)
-- Name: _hyper_2_24_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_24_chunk (
    CONSTRAINT constraint_24 CHECK (((event_time >= '2021-11-25 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_24_chunk OWNER TO vliz;

--
-- TOC entry 577 (class 1259 OID 31351421)
-- Name: _hyper_2_252_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_252_chunk (
    CONSTRAINT constraint_195 CHECK (((event_time >= '2023-01-05 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-12 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_252_chunk OWNER TO vliz;

--
-- TOC entry 579 (class 1259 OID 32687021)
-- Name: _hyper_2_254_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_254_chunk (
    CONSTRAINT constraint_196 CHECK (((event_time >= '2023-01-12 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-19 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_254_chunk OWNER TO vliz;

--
-- TOC entry 583 (class 1259 OID 34051009)
-- Name: _hyper_2_258_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_258_chunk (
    CONSTRAINT constraint_199 CHECK (((event_time >= '2023-01-19 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-01-26 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_258_chunk OWNER TO vliz;

--
-- TOC entry 586 (class 1259 OID 35482480)
-- Name: _hyper_2_261_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_261_chunk (
    CONSTRAINT constraint_201 CHECK (((event_time >= '2023-01-26 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_261_chunk OWNER TO vliz;

--
-- TOC entry 588 (class 1259 OID 35494470)
-- Name: _hyper_2_263_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_263_chunk (
    CONSTRAINT constraint_203 CHECK (((event_time >= '2023-02-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_263_chunk OWNER TO vliz;

--
-- TOC entry 593 (class 1259 OID 36945281)
-- Name: _hyper_2_268_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_268_chunk (
    CONSTRAINT constraint_207 CHECK (((event_time >= '2023-02-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_268_chunk OWNER TO vliz;

--
-- TOC entry 322 (class 1259 OID 66593)
-- Name: _hyper_2_26_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_26_chunk (
    CONSTRAINT constraint_26 CHECK (((event_time >= '2021-12-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_26_chunk OWNER TO vliz;

--
-- TOC entry 596 (class 1259 OID 38434302)
-- Name: _hyper_2_271_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_271_chunk (
    CONSTRAINT constraint_209 CHECK (((event_time >= '2023-02-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-02-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_271_chunk OWNER TO vliz;

--
-- TOC entry 599 (class 1259 OID 40050751)
-- Name: _hyper_2_274_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_274_chunk (
    CONSTRAINT constraint_211 CHECK (((event_time >= '2023-02-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_274_chunk OWNER TO vliz;

--
-- TOC entry 602 (class 1259 OID 41383287)
-- Name: _hyper_2_277_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_277_chunk (
    CONSTRAINT constraint_213 CHECK (((event_time >= '2023-03-02 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_277_chunk OWNER TO vliz;

--
-- TOC entry 606 (class 1259 OID 44240100)
-- Name: _hyper_2_281_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_281_chunk (
    CONSTRAINT constraint_215 CHECK (((event_time >= '2023-03-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_281_chunk OWNER TO vliz;

--
-- TOC entry 609 (class 1259 OID 45689986)
-- Name: _hyper_2_284_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_284_chunk (
    CONSTRAINT constraint_217 CHECK (((event_time >= '2023-03-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2023-03-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports);


ALTER TABLE _timescaledb_internal._hyper_2_284_chunk OWNER TO vliz;

--
-- TOC entry 324 (class 1259 OID 67014)
-- Name: _hyper_2_28_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_28_chunk (
    CONSTRAINT constraint_28 CHECK (((event_time >= '2021-12-09 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-16 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_28_chunk OWNER TO vliz;

--
-- TOC entry 284 (class 1259 OID 24677)
-- Name: _hyper_2_2_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_2_chunk (
    CONSTRAINT constraint_2 CHECK (((event_time >= '2021-09-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-09-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_2_chunk OWNER TO vliz;

--
-- TOC entry 328 (class 1259 OID 67591)
-- Name: _hyper_2_32_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_32_chunk (
    CONSTRAINT constraint_32 CHECK (((event_time >= '2021-12-16 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-23 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_32_chunk OWNER TO vliz;

--
-- TOC entry 335 (class 1259 OID 76862)
-- Name: _hyper_2_34_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_34_chunk (
    CONSTRAINT constraint_34 CHECK (((event_time >= '2021-12-23 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-12-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_34_chunk OWNER TO vliz;

--
-- TOC entry 338 (class 1259 OID 123162)
-- Name: _hyper_2_36_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_36_chunk (
    CONSTRAINT constraint_36 CHECK (((event_time >= '2021-12-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-06 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_36_chunk OWNER TO vliz;

--
-- TOC entry 340 (class 1259 OID 123536)
-- Name: _hyper_2_38_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_38_chunk (
    CONSTRAINT constraint_38 CHECK (((event_time >= '2022-01-06 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_38_chunk OWNER TO vliz;

--
-- TOC entry 343 (class 1259 OID 123922)
-- Name: _hyper_2_40_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_40_chunk (
    CONSTRAINT constraint_40 CHECK (((event_time >= '2022-01-13 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-20 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_40_chunk OWNER TO vliz;

--
-- TOC entry 345 (class 1259 OID 126264)
-- Name: _hyper_2_42_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_42_chunk (
    CONSTRAINT constraint_42 CHECK (((event_time >= '2022-01-20 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-01-27 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_42_chunk OWNER TO vliz;

--
-- TOC entry 348 (class 1259 OID 126667)
-- Name: _hyper_2_44_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_44_chunk (
    CONSTRAINT constraint_44 CHECK (((event_time >= '2022-01-27 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_44_chunk OWNER TO vliz;

--
-- TOC entry 350 (class 1259 OID 127038)
-- Name: _hyper_2_46_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_46_chunk (
    CONSTRAINT constraint_46 CHECK (((event_time >= '2022-02-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_46_chunk OWNER TO vliz;

--
-- TOC entry 355 (class 1259 OID 133026)
-- Name: _hyper_2_48_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_48_chunk (
    CONSTRAINT constraint_48 CHECK (((event_time >= '2022-02-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_48_chunk OWNER TO vliz;

--
-- TOC entry 358 (class 1259 OID 137242)
-- Name: _hyper_2_50_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_50_chunk (
    CONSTRAINT constraint_50 CHECK (((event_time >= '2022-02-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-02-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_50_chunk OWNER TO vliz;

--
-- TOC entry 362 (class 1259 OID 141195)
-- Name: _hyper_2_54_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_54_chunk (
    CONSTRAINT constraint_54 CHECK (((event_time >= '2022-02-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-03 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_54_chunk OWNER TO vliz;

--
-- TOC entry 367 (class 1259 OID 145614)
-- Name: _hyper_2_56_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_56_chunk (
    CONSTRAINT constraint_56 CHECK (((event_time >= '2022-03-03 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-10 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_56_chunk OWNER TO vliz;

--
-- TOC entry 369 (class 1259 OID 150394)
-- Name: _hyper_2_58_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_58_chunk (
    CONSTRAINT constraint_58 CHECK (((event_time >= '2022-03-10 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_58_chunk OWNER TO vliz;

--
-- TOC entry 371 (class 1259 OID 156242)
-- Name: _hyper_2_60_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_60_chunk (
    CONSTRAINT constraint_60 CHECK (((event_time >= '2022-03-17 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_60_chunk OWNER TO vliz;

--
-- TOC entry 373 (class 1259 OID 162854)
-- Name: _hyper_2_62_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_62_chunk (
    CONSTRAINT constraint_62 CHECK (((event_time >= '2022-03-24 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-03-31 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_62_chunk OWNER TO vliz;

--
-- TOC entry 375 (class 1259 OID 170240)
-- Name: _hyper_2_64_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_64_chunk (
    CONSTRAINT constraint_64 CHECK (((event_time >= '2022-03-31 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_64_chunk OWNER TO vliz;

--
-- TOC entry 378 (class 1259 OID 176695)
-- Name: _hyper_2_66_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_66_chunk (
    CONSTRAINT constraint_66 CHECK (((event_time >= '2022-04-07 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-14 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_66_chunk OWNER TO vliz;

--
-- TOC entry 297 (class 1259 OID 25286)
-- Name: _hyper_2_7_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_7_chunk (
    CONSTRAINT constraint_7 CHECK (((event_time >= '2021-09-30 00:00:00+00'::timestamp with time zone) AND (event_time < '2021-10-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_7_chunk OWNER TO vliz;

--
-- TOC entry 401 (class 1259 OID 5625477)
-- Name: _hyper_2_88_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_88_chunk (
    CONSTRAINT constraint_68 CHECK (((event_time >= '2022-04-14 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-21 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_88_chunk OWNER TO vliz;

--
-- TOC entry 404 (class 1259 OID 5912411)
-- Name: _hyper_2_91_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_91_chunk (
    CONSTRAINT constraint_70 CHECK (((event_time >= '2022-04-21 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-04-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_91_chunk OWNER TO vliz;

--
-- TOC entry 407 (class 1259 OID 6212200)
-- Name: _hyper_2_93_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_93_chunk (
    CONSTRAINT constraint_71 CHECK (((event_time >= '2022-04-28 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-05 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_93_chunk OWNER TO vliz;

--
-- TOC entry 412 (class 1259 OID 6216981)
-- Name: _hyper_2_98_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_2_98_chunk (
    CONSTRAINT constraint_76 CHECK (((event_time >= '2022-05-05 00:00:00+00'::timestamp with time zone) AND (event_time < '2022-05-12 00:00:00+00'::timestamp with time zone)))
)
INHERITS (ais.voy_reports)
WITH (autovacuum_enabled='false');


ALTER TABLE _timescaledb_internal._hyper_2_98_chunk OWNER TO vliz;

--
-- TOC entry 285 (class 1259 OID 24854)
-- Name: _materialized_hypertable_4; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._materialized_hypertable_4 (
    mmsi text,
    routing_key text,
    bucket timestamp with time zone NOT NULL,
    agg_4_4 bytea,
    agg_5_5 bytea,
    agg_6_6 bytea,
    agg_7_7 bytea,
    agg_8_8 bytea,
    agg_9_9 bytea,
    agg_10_10 bytea,
    agg_11_11 bytea,
    agg_12_12 bytea,
    agg_13_13 bytea,
    agg_14_14 bytea,
    agg_15_15 bytea,
    agg_16_16 bytea,
    agg_17_17 bytea,
    agg_18_18 bytea,
    agg_19_19 bytea,
    agg_20_20 bytea,
    agg_21_21 bytea,
    agg_22_22 bytea,
    chunk_id integer
);


ALTER TABLE _timescaledb_internal._materialized_hypertable_4 OWNER TO vliz;

--
-- TOC entry 449 (class 1259 OID 6821060)
-- Name: _hyper_4_146_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_146_chunk (
    CONSTRAINT constraint_122 CHECK (((bucket >= '2020-03-19 00:00:00+00'::timestamp with time zone) AND (bucket < '2020-05-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_146_chunk OWNER TO vliz;

--
-- TOC entry 450 (class 1259 OID 6821070)
-- Name: _hyper_4_147_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_147_chunk (
    CONSTRAINT constraint_123 CHECK (((bucket >= '2020-05-28 00:00:00+00'::timestamp with time zone) AND (bucket < '2020-08-06 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_147_chunk OWNER TO vliz;

--
-- TOC entry 472 (class 1259 OID 9268398)
-- Name: _hyper_4_169_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_169_chunk (
    CONSTRAINT constraint_138 CHECK (((bucket >= '2022-07-07 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-09-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_169_chunk OWNER TO vliz;

--
-- TOC entry 513 (class 1259 OID 14138715)
-- Name: _hyper_4_200_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_200_chunk (
    CONSTRAINT constraint_160 CHECK (((bucket >= '2022-09-15 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-11-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_200_chunk OWNER TO vliz;

--
-- TOC entry 553 (class 1259 OID 21597729)
-- Name: _hyper_4_232_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_232_chunk (
    CONSTRAINT constraint_182 CHECK (((bucket >= '2022-11-24 00:00:00+00'::timestamp with time zone) AND (bucket < '2023-02-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_232_chunk OWNER TO vliz;

--
-- TOC entry 589 (class 1259 OID 35495207)
-- Name: _hyper_4_264_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_264_chunk (
    CONSTRAINT constraint_204 CHECK (((bucket >= '2023-02-02 00:00:00+00'::timestamp with time zone) AND (bucket < '2023-04-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_264_chunk OWNER TO vliz;

--
-- TOC entry 325 (class 1259 OID 67218)
-- Name: _hyper_4_29_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_29_chunk (
    CONSTRAINT constraint_29 CHECK (((bucket >= '2021-12-09 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-02-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_29_chunk OWNER TO vliz;

--
-- TOC entry 294 (class 1259 OID 24919)
-- Name: _hyper_4_4_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_4_chunk (
    CONSTRAINT constraint_4 CHECK (((bucket >= '2021-07-22 00:00:00+00'::timestamp with time zone) AND (bucket < '2021-09-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_4_chunk OWNER TO vliz;

--
-- TOC entry 359 (class 1259 OID 137436)
-- Name: _hyper_4_51_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_51_chunk (
    CONSTRAINT constraint_51 CHECK (((bucket >= '2022-02-17 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-04-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_51_chunk OWNER TO vliz;

--
-- TOC entry 296 (class 1259 OID 25108)
-- Name: _hyper_4_6_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_6_chunk (
    CONSTRAINT constraint_6 CHECK (((bucket >= '2021-09-30 00:00:00+00'::timestamp with time zone) AND (bucket < '2021-12-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_6_chunk OWNER TO vliz;

--
-- TOC entry 409 (class 1259 OID 6212400)
-- Name: _hyper_4_95_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_4_95_chunk (
    CONSTRAINT constraint_73 CHECK (((bucket >= '2022-04-28 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-07-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_4);


ALTER TABLE _timescaledb_internal._hyper_4_95_chunk OWNER TO vliz;

--
-- TOC entry 289 (class 1259 OID 24882)
-- Name: _materialized_hypertable_5; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._materialized_hypertable_5 (
    mmsi text,
    routing_key text,
    bucket timestamp with time zone NOT NULL,
    agg_4_4 bytea,
    agg_5_5 bytea,
    agg_6_6 bytea,
    agg_7_7 bytea,
    agg_8_8 bytea,
    agg_9_9 bytea,
    agg_10_10 bytea,
    agg_11_11 bytea,
    agg_12_12 bytea,
    agg_13_13 bytea,
    agg_14_14 bytea,
    agg_15_15 bytea,
    agg_16_16 bytea,
    agg_17_17 bytea,
    chunk_id integer
);


ALTER TABLE _timescaledb_internal._materialized_hypertable_5 OWNER TO vliz;

--
-- TOC entry 473 (class 1259 OID 9269635)
-- Name: _hyper_5_170_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_170_chunk (
    CONSTRAINT constraint_139 CHECK (((bucket >= '2022-07-07 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-09-15 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_170_chunk OWNER TO vliz;

--
-- TOC entry 514 (class 1259 OID 14139324)
-- Name: _hyper_5_201_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_201_chunk (
    CONSTRAINT constraint_161 CHECK (((bucket >= '2022-09-15 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-11-24 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_201_chunk OWNER TO vliz;

--
-- TOC entry 554 (class 1259 OID 21599799)
-- Name: _hyper_5_233_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_233_chunk (
    CONSTRAINT constraint_183 CHECK (((bucket >= '2022-11-24 00:00:00+00'::timestamp with time zone) AND (bucket < '2023-02-02 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_233_chunk OWNER TO vliz;

--
-- TOC entry 590 (class 1259 OID 35495896)
-- Name: _hyper_5_265_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_265_chunk (
    CONSTRAINT constraint_205 CHECK (((bucket >= '2023-02-02 00:00:00+00'::timestamp with time zone) AND (bucket < '2023-04-13 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_265_chunk OWNER TO vliz;

--
-- TOC entry 326 (class 1259 OID 67338)
-- Name: _hyper_5_30_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_30_chunk (
    CONSTRAINT constraint_30 CHECK (((bucket >= '2021-12-09 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-02-17 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_30_chunk OWNER TO vliz;

--
-- TOC entry 293 (class 1259 OID 24909)
-- Name: _hyper_5_3_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_3_chunk (
    CONSTRAINT constraint_3 CHECK (((bucket >= '2021-07-22 00:00:00+00'::timestamp with time zone) AND (bucket < '2021-09-30 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_3_chunk OWNER TO vliz;

--
-- TOC entry 360 (class 1259 OID 137675)
-- Name: _hyper_5_52_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_52_chunk (
    CONSTRAINT constraint_52 CHECK (((bucket >= '2022-02-17 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-04-28 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_52_chunk OWNER TO vliz;

--
-- TOC entry 298 (class 1259 OID 25323)
-- Name: _hyper_5_8_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_8_chunk (
    CONSTRAINT constraint_8 CHECK (((bucket >= '2021-09-30 00:00:00+00'::timestamp with time zone) AND (bucket < '2021-12-09 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_8_chunk OWNER TO vliz;

--
-- TOC entry 410 (class 1259 OID 6212564)
-- Name: _hyper_5_96_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal._hyper_5_96_chunk (
    CONSTRAINT constraint_74 CHECK (((bucket >= '2022-04-28 00:00:00+00'::timestamp with time zone) AND (bucket < '2022-07-07 00:00:00+00'::timestamp with time zone)))
)
INHERITS (_timescaledb_internal._materialized_hypertable_5);


ALTER TABLE _timescaledb_internal._hyper_5_96_chunk OWNER TO vliz;

--
-- TOC entry 287 (class 1259 OID 24869)
-- Name: _partial_view_4; Type: VIEW; Schema: _timescaledb_internal; Owner: vliz
--

CREATE VIEW _timescaledb_internal._partial_view_4 AS
 SELECT pos_reports.mmsi,
    pos_reports.routing_key,
    public.time_bucket('01:00:00'::interval, pos_reports.event_time) AS bucket,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.navigation_status, pos_reports.event_time)) AS agg_4_4,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.rot, pos_reports.event_time)) AS agg_5_5,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.sog, pos_reports.event_time)) AS agg_6_6,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.longitude, pos_reports.event_time)) AS agg_7_7,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.latitude, pos_reports.event_time)) AS agg_8_8,
    _timescaledb_internal.partialize_agg(public.last(pos_reports."position", pos_reports.event_time)) AS agg_9_9,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.cog, pos_reports.event_time)) AS agg_10_10,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.hdg, pos_reports.event_time)) AS agg_11_11,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.event_time, pos_reports.event_time)) AS agg_12_12,
    _timescaledb_internal.partialize_agg(public.last(pos_reports.msg_type, pos_reports.event_time)) AS agg_13_13,
    _timescaledb_internal.partialize_agg(avg(pos_reports.sog)) AS agg_14_14,
    _timescaledb_internal.partialize_agg(min(pos_reports.sog)) AS agg_15_15,
    _timescaledb_internal.partialize_agg(max(pos_reports.sog)) AS agg_16_16,
    _timescaledb_internal.partialize_agg(avg(pos_reports.cog)) AS agg_17_17,
    _timescaledb_internal.partialize_agg(min(pos_reports.cog)) AS agg_18_18,
    _timescaledb_internal.partialize_agg(max(pos_reports.cog)) AS agg_19_19,
    _timescaledb_internal.partialize_agg(avg(pos_reports.hdg)) AS agg_20_20,
    _timescaledb_internal.partialize_agg(min(pos_reports.hdg)) AS agg_21_21,
    _timescaledb_internal.partialize_agg(max(pos_reports.hdg)) AS agg_22_22,
    _timescaledb_internal.chunk_id_from_relid(pos_reports.tableoid) AS chunk_id
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, pos_reports.routing_key, (public.time_bucket('01:00:00'::interval, pos_reports.event_time)), (_timescaledb_internal.chunk_id_from_relid(pos_reports.tableoid));


ALTER TABLE _timescaledb_internal._partial_view_4 OWNER TO vliz;

--
-- TOC entry 291 (class 1259 OID 24897)
-- Name: _partial_view_5; Type: VIEW; Schema: _timescaledb_internal; Owner: vliz
--

CREATE VIEW _timescaledb_internal._partial_view_5 AS
 SELECT voy_reports.mmsi,
    voy_reports.routing_key,
    public.time_bucket('06:00:00'::interval, voy_reports.event_time) AS bucket,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.imo, voy_reports.event_time)) AS agg_4_4,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.callsign, voy_reports.event_time)) AS agg_5_5,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.name, voy_reports.event_time)) AS agg_6_6,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.type_and_cargo, voy_reports.event_time)) AS agg_7_7,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.to_bow, voy_reports.event_time)) AS agg_8_8,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.to_stern, voy_reports.event_time)) AS agg_9_9,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.to_port, voy_reports.event_time)) AS agg_10_10,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.to_starboard, voy_reports.event_time)) AS agg_11_11,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.fix_type, voy_reports.event_time)) AS agg_12_12,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.eta, voy_reports.event_time)) AS agg_13_13,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.draught, voy_reports.event_time)) AS agg_14_14,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.destination, voy_reports.event_time)) AS agg_15_15,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.event_time, voy_reports.event_time)) AS agg_16_16,
    _timescaledb_internal.partialize_agg(public.last(voy_reports.msg_type, voy_reports.event_time)) AS agg_17_17,
    _timescaledb_internal.chunk_id_from_relid(voy_reports.tableoid) AS chunk_id
   FROM ais.voy_reports
  GROUP BY voy_reports.mmsi, voy_reports.routing_key, (public.time_bucket('06:00:00'::interval, voy_reports.event_time)), (_timescaledb_internal.chunk_id_from_relid(voy_reports.tableoid));


ALTER TABLE _timescaledb_internal._partial_view_5 OWNER TO vliz;

--
-- TOC entry 417 (class 1259 OID 6522661)
-- Name: compress_hyper_6_102_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_102_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_102_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_102_chunk OWNER TO vliz;

--
-- TOC entry 453 (class 1259 OID 6823628)
-- Name: compress_hyper_6_150_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_150_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_150_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_150_chunk OWNER TO vliz;

--
-- TOC entry 456 (class 1259 OID 7150914)
-- Name: compress_hyper_6_153_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_153_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_153_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_153_chunk OWNER TO vliz;

--
-- TOC entry 459 (class 1259 OID 7481160)
-- Name: compress_hyper_6_156_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_156_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_156_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_156_chunk OWNER TO vliz;

--
-- TOC entry 462 (class 1259 OID 7841786)
-- Name: compress_hyper_6_159_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_159_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_159_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_159_chunk OWNER TO vliz;

--
-- TOC entry 463 (class 1259 OID 8180518)
-- Name: compress_hyper_6_160_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_160_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_160_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_160_chunk OWNER TO vliz;

--
-- TOC entry 466 (class 1259 OID 8549001)
-- Name: compress_hyper_6_163_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_163_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_163_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_163_chunk OWNER TO vliz;

--
-- TOC entry 469 (class 1259 OID 8982927)
-- Name: compress_hyper_6_166_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_166_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_166_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_166_chunk OWNER TO vliz;

--
-- TOC entry 474 (class 1259 OID 9270054)
-- Name: compress_hyper_6_171_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_171_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_171_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_171_chunk OWNER TO vliz;

--
-- TOC entry 477 (class 1259 OID 9738845)
-- Name: compress_hyper_6_174_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_174_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_174_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_174_chunk OWNER TO vliz;

--
-- TOC entry 480 (class 1259 OID 10230442)
-- Name: compress_hyper_6_177_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_177_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_177_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_177_chunk OWNER TO vliz;

--
-- TOC entry 483 (class 1259 OID 10734112)
-- Name: compress_hyper_6_180_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_180_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_180_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_180_chunk OWNER TO vliz;

--
-- TOC entry 486 (class 1259 OID 11237754)
-- Name: compress_hyper_6_183_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_183_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_183_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_183_chunk OWNER TO vliz;

--
-- TOC entry 489 (class 1259 OID 11760504)
-- Name: compress_hyper_6_186_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_186_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_186_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_186_chunk OWNER TO vliz;

--
-- TOC entry 492 (class 1259 OID 12287748)
-- Name: compress_hyper_6_189_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_189_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_189_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_189_chunk OWNER TO vliz;

--
-- TOC entry 497 (class 1259 OID 12500950)
-- Name: compress_hyper_6_194_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_194_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_194_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_194_chunk OWNER TO vliz;

--
-- TOC entry 500 (class 1259 OID 13044350)
-- Name: compress_hyper_6_197_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_197_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_197_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_197_chunk OWNER TO vliz;

--
-- TOC entry 515 (class 1259 OID 14140532)
-- Name: compress_hyper_6_202_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_202_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_202_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_202_chunk OWNER TO vliz;

--
-- TOC entry 518 (class 1259 OID 14697486)
-- Name: compress_hyper_6_205_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_205_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_205_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_205_chunk OWNER TO vliz;

--
-- TOC entry 521 (class 1259 OID 15274318)
-- Name: compress_hyper_6_208_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_208_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_208_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_208_chunk OWNER TO vliz;

--
-- TOC entry 524 (class 1259 OID 15851237)
-- Name: compress_hyper_6_211_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_211_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_211_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_211_chunk OWNER TO vliz;

--
-- TOC entry 528 (class 1259 OID 16433193)
-- Name: compress_hyper_6_214_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_214_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_214_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_214_chunk OWNER TO vliz;

--
-- TOC entry 533 (class 1259 OID 16999729)
-- Name: compress_hyper_6_217_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_217_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_217_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_217_chunk OWNER TO vliz;

--
-- TOC entry 540 (class 1259 OID 17556892)
-- Name: compress_hyper_6_220_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_220_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_220_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_220_chunk OWNER TO vliz;

--
-- TOC entry 543 (class 1259 OID 18085332)
-- Name: compress_hyper_6_223_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_223_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_223_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_223_chunk OWNER TO vliz;

--
-- TOC entry 547 (class 1259 OID 18803841)
-- Name: compress_hyper_6_226_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_226_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_226_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_226_chunk OWNER TO vliz;

--
-- TOC entry 550 (class 1259 OID 20179770)
-- Name: compress_hyper_6_229_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_229_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_229_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_229_chunk OWNER TO vliz;

--
-- TOC entry 555 (class 1259 OID 21600311)
-- Name: compress_hyper_6_234_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_234_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_234_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_234_chunk OWNER TO vliz;

--
-- TOC entry 561 (class 1259 OID 23019367)
-- Name: compress_hyper_6_237_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_237_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_237_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_237_chunk OWNER TO vliz;

--
-- TOC entry 562 (class 1259 OID 24387294)
-- Name: compress_hyper_6_238_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_238_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_238_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_238_chunk OWNER TO vliz;

--
-- TOC entry 566 (class 1259 OID 25841323)
-- Name: compress_hyper_6_241_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_241_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_241_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_241_chunk OWNER TO vliz;

--
-- TOC entry 569 (class 1259 OID 27187365)
-- Name: compress_hyper_6_244_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_244_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_244_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_244_chunk OWNER TO vliz;

--
-- TOC entry 572 (class 1259 OID 28552147)
-- Name: compress_hyper_6_247_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_247_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_247_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_247_chunk OWNER TO vliz;

--
-- TOC entry 575 (class 1259 OID 29883725)
-- Name: compress_hyper_6_250_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_250_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_250_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_250_chunk OWNER TO vliz;

--
-- TOC entry 578 (class 1259 OID 31358970)
-- Name: compress_hyper_6_253_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_253_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_253_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_253_chunk OWNER TO vliz;

--
-- TOC entry 581 (class 1259 OID 32695052)
-- Name: compress_hyper_6_256_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_256_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_256_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_256_chunk OWNER TO vliz;

--
-- TOC entry 584 (class 1259 OID 34062773)
-- Name: compress_hyper_6_259_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_259_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_259_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_259_chunk OWNER TO vliz;

--
-- TOC entry 591 (class 1259 OID 35497646)
-- Name: compress_hyper_6_266_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_266_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_266_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_266_chunk OWNER TO vliz;

--
-- TOC entry 594 (class 1259 OID 36948693)
-- Name: compress_hyper_6_269_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_269_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_269_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_269_chunk OWNER TO vliz;

--
-- TOC entry 597 (class 1259 OID 38437775)
-- Name: compress_hyper_6_272_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_272_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_272_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_272_chunk OWNER TO vliz;

--
-- TOC entry 600 (class 1259 OID 40054062)
-- Name: compress_hyper_6_275_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_275_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_275_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_275_chunk OWNER TO vliz;

--
-- TOC entry 603 (class 1259 OID 41386473)
-- Name: compress_hyper_6_278_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_278_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_278_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_278_chunk OWNER TO vliz;

--
-- TOC entry 604 (class 1259 OID 42803136)
-- Name: compress_hyper_6_279_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_279_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_279_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_279_chunk OWNER TO vliz;

--
-- TOC entry 607 (class 1259 OID 44249040)
-- Name: compress_hyper_6_282_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_282_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_282_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_282_chunk OWNER TO vliz;

--
-- TOC entry 610 (class 1259 OID 45699889)
-- Name: compress_hyper_6_285_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_285_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_285_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_285_chunk OWNER TO vliz;

--
-- TOC entry 380 (class 1259 OID 180189)
-- Name: compress_hyper_6_67_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_67_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_67_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_67_chunk OWNER TO vliz;

--
-- TOC entry 381 (class 1259 OID 180202)
-- Name: compress_hyper_6_68_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_68_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_68_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_68_chunk OWNER TO vliz;

--
-- TOC entry 382 (class 1259 OID 180217)
-- Name: compress_hyper_6_69_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_69_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_69_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_69_chunk OWNER TO vliz;

--
-- TOC entry 383 (class 1259 OID 325395)
-- Name: compress_hyper_6_70_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_70_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_70_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_70_chunk OWNER TO vliz;

--
-- TOC entry 384 (class 1259 OID 714986)
-- Name: compress_hyper_6_71_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_71_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_71_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_71_chunk OWNER TO vliz;

--
-- TOC entry 385 (class 1259 OID 1088737)
-- Name: compress_hyper_6_72_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_72_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_72_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_72_chunk OWNER TO vliz;

--
-- TOC entry 386 (class 1259 OID 1443750)
-- Name: compress_hyper_6_73_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_73_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_73_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_73_chunk OWNER TO vliz;

--
-- TOC entry 387 (class 1259 OID 1783759)
-- Name: compress_hyper_6_74_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_74_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_74_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_74_chunk OWNER TO vliz;

--
-- TOC entry 388 (class 1259 OID 2108316)
-- Name: compress_hyper_6_75_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_75_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_75_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_75_chunk OWNER TO vliz;

--
-- TOC entry 389 (class 1259 OID 2443232)
-- Name: compress_hyper_6_76_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_76_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_76_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_76_chunk OWNER TO vliz;

--
-- TOC entry 390 (class 1259 OID 2749782)
-- Name: compress_hyper_6_77_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_77_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_77_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_77_chunk OWNER TO vliz;

--
-- TOC entry 391 (class 1259 OID 3072544)
-- Name: compress_hyper_6_78_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_78_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_78_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_78_chunk OWNER TO vliz;

--
-- TOC entry 392 (class 1259 OID 3370646)
-- Name: compress_hyper_6_79_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_79_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_79_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_79_chunk OWNER TO vliz;

--
-- TOC entry 393 (class 1259 OID 3668229)
-- Name: compress_hyper_6_80_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_80_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_80_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_80_chunk OWNER TO vliz;

--
-- TOC entry 394 (class 1259 OID 3959394)
-- Name: compress_hyper_6_81_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_81_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_81_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_81_chunk OWNER TO vliz;

--
-- TOC entry 395 (class 1259 OID 4240223)
-- Name: compress_hyper_6_82_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_82_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_82_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_82_chunk OWNER TO vliz;

--
-- TOC entry 396 (class 1259 OID 4513604)
-- Name: compress_hyper_6_83_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_83_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_83_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_83_chunk OWNER TO vliz;

--
-- TOC entry 397 (class 1259 OID 4789172)
-- Name: compress_hyper_6_84_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_84_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_84_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_84_chunk OWNER TO vliz;

--
-- TOC entry 398 (class 1259 OID 5070218)
-- Name: compress_hyper_6_85_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_85_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_85_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_85_chunk OWNER TO vliz;

--
-- TOC entry 399 (class 1259 OID 5337841)
-- Name: compress_hyper_6_86_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_86_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_86_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_86_chunk OWNER TO vliz;

--
-- TOC entry 402 (class 1259 OID 5630298)
-- Name: compress_hyper_6_89_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_89_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_89_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_89_chunk OWNER TO vliz;

--
-- TOC entry 406 (class 1259 OID 5917072)
-- Name: compress_hyper_6_92_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_92_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_92_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_92_chunk OWNER TO vliz;

--
-- TOC entry 413 (class 1259 OID 6218794)
-- Name: compress_hyper_6_99_chunk; Type: TABLE; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TABLE _timescaledb_internal.compress_hyper_6_99_chunk (
)
INHERITS (_timescaledb_internal._compressed_hypertable_6)
WITH (toast_tuple_target='128');
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN mmsi SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN imo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN imo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN callsign SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN callsign SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN name SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN name SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN type_and_cargo SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN type_and_cargo SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN to_bow SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN to_stern SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN to_port SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN to_starboard SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN fix_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN eta_month SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN eta_day SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN eta_hour SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN eta_minute SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN eta SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN draught SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN draught SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN destination SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN destination SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN event_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN server_time SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN msg_type SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN msg_type SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN routing_key SET STATISTICS 0;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN routing_key SET STORAGE EXTENDED;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN _ts_meta_count SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN _ts_meta_sequence_num SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN _ts_meta_min_1 SET STATISTICS 1000;
ALTER TABLE ONLY _timescaledb_internal.compress_hyper_6_99_chunk ALTER COLUMN _ts_meta_max_1 SET STATISTICS 1000;


ALTER TABLE _timescaledb_internal.compress_hyper_6_99_chunk OWNER TO vliz;

--
-- TOC entry 264 (class 1259 OID 17967)
-- Name: ais_num_to_type; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.ais_num_to_type (
    ais_num character varying(3) NOT NULL,
    description text,
    type text,
    sub_type text,
    abrv character varying(3) NOT NULL
);


ALTER TABLE ais.ais_num_to_type OWNER TO vliz;

--
-- TOC entry 316 (class 1259 OID 52447)
-- Name: aishub_primer_vessels; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.aishub_primer_vessels (
    mmsi text,
    tstamp timestamp with time zone,
    latitude double precision,
    longitude double precision,
    cog numeric(4,1),
    sog numeric(4,1),
    heading numeric(4,1),
    navstat character(3),
    imo text,
    name text,
    callsign text,
    type text,
    a smallint,
    b smallint,
    c smallint,
    d smallint,
    draught numeric(4,1)
);


ALTER TABLE ais.aishub_primer_vessels OWNER TO vliz;

--
-- TOC entry 299 (class 1259 OID 25405)
-- Name: ferry_cluster; Type: VIEW; Schema: ais; Owner: vliz
--

CREATE VIEW ais.ferry_cluster AS
 WITH ferry_data AS (
         SELECT aa.mmsi,
            aa.navigation_status,
            aa.rot,
            aa.sog,
            aa.longitude,
            aa.latitude,
            aa."position",
            aa.cog,
            aa.hdg,
            aa.event_time,
            aa.server_time,
            aa.msg_type,
            aa.routing_key,
            (aa.sog > 0.4) AS sog_group,
            (aa.sog > (180)::numeric) AS cog_group
           FROM ais.pos_reports aa
          WHERE ((aa.mmsi = ANY (ARRAY['205393490'::text, '205393690'::text, '205238890'::text])) AND ((aa.event_time >= (now() - '7 days'::interval)) AND (aa.event_time <= now())))
        ), clusters AS (
         SELECT ferry_data.sog_group,
            ferry_data.cog_group,
            ferry_data."position",
            public.st_clusterdbscan(ferry_data."position", eps => (0.0001)::double precision, minpoints => 10) OVER (PARTITION BY ferry_data.sog_group, ferry_data.cog_group) AS cid
           FROM ferry_data
        )
 SELECT clusters.cid,
    clusters.sog_group,
    clusters.cog_group,
    public.st_setsrid(public.st_concavehull(public.st_union(clusters."position"), (0.95)::double precision), 4326) AS convexhull
   FROM clusters
  WHERE (clusters.cid IS NOT NULL)
  GROUP BY clusters.cid, clusters.sog_group, clusters.cog_group;


ALTER TABLE ais.ferry_cluster OWNER TO vliz;

--
-- TOC entry 266 (class 1259 OID 17979)
-- Name: mid_to_country; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.mid_to_country (
    country text NOT NULL,
    country_abrv0 text,
    country_abrv1 text,
    country_abrv2 text,
    mid character varying(3) NOT NULL,
    flag_link text
);


ALTER TABLE ais.mid_to_country OWNER TO vliz;

--
-- TOC entry 311 (class 1259 OID 51994)
-- Name: latest_vessel_details; Type: MATERIALIZED VIEW; Schema: ais; Owner: vliz
--

CREATE MATERIALIZED VIEW ais.latest_vessel_details AS
 SELECT aa.mmsi,
    public.time_bucket_gapfill('1 day'::interval, aa.event_time, (now() - '1 day'::interval), now()) AS bucket,
    public.locf(max(aa.callsign)) AS callsign,
    public.locf(max(aa.destination)) AS destination,
    public.locf(max(aa.draught)) AS draught,
    public.locf(max(aa.eta)) AS eta,
    public.locf(max(aa.event_time)) AS latest_voy_report_timestamp,
    public.locf(max(aa.fix_type)) AS fix_type,
    public.locf(max(aa.imo)) AS imo,
    public.locf(max((aa.msg_type)::text)) AS msg_type,
    public.locf(max(aa.name)) AS name,
    public.locf(max(aa.routing_key)) AS routing_key,
    public.locf(max(aa.to_bow)) AS to_bow,
    public.locf(max(aa.to_stern)) AS to_stern,
    public.locf(max(aa.to_port)) AS to_port,
    public.locf(max(aa.to_starboard)) AS to_starboard,
    public.locf(max((aa.type_and_cargo)::text)) AS type_and_cargo,
    public.locf(max(bb.type)) AS text_type,
    public.locf(max(bb.sub_type)) AS text_sub_type,
    public.locf(max(cc.country)) AS mid_country
   FROM ((ais.voy_reports aa
     LEFT JOIN ais.ais_num_to_type bb ON (((aa.type_and_cargo)::text = (bb.ais_num)::text)))
     LEFT JOIN ais.mid_to_country cc ON (("left"(aa.mmsi, 3) = (cc.mid)::text)))
  WHERE ((aa.event_time >= (now() - '7 days'::interval)) AND (aa.event_time <= now()))
  GROUP BY (public.time_bucket_gapfill('1 day'::interval, aa.event_time, (now() - '1 day'::interval), now())), aa.mmsi
  WITH NO DATA;


ALTER TABLE ais.latest_vessel_details OWNER TO vliz;

--
-- TOC entry 353 (class 1259 OID 129945)
-- Name: latest_voy_reports; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.latest_voy_reports (
    mmsi text,
    imo text,
    callsign text,
    name text,
    type_and_cargo character varying(3),
    to_bow smallint,
    to_stern smallint,
    to_port smallint,
    to_starboard smallint,
    fix_type smallint,
    eta_month smallint,
    eta_day smallint,
    eta_hour smallint,
    eta_minute smallint,
    eta timestamp with time zone,
    draught numeric(4,1),
    destination text,
    event_time timestamp with time zone,
    server_time timestamp with time zone,
    msg_type character varying(3),
    routing_key text
);


ALTER TABLE ais.latest_voy_reports OWNER TO vliz;

--
-- TOC entry 265 (class 1259 OID 17973)
-- Name: nav_status; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.nav_status (
    nav_status text,
    description text
);


ALTER TABLE ais.nav_status OWNER TO vliz;

--
-- TOC entry 286 (class 1259 OID 24864)
-- Name: pos_reports_1h_cagg; Type: VIEW; Schema: ais; Owner: vliz
--

CREATE VIEW ais.pos_reports_1h_cagg AS
 SELECT _materialized_hypertable_4.mmsi,
    _materialized_hypertable_4.routing_key,
    _materialized_hypertable_4.bucket,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_4_4, NULL::character varying) AS navigation_status,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_5_5, NULL::smallint) AS rot,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_6_6, NULL::numeric) AS sog,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_7_7, NULL::double precision) AS longitude,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_8_8, NULL::double precision) AS latitude,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_9_9, NULL::public.geometry) AS "position",
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_10_10, NULL::numeric) AS cog,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_11_11, NULL::numeric) AS hdg,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_12_12, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_13_13, NULL::character varying) AS msg_type,
    _timescaledb_internal.finalize_agg('pg_catalog.avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_14_14, NULL::numeric) AS sog_avg,
    _timescaledb_internal.finalize_agg('pg_catalog.min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_15_15, NULL::numeric) AS sog_min,
    _timescaledb_internal.finalize_agg('pg_catalog.max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_16_16, NULL::numeric) AS sog_max,
    _timescaledb_internal.finalize_agg('pg_catalog.avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_17_17, NULL::numeric) AS cog_avg,
    _timescaledb_internal.finalize_agg('pg_catalog.min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_18_18, NULL::numeric) AS cog_min,
    _timescaledb_internal.finalize_agg('pg_catalog.max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_19_19, NULL::numeric) AS cog_max,
    _timescaledb_internal.finalize_agg('pg_catalog.avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_20_20, NULL::numeric) AS hdg_avg,
    _timescaledb_internal.finalize_agg('pg_catalog.min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_21_21, NULL::numeric) AS hdg_min,
    _timescaledb_internal.finalize_agg('pg_catalog.max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_22_22, NULL::numeric) AS hdg_max
   FROM _timescaledb_internal._materialized_hypertable_4
  WHERE (_materialized_hypertable_4.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(4)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_4.mmsi, _materialized_hypertable_4.routing_key, _materialized_hypertable_4.bucket
UNION ALL
 SELECT pos_reports.mmsi,
    pos_reports.routing_key,
    public.time_bucket('01:00:00'::interval, pos_reports.event_time) AS bucket,
    public.last(pos_reports.navigation_status, pos_reports.event_time) AS navigation_status,
    public.last(pos_reports.rot, pos_reports.event_time) AS rot,
    public.last(pos_reports.sog, pos_reports.event_time) AS sog,
    public.last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    public.last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    public.last(pos_reports."position", pos_reports.event_time) AS "position",
    public.last(pos_reports.cog, pos_reports.event_time) AS cog,
    public.last(pos_reports.hdg, pos_reports.event_time) AS hdg,
    public.last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    public.last(pos_reports.msg_type, pos_reports.event_time) AS msg_type,
    avg(pos_reports.sog) AS sog_avg,
    min(pos_reports.sog) AS sog_min,
    max(pos_reports.sog) AS sog_max,
    avg(pos_reports.cog) AS cog_avg,
    min(pos_reports.cog) AS cog_min,
    max(pos_reports.cog) AS cog_max,
    avg(pos_reports.hdg) AS hdg_avg,
    min(pos_reports.hdg) AS hdg_min,
    max(pos_reports.hdg) AS hdg_max
   FROM ais.pos_reports
  WHERE (pos_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(4)), '-infinity'::timestamp with time zone))
  GROUP BY pos_reports.mmsi, pos_reports.routing_key, (public.time_bucket('01:00:00'::interval, pos_reports.event_time));


ALTER TABLE ais.pos_reports_1h_cagg OWNER TO vliz;

--
-- TOC entry 300 (class 1259 OID 25460)
-- Name: oostend_traffic; Type: MATERIALIZED VIEW; Schema: ais; Owner: vliz
--

CREATE MATERIALIZED VIEW ais.oostend_traffic AS
 SELECT pos_reports_1h_cagg.mmsi,
    public.st_setsrid(public.st_makeline(pos_reports_1h_cagg."position" ORDER BY pos_reports_1h_cagg.bucket), 4326) AS geom,
    public.st_astext(public.st_setsrid(public.st_makeline(pos_reports_1h_cagg."position" ORDER BY pos_reports_1h_cagg.bucket), 4326)) AS st_astext
   FROM ais.pos_reports_1h_cagg
  WHERE ((pos_reports_1h_cagg.bucket >= (now() - '24:00:00'::interval)) AND (pos_reports_1h_cagg.bucket <= now()))
  GROUP BY pos_reports_1h_cagg.mmsi
  WITH NO DATA;


ALTER TABLE ais.oostend_traffic OWNER TO vliz;

--
-- TOC entry 351 (class 1259 OID 127370)
-- Name: trajectories; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.trajectories (
    mmsi text,
    time_grp bigint,
    dist_grp bigint,
    sog_grp bigint,
    first_time timestamp with time zone,
    last_time timestamp with time zone,
    geom_length double precision,
    geom public.geometry
);


ALTER TABLE ais.trajectories OWNER TO vliz;

--
-- TOC entry 7634 (class 0 OID 0)
-- Dependencies: 351
-- Name: TABLE trajectories; Type: COMMENT; Schema: ais; Owner: vliz
--

COMMENT ON TABLE ais.trajectories IS 'Trajectories for vessels. AIS points are grouped by MMSI but split by gaps in time (greater than 1 hour), jumps in distance, or gaps in distance (greater than 0.1 deg), or where calculated speed is too great (from duplicate MMSI''s). Calculated using stored procedure is ais.build_trajectories(integer, jsonb)';


--
-- TOC entry 536 (class 1259 OID 17550734)
-- Name: vessel_density_agg; Type: TABLE; Schema: ais; Owner: vliz
--

CREATE TABLE ais.vessel_density_agg (
    gid double precision,
    event_date date,
    type_and_cargo character varying,
    cardinal_seg numeric,
    sog_bin numeric,
    track_count bigint,
    avg_time_delta double precision,
    cum_time_in_grid double precision
);


ALTER TABLE ais.vessel_density_agg OWNER TO vliz;

--
-- TOC entry 312 (class 1259 OID 52038)
-- Name: vessel_details; Type: VIEW; Schema: ais; Owner: vliz
--

CREATE VIEW ais.vessel_details AS
 SELECT DISTINCT ON (aa.mmsi) aa.mmsi,
    aa.bucket,
    btrim(aa.callsign, '@'::text) AS callsign,
    btrim(aa.destination, '@'::text) AS destination,
    btrim(aa.imo, '@'::text) AS imo,
    btrim(aa.name, '@'::text) AS name,
    aa.draught,
    aa.eta,
    aa.latest_voy_report_timestamp,
    aa.fix_type,
    aa.msg_type,
    aa.routing_key,
    (aa.to_bow + aa.to_stern) AS length,
    (aa.to_port + aa.to_starboard) AS width,
    aa.type_and_cargo,
    aa.text_type,
    aa.text_sub_type,
    aa.mid_country
   FROM (ais.latest_vessel_details aa
     LEFT JOIN ais.aishub_primer_vessels bb ON ((aa.mmsi = bb.mmsi)))
  ORDER BY aa.mmsi, aa.bucket DESC;


ALTER TABLE ais.vessel_details OWNER TO vliz;

--
-- TOC entry 530 (class 1259 OID 16990976)
-- Name: vessel_trajectories; Type: VIEW; Schema: ais; Owner: vliz
--

CREATE VIEW ais.vessel_trajectories AS
 SELECT trajectories.mmsi,
    date(trajectories.first_time) AS date,
    trajectories.first_time,
    trajectories.last_time,
    trajectories.geom_length,
    (trajectories.geom)::public.geometry(LineString,4326) AS geom,
    latest_voy_reports.imo,
    latest_voy_reports.callsign,
    latest_voy_reports.name,
    latest_voy_reports.type_and_cargo,
    ais_num_to_type.type,
    ais_num_to_type.sub_type
   FROM ((ais.trajectories
     LEFT JOIN ais.latest_voy_reports ON ((latest_voy_reports.mmsi = trajectories.mmsi)))
     LEFT JOIN ais.ais_num_to_type ON (((latest_voy_reports.type_and_cargo)::text = (ais_num_to_type.ais_num)::text)))
  WHERE (trajectories.geom_length > (0)::double precision);


ALTER TABLE ais.vessel_trajectories OWNER TO vliz;

--
-- TOC entry 7638 (class 0 OID 0)
-- Dependencies: 530
-- Name: VIEW vessel_trajectories; Type: COMMENT; Schema: ais; Owner: vliz
--

COMMENT ON VIEW ais.vessel_trajectories IS 'Trajectories for vessels. AIS points are grouped by MMSI but split by gaps in time (greater than 1 hour), jumps in distance, or gaps in distance (greater than 0.1 deg), or where calculated speed is too great (from duplicate MMSI''s). Calculated using stored procedure is ais.build_trajectories(integer, jsonb)';


--
-- TOC entry 290 (class 1259 OID 24892)
-- Name: voy_reports_6h_cagg; Type: VIEW; Schema: ais; Owner: vliz
--

CREATE VIEW ais.voy_reports_6h_cagg AS
 SELECT _materialized_hypertable_5.mmsi,
    _materialized_hypertable_5.routing_key,
    _materialized_hypertable_5.bucket,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_4_4, NULL::text) AS imo,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_5_5, NULL::text) AS callsign,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_6_6, NULL::text) AS name,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_7_7, NULL::character varying) AS type_and_cargo,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_8_8, NULL::smallint) AS to_bow,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_9_9, NULL::smallint) AS to_stern,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_10_10, NULL::smallint) AS to_port,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_11_11, NULL::smallint) AS to_starboard,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_12_12, NULL::smallint) AS fix_type,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_13_13, NULL::timestamp with time zone) AS eta,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_14_14, NULL::numeric) AS draught,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_15_15, NULL::text) AS destination,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_16_16, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('public.last(pg_catalog.anyelement,pg_catalog."any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_17_17, NULL::character varying) AS msg_type
   FROM _timescaledb_internal._materialized_hypertable_5
  WHERE (_materialized_hypertable_5.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(5)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_5.mmsi, _materialized_hypertable_5.routing_key, _materialized_hypertable_5.bucket
UNION ALL
 SELECT voy_reports.mmsi,
    voy_reports.routing_key,
    public.time_bucket('06:00:00'::interval, voy_reports.event_time) AS bucket,
    public.last(voy_reports.imo, voy_reports.event_time) AS imo,
    public.last(voy_reports.callsign, voy_reports.event_time) AS callsign,
    public.last(voy_reports.name, voy_reports.event_time) AS name,
    public.last(voy_reports.type_and_cargo, voy_reports.event_time) AS type_and_cargo,
    public.last(voy_reports.to_bow, voy_reports.event_time) AS to_bow,
    public.last(voy_reports.to_stern, voy_reports.event_time) AS to_stern,
    public.last(voy_reports.to_port, voy_reports.event_time) AS to_port,
    public.last(voy_reports.to_starboard, voy_reports.event_time) AS to_starboard,
    public.last(voy_reports.fix_type, voy_reports.event_time) AS fix_type,
    public.last(voy_reports.eta, voy_reports.event_time) AS eta,
    public.last(voy_reports.draught, voy_reports.event_time) AS draught,
    public.last(voy_reports.destination, voy_reports.event_time) AS destination,
    public.last(voy_reports.event_time, voy_reports.event_time) AS event_time,
    public.last(voy_reports.msg_type, voy_reports.event_time) AS msg_type
   FROM ais.voy_reports
  WHERE (voy_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(5)), '-infinity'::timestamp with time zone))
  GROUP BY voy_reports.mmsi, voy_reports.routing_key, (public.time_bucket('06:00:00'::interval, voy_reports.event_time));


ALTER TABLE ais.voy_reports_6h_cagg OWNER TO vliz;

--
-- TOC entry 330 (class 1259 OID 67963)
-- Name: admin_0_countries; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.admin_0_countries (
    gid integer NOT NULL,
    featurecla character varying(15),
    scalerank smallint,
    labelrank smallint,
    sovereignt character varying(32),
    sov_a3 character varying(3),
    adm0_dif smallint,
    level smallint,
    type character varying(17),
    admin character varying(36),
    adm0_a3 character varying(3),
    geou_dif smallint,
    geounit character varying(36),
    gu_a3 character varying(3),
    su_dif smallint,
    subunit character varying(36),
    su_a3 character varying(3),
    brk_diff smallint,
    name character varying(29),
    name_long character varying(36),
    brk_a3 character varying(3),
    brk_name character varying(32),
    brk_group character varying(17),
    abbrev character varying(16),
    postal character varying(4),
    formal_en character varying(52),
    formal_fr character varying(35),
    name_ciawf character varying(45),
    note_adm0 character varying(22),
    note_brk character varying(63),
    name_sort character varying(36),
    name_alt character varying(19),
    mapcolor7 smallint,
    mapcolor8 smallint,
    mapcolor9 smallint,
    mapcolor13 smallint,
    pop_est double precision,
    pop_rank smallint,
    pop_year smallint,
    gdp_md integer,
    gdp_year smallint,
    economy character varying(26),
    income_grp character varying(23),
    fips_10 character varying(3),
    iso_a2 character varying(3),
    iso_a2_eh character varying(3),
    iso_a3 character varying(3),
    iso_a3_eh character varying(3),
    iso_n3 character varying(3),
    iso_n3_eh character varying(3),
    un_a3 character varying(4),
    wb_a2 character varying(3),
    wb_a3 character varying(3),
    woe_id integer,
    woe_id_eh integer,
    woe_note character varying(167),
    adm0_a3_is character varying(3),
    adm0_a3_us character varying(3),
    adm0_a3_fr character varying(3),
    adm0_a3_ru character varying(3),
    adm0_a3_es character varying(3),
    adm0_a3_cn character varying(3),
    adm0_a3_tw character varying(3),
    adm0_a3_in character varying(3),
    adm0_a3_np character varying(3),
    adm0_a3_pk character varying(3),
    adm0_a3_de character varying(3),
    adm0_a3_gb character varying(3),
    adm0_a3_br character varying(3),
    adm0_a3_il character varying(3),
    adm0_a3_ps character varying(3),
    adm0_a3_sa character varying(3),
    adm0_a3_eg character varying(3),
    adm0_a3_ma character varying(3),
    adm0_a3_pt character varying(3),
    adm0_a3_ar character varying(3),
    adm0_a3_jp character varying(3),
    adm0_a3_ko character varying(3),
    adm0_a3_vn character varying(3),
    adm0_a3_tr character varying(3),
    adm0_a3_id character varying(3),
    adm0_a3_pl character varying(3),
    adm0_a3_gr character varying(3),
    adm0_a3_it character varying(3),
    adm0_a3_nl character varying(3),
    adm0_a3_se character varying(3),
    adm0_a3_bd character varying(3),
    adm0_a3_ua character varying(3),
    adm0_a3_un smallint,
    adm0_a3_wb smallint,
    continent character varying(23),
    region_un character varying(10),
    subregion character varying(25),
    region_wb character varying(26),
    name_len smallint,
    long_len smallint,
    abbrev_len smallint,
    tiny smallint,
    homepart smallint,
    min_zoom double precision,
    min_label double precision,
    max_label double precision,
    ne_id double precision,
    wikidataid character varying(8),
    name_ar character varying(72),
    name_bn character varying(148),
    name_de character varying(46),
    name_en character varying(44),
    name_es character varying(44),
    name_fa character varying(66),
    name_fr character varying(54),
    name_el character varying(86),
    name_he character varying(78),
    name_hi character varying(126),
    name_hu character varying(52),
    name_id character varying(46),
    name_it character varying(48),
    name_ja character varying(63),
    name_ko character varying(47),
    name_nl character varying(49),
    name_pl character varying(47),
    name_pt character varying(43),
    name_ru character varying(86),
    name_sv character varying(57),
    name_tr character varying(42),
    name_uk character varying(91),
    name_ur character varying(67),
    name_vi character varying(56),
    name_zh character varying(33),
    name_zht character varying(33),
    fclass_iso character varying(12),
    fclass_us character varying(12),
    fclass_fr character varying(12),
    fclass_ru character varying(12),
    fclass_es character varying(12),
    fclass_cn character varying(12),
    fclass_tw character varying(12),
    fclass_in character varying(12),
    fclass_np character varying(12),
    fclass_pk character varying(12),
    fclass_de character varying(12),
    fclass_gb character varying(12),
    fclass_br character varying(12),
    fclass_il character varying(12),
    fclass_ps character varying(12),
    fclass_sa character varying(12),
    fclass_eg character varying(12),
    fclass_ma character varying(12),
    fclass_pt character varying(12),
    fclass_ar character varying(12),
    fclass_jp character varying(12),
    fclass_ko character varying(12),
    fclass_vn character varying(12),
    fclass_tr character varying(12),
    fclass_id character varying(12),
    fclass_pl character varying(12),
    fclass_gr character varying(12),
    fclass_it character varying(12),
    fclass_nl character varying(12),
    fclass_se character varying(12),
    fclass_bd character varying(12),
    fclass_ua character varying(12),
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.admin_0_countries OWNER TO vliz;

--
-- TOC entry 329 (class 1259 OID 67961)
-- Name: admin_0_countries_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.admin_0_countries_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.admin_0_countries_gid_seq OWNER TO vliz;

--
-- TOC entry 7642 (class 0 OID 0)
-- Dependencies: 329
-- Name: admin_0_countries_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.admin_0_countries_gid_seq OWNED BY geo.admin_0_countries.gid;


--
-- TOC entry 272 (class 1259 OID 18780)
-- Name: eez_12nm; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.eez_12nm (
    gid integer NOT NULL,
    mrgid integer,
    geoname character varying(254),
    pol_type character varying(254),
    mrgid_ter1 integer,
    territory1 character varying(254),
    mrgid_sov1 integer,
    sovereign1 character varying(254),
    iso_ter1 character varying(254),
    x_1 numeric,
    y_1 numeric,
    mrgid_eez integer,
    area_km2 integer,
    iso_sov1 character varying(254),
    un_sov1 numeric,
    un_ter1 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.eez_12nm OWNER TO vliz;

--
-- TOC entry 271 (class 1259 OID 18778)
-- Name: eez_12nm_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.eez_12nm_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.eez_12nm_gid_seq OWNER TO vliz;

--
-- TOC entry 7644 (class 0 OID 0)
-- Dependencies: 271
-- Name: eez_12nm_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.eez_12nm_gid_seq OWNED BY geo.eez_12nm.gid;


--
-- TOC entry 270 (class 1259 OID 18513)
-- Name: eez_24nm; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.eez_24nm (
    gid integer NOT NULL,
    mrgid integer,
    geoname character varying(254),
    pol_type character varying(254),
    mrgid_ter1 integer,
    territory1 character varying(254),
    mrgid_sov1 integer,
    sovereign1 character varying(254),
    iso_ter1 character varying(254),
    x_1 numeric,
    y_1 numeric,
    mrgid_eez integer,
    area_km2 integer,
    iso_sov1 character varying(254),
    un_sov1 numeric,
    un_ter1 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.eez_24nm OWNER TO vliz;

--
-- TOC entry 269 (class 1259 OID 18511)
-- Name: eez_24nm_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.eez_24nm_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.eez_24nm_gid_seq OWNER TO vliz;

--
-- TOC entry 7646 (class 0 OID 0)
-- Dependencies: 269
-- Name: eez_24nm_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.eez_24nm_gid_seq OWNED BY geo.eez_24nm.gid;


--
-- TOC entry 276 (class 1259 OID 19236)
-- Name: eez_archipelagic_waters; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.eez_archipelagic_waters (
    gid integer NOT NULL,
    mrgid integer,
    geoname character varying(254),
    pol_type character varying(254),
    mrgid_ter1 integer,
    territory1 character varying(254),
    mrgid_sov1 integer,
    sovereign1 character varying(254),
    iso_ter1 character varying(254),
    x_1 numeric,
    y_1 numeric,
    mrgid_eez integer,
    area_km2 integer,
    iso_sov1 character varying(254),
    un_sov1 numeric,
    un_ter1 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.eez_archipelagic_waters OWNER TO vliz;

--
-- TOC entry 275 (class 1259 OID 19234)
-- Name: eez_archipelagic_waters_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.eez_archipelagic_waters_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.eez_archipelagic_waters_gid_seq OWNER TO vliz;

--
-- TOC entry 7648 (class 0 OID 0)
-- Dependencies: 275
-- Name: eez_archipelagic_waters_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.eez_archipelagic_waters_gid_seq OWNED BY geo.eez_archipelagic_waters.gid;


--
-- TOC entry 274 (class 1259 OID 19051)
-- Name: eez_internal_waters; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.eez_internal_waters (
    gid integer NOT NULL,
    mrgid integer,
    geoname character varying(254),
    pol_type character varying(254),
    mrgid_ter1 integer,
    territory1 character varying(254),
    mrgid_sov1 integer,
    sovereign1 character varying(254),
    iso_ter1 character varying(254),
    x_1 numeric,
    y_1 numeric,
    mrgid_eez integer,
    area_km2 integer,
    iso_sov1 character varying(254),
    un_sov1 numeric,
    un_ter1 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.eez_internal_waters OWNER TO vliz;

--
-- TOC entry 273 (class 1259 OID 19049)
-- Name: eez_internal_waters_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.eez_internal_waters_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.eez_internal_waters_gid_seq OWNER TO vliz;

--
-- TOC entry 7650 (class 0 OID 0)
-- Dependencies: 273
-- Name: eez_internal_waters_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.eez_internal_waters_gid_seq OWNED BY geo.eez_internal_waters.gid;


--
-- TOC entry 352 (class 1259 OID 128437)
-- Name: fishing_clusters; Type: MATERIALIZED VIEW; Schema: geo; Owner: vliz
--

CREATE MATERIALIZED VIEW geo.fishing_clusters AS
 WITH clusters AS (
         SELECT aa.mmsi,
            public.st_clusterdbscan(aa."position", eps => (0.1)::double precision, minpoints => 50) OVER (PARTITION BY (date_part('month'::text, aa.bucket))) AS cluster_id,
            date_part('month'::text, aa.bucket) AS month,
            aa."position"
           FROM ais.pos_reports_1h_cagg aa
          WHERE (((aa.navigation_status)::text = '7'::text) AND (aa.bucket >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (aa.bucket <= '2022-01-15 00:00:00+00'::timestamp with time zone))
        )
 SELECT clusters.cluster_id,
    clusters.month,
    count(clusters."position") AS pos_count,
    count(DISTINCT clusters.mmsi) AS mmsi_count,
    public.st_convexhull(public.st_collect(clusters."position")) AS cluster_geom
   FROM clusters
  GROUP BY clusters.cluster_id, clusters.month
  WITH NO DATA;


ALTER TABLE geo.fishing_clusters OWNER TO vliz;

--
-- TOC entry 278 (class 1259 OID 19296)
-- Name: oceans_world; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.oceans_world (
    gid integer NOT NULL,
    ____gid numeric,
    name character varying(254),
    mrgid numeric,
    source character varying(254),
    area_km2 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.oceans_world OWNER TO vliz;

--
-- TOC entry 268 (class 1259 OID 17987)
-- Name: world_eez; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.world_eez (
    gid integer NOT NULL,
    mrgid integer,
    geoname character varying(254),
    mrgid_ter1 integer,
    pol_type character varying(254),
    mrgid_sov1 integer,
    territory1 character varying(254),
    iso_ter1 character varying(254),
    sovereign1 character varying(254),
    mrgid_ter2 integer,
    mrgid_sov2 integer,
    territory2 character varying(254),
    iso_ter2 character varying(254),
    sovereign2 character varying(254),
    mrgid_ter3 integer,
    mrgid_sov3 integer,
    territory3 character varying(254),
    iso_ter3 character varying(254),
    sovereign3 character varying(254),
    x_1 numeric,
    y_1 numeric,
    mrgid_eez integer,
    area_km2 integer,
    iso_sov1 character varying(254),
    iso_sov2 character varying(254),
    iso_sov3 character varying(254),
    un_sov1 numeric,
    un_sov2 numeric,
    un_sov3 numeric,
    un_ter1 numeric,
    un_ter2 numeric,
    un_ter3 numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE geo.world_eez OWNER TO vliz;

--
-- TOC entry 331 (class 1259 OID 72220)
-- Name: levels; Type: MATERIALIZED VIEW; Schema: geo; Owner: vliz
--

CREATE MATERIALIZED VIEW geo.levels AS
 WITH z0a AS (
         SELECT public.st_setsrid(public.st_simplify(oceans_world.geom, (0.001)::double precision), 4326) AS geom,
            oceans_world.name AS geoname,
            'ocean'::text AS pol_type,
            'ocean'::text AS territory,
            NULL::text AS iso_ter,
            0 AS level
           FROM geo.oceans_world
        ), z0b AS (
         SELECT public.st_setsrid(public.st_simplify(admin_0_countries.geom, (0.001)::double precision), 4326) AS geom,
            admin_0_countries.sovereignt AS geoname,
            admin_0_countries.type AS pol_type,
            admin_0_countries.brk_name AS territory,
            admin_0_countries.adm0_a3 AS iso_ter,
            0 AS level
           FROM geo.admin_0_countries
        ), z2a AS (
         SELECT public.st_setsrid(public.st_simplify(eez_12nm.geom, (0.001)::double precision), 4326) AS geom,
            eez_12nm.geoname,
            eez_12nm.pol_type,
            eez_12nm.territory1 AS territory,
            eez_12nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_12nm
        ), z2b AS (
         SELECT public.st_setsrid(public.st_simplify(eez_24nm.geom, (0.001)::double precision), 4326) AS geom,
            eez_24nm.geoname,
            eez_24nm.pol_type,
            eez_24nm.territory1 AS territory,
            eez_24nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_24nm
        ), z2c AS (
         SELECT public.st_setsrid(public.st_simplify(eez_archipelagic_waters.geom, (0.001)::double precision), 4326) AS geom,
            eez_archipelagic_waters.geoname,
            eez_archipelagic_waters.pol_type,
            eez_archipelagic_waters.territory1 AS territory,
            eez_archipelagic_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_archipelagic_waters
        ), z2d AS (
         SELECT public.st_setsrid(public.st_simplify(eez_internal_waters.geom, (0.001)::double precision), 4326) AS geom,
            eez_internal_waters.geoname,
            eez_internal_waters.pol_type,
            eez_internal_waters.territory1 AS territory,
            eez_internal_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_internal_waters
        ), z1a AS (
         SELECT public.st_setsrid(public.st_simplify(world_eez.geom, (0.001)::double precision), 4326) AS geom,
            world_eez.geoname,
            world_eez.pol_type,
            world_eez.territory1 AS territory,
            world_eez.iso_ter1 AS iso_ter,
            1 AS level
           FROM geo.world_eez
        )
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
  WITH NO DATA;


ALTER TABLE geo.levels OWNER TO vliz;

--
-- TOC entry 529 (class 1259 OID 16989963)
-- Name: maritime_boundaries; Type: MATERIALIZED VIEW; Schema: geo; Owner: vliz
--

CREATE MATERIALIZED VIEW geo.maritime_boundaries AS
 WITH z0a AS (
         SELECT public.st_setsrid(public.st_simplify(oceans_world.geom, (0.001)::double precision), 4326) AS geom,
            oceans_world.name AS geoname,
            'ocean'::text AS pol_type,
            'ocean'::text AS territory,
            NULL::text AS iso_ter,
            0 AS level
           FROM geo.oceans_world
        ), z0b AS (
         SELECT public.st_setsrid(public.st_simplify(admin_0_countries.geom, (0.001)::double precision), 4326) AS geom,
            admin_0_countries.sovereignt AS geoname,
            admin_0_countries.type AS pol_type,
            admin_0_countries.brk_name AS territory,
            admin_0_countries.adm0_a3 AS iso_ter,
            0 AS level
           FROM geo.admin_0_countries
        ), z2a AS (
         SELECT public.st_setsrid(public.st_simplify(eez_12nm.geom, (0.001)::double precision), 4326) AS geom,
            eez_12nm.geoname,
            eez_12nm.pol_type,
            eez_12nm.territory1 AS territory,
            eez_12nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_12nm
        ), z2b AS (
         SELECT public.st_setsrid(public.st_simplify(eez_24nm.geom, (0.001)::double precision), 4326) AS geom,
            eez_24nm.geoname,
            eez_24nm.pol_type,
            eez_24nm.territory1 AS territory,
            eez_24nm.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_24nm
        ), z2c AS (
         SELECT public.st_setsrid(public.st_simplify(eez_archipelagic_waters.geom, (0.001)::double precision), 4326) AS geom,
            eez_archipelagic_waters.geoname,
            eez_archipelagic_waters.pol_type,
            eez_archipelagic_waters.territory1 AS territory,
            eez_archipelagic_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_archipelagic_waters
        ), z2d AS (
         SELECT public.st_setsrid(public.st_simplify(eez_internal_waters.geom, (0.001)::double precision), 4326) AS geom,
            eez_internal_waters.geoname,
            eez_internal_waters.pol_type,
            eez_internal_waters.territory1 AS territory,
            eez_internal_waters.iso_ter1 AS iso_ter,
            2 AS level
           FROM geo.eez_internal_waters
        ), z1a AS (
         SELECT public.st_setsrid(public.st_simplify(world_eez.geom, (0.001)::double precision), 4326) AS geom,
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
    (public.st_setsrid(z_all.geom, 4326))::public.geometry(MultiPolygon,4326) AS geom,
    z_all.geoname,
    z_all.pol_type,
    z_all.territory,
    z_all.iso_ter,
    z_all.level
   FROM z_all
  WITH NO DATA;


ALTER TABLE geo.maritime_boundaries OWNER TO vliz;

--
-- TOC entry 7655 (class 0 OID 0)
-- Dependencies: 529
-- Name: MATERIALIZED VIEW maritime_boundaries; Type: COMMENT; Schema: geo; Owner: vliz
--

COMMENT ON MATERIALIZED VIEW geo.maritime_boundaries IS 'Maritime boundaries ordered by level, similar to administrative divisions on land. ';


--
-- TOC entry 535 (class 1259 OID 17550722)
-- Name: north_sea_hex_grid_1km2; Type: MATERIALIZED VIEW; Schema: geo; Owner: vliz
--

CREATE MATERIALIZED VIEW geo.north_sea_hex_grid_1km2 AS
 WITH belgi_waters AS (
         SELECT public.st_transform(public.st_makeenvelope((0.2)::double precision, (49.5)::double precision, (7)::double precision, (53.8)::double precision, 4326), 31370) AS geom
        )
 SELECT row_number() OVER () AS gid,
    public.st_transform(hex.geom, 4326) AS geom
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((620)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE geo.north_sea_hex_grid_1km2 OWNER TO vliz;

--
-- TOC entry 277 (class 1259 OID 19294)
-- Name: oceans_world_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.oceans_world_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.oceans_world_gid_seq OWNER TO vliz;

--
-- TOC entry 7658 (class 0 OID 0)
-- Dependencies: 277
-- Name: oceans_world_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.oceans_world_gid_seq OWNED BY geo.oceans_world.gid;


--
-- TOC entry 282 (class 1259 OID 19324)
-- Name: sampaz; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.sampaz (
    gid integer NOT NULL,
    wdpaid character varying(50),
    cur_nme character varying(250),
    cur_zon_nm character varying(150),
    cur_zon_ty character varying(150),
    cur_zon_cd character varying(50),
    wmcm_type character varying(50),
    maj_type character varying(50),
    site_type character varying(150),
    d_dclar date,
    legal_stat character varying(50),
    gis_area numeric,
    geom public.geometry(MultiPolygonZM)
);


ALTER TABLE geo.sampaz OWNER TO vliz;

--
-- TOC entry 281 (class 1259 OID 19322)
-- Name: sampaz_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.sampaz_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.sampaz_gid_seq OWNER TO vliz;

--
-- TOC entry 7660 (class 0 OID 0)
-- Dependencies: 281
-- Name: sampaz_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.sampaz_gid_seq OWNED BY geo.sampaz.gid;


--
-- TOC entry 267 (class 1259 OID 17985)
-- Name: world_eez_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.world_eez_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.world_eez_gid_seq OWNER TO vliz;

--
-- TOC entry 7661 (class 0 OID 0)
-- Dependencies: 267
-- Name: world_eez_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.world_eez_gid_seq OWNED BY geo.world_eez.gid;


--
-- TOC entry 280 (class 1259 OID 19310)
-- Name: world_port_index; Type: TABLE; Schema: geo; Owner: vliz
--

CREATE TABLE geo.world_port_index (
    gid integer NOT NULL,
    index_no double precision,
    region_no double precision,
    port_name character varying(254),
    country character varying(254),
    latitude double precision,
    longitude double precision,
    lat_deg double precision,
    lat_min double precision,
    lat_hemi character varying(254),
    long_deg double precision,
    long_min double precision,
    long_hemi character varying(254),
    pub character varying(254),
    chart character varying(254),
    harborsize character varying(254),
    harbortype character varying(254),
    shelter character varying(254),
    entry_tide character varying(254),
    entryswell character varying(254),
    entry_ice character varying(254),
    entryother character varying(254),
    overhd_lim character varying(254),
    chan_depth character varying(254),
    anch_depth character varying(254),
    cargodepth character varying(254),
    oil_depth character varying(254),
    tide_range double precision,
    max_vessel character varying(254),
    holdground character varying(254),
    turn_basin character varying(254),
    portofentr character varying(254),
    us_rep character varying(254),
    etamessage character varying(254),
    pilot_reqd character varying(254),
    pilotavail character varying(254),
    loc_assist double precision,
    pilotadvsd character varying(254),
    tugsalvage character varying(254),
    tug_assist character varying(254),
    pratique character varying(254),
    sscc_cert double precision,
    quar_other character varying(254),
    comm_phone character varying(254),
    comm_fax character varying(254),
    comm_radio character varying(254),
    comm_vhf character varying(254),
    comm_air character varying(254),
    comm_rail character varying(254),
    cargowharf character varying(254),
    cargo_anch character varying(254),
    cargmdmoor double precision,
    carbchmoor double precision,
    caricemoor double precision,
    med_facil character varying(254),
    garbage character varying(254),
    degauss double precision,
    drtyballst character varying(254),
    cranefixed character varying(254),
    cranemobil character varying(254),
    cranefloat character varying(254),
    lift_100_ double precision,
    lift50_100 character varying(254),
    lift_25_49 double precision,
    lift_0_24 double precision,
    longshore character varying(254),
    electrical character varying(254),
    serv_steam double precision,
    nav_equip double precision,
    elecrepair double precision,
    provisions character varying(254),
    water character varying(254),
    fuel_oil character varying(254),
    diesel character varying(254),
    decksupply character varying(254),
    eng_supply character varying(254),
    repaircode character varying(254),
    drydock character varying(254),
    railway character varying(254),
    geom public.geometry(Point,4326)
);


ALTER TABLE geo.world_port_index OWNER TO vliz;

--
-- TOC entry 7662 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE world_port_index; Type: COMMENT; Schema: geo; Owner: vliz
--

COMMENT ON TABLE geo.world_port_index IS '2019 WPI version downloaded from https://msi.nga.mil/api/publications/download?key=16694622/SFH00000/WPI_Shapefile.zip&type=view';


--
-- TOC entry 279 (class 1259 OID 19308)
-- Name: world_port_index_gid_seq; Type: SEQUENCE; Schema: geo; Owner: vliz
--

CREATE SEQUENCE geo.world_port_index_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geo.world_port_index_gid_seq OWNER TO vliz;

--
-- TOC entry 7664 (class 0 OID 0)
-- Dependencies: 279
-- Name: world_port_index_gid_seq; Type: SEQUENCE OWNED BY; Schema: geo; Owner: vliz
--

ALTER SEQUENCE geo.world_port_index_gid_seq OWNED BY geo.world_port_index.gid;


--
-- TOC entry 544 (class 1259 OID 18795649)
-- Name: vessel_density; Type: MATERIALIZED VIEW; Schema: geoserver; Owner: vliz
--

CREATE MATERIALIZED VIEW geoserver.vessel_density AS
 WITH griddata AS (
         SELECT vessel_density_agg.gid,
            to_char(date_trunc('year'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'YYYY'::text) AS year,
            to_char(date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'Mon'::text) AS month,
            date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone) AS agg_datetime,
            COALESCE(ais_num_to_type.type, 'Unknown'::text) AS type,
            ((sum(vessel_density_agg.cum_time_in_grid) / (60)::double precision) / (60)::double precision) AS hour_in_cell,
            sum(vessel_density_agg.track_count) AS track_count_in_cell
           FROM (ais.vessel_density_agg
             LEFT JOIN ais.ais_num_to_type ON (((vessel_density_agg.type_and_cargo)::text = (ais_num_to_type.ais_num)::text)))
          GROUP BY vessel_density_agg.gid, (to_char(date_trunc('year'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'YYYY'::text)), (to_char(date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'Mon'::text)), ais_num_to_type.type, (date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone))
        UNION ALL
         SELECT vessel_density_agg.gid,
            to_char(date_trunc('year'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'YYYY'::text) AS year,
            to_char(date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'Mon'::text) AS month,
            date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone) AS agg_datetime,
            'All'::text AS type,
            ((sum(vessel_density_agg.cum_time_in_grid) / (60)::double precision) / (60)::double precision) AS hour_in_cell,
            sum(vessel_density_agg.track_count) AS track_count_in_cell
           FROM ais.vessel_density_agg
          GROUP BY vessel_density_agg.gid, (to_char(date_trunc('year'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'YYYY'::text)), (to_char(date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone), 'Mon'::text)), (date_trunc('month'::text, (vessel_density_agg.event_date)::timestamp with time zone))
        ), avg_month AS (
         SELECT griddata.gid,
            griddata.year,
            griddata.month,
            griddata.agg_datetime,
            griddata.type,
            griddata.hour_in_cell,
            griddata.track_count_in_cell
           FROM griddata
        UNION ALL
         SELECT griddata.gid,
            griddata.year,
            'Average'::text AS month,
            date_trunc('year'::text, griddata.agg_datetime) AS agg_datetime,
            griddata.type,
            avg(griddata.hour_in_cell) AS avg,
            avg(griddata.track_count_in_cell) AS avg
           FROM griddata
          GROUP BY griddata.gid, griddata.year, (date_trunc('year'::text, griddata.agg_datetime)), griddata.type
        )
 SELECT avg_month.gid,
    avg_month.year,
    avg_month.month,
    avg_month.agg_datetime,
    avg_month.type,
    avg_month.hour_in_cell,
    avg_month.track_count_in_cell,
    public.st_setsrid(grid.geom, 4326) AS geom
   FROM (avg_month
     JOIN geo.north_sea_hex_grid_1km2 grid ON (((grid.gid)::double precision = avg_month.gid)))
  WITH NO DATA;


ALTER TABLE geoserver.vessel_density OWNER TO vliz;

--
-- TOC entry 509 (class 1259 OID 14135224)
-- Name: labelled_vessels; Type: MATERIALIZED VIEW; Schema: public; Owner: read_user
--

CREATE MATERIALIZED VIEW public.labelled_vessels AS
 SELECT _voyages.mmsi,
    _voyages.type_and_cargo,
    _positions.navigation_status,
    _positions.longitude,
    _positions.latitude,
    _positions.rot,
    _positions.sog,
    _positions.cog
   FROM (ais.voy_reports _voyages
     JOIN ais.pos_reports _positions ON (((_voyages.mmsi = _positions.mmsi) AND (_voyages.type_and_cargo IS NOT NULL) AND (length(_voyages.mmsi) > 7) AND (_voyages.mmsi <> '123456789'::text) AND (_voyages.mmsi <> '111111111'::text))))
  WHERE (((_positions.event_time >= '2022-08-01 00:00:00+00'::timestamp with time zone) AND (_positions.event_time <= '2022-08-02 00:00:00+00'::timestamp with time zone)) AND ((_voyages.event_time >= '2022-08-01 00:00:00+00'::timestamp with time zone) AND (_voyages.event_time <= '2022-08-02 00:00:00+00'::timestamp with time zone)))
  WITH NO DATA;


ALTER TABLE public.labelled_vessels OWNER TO read_user;

--
-- TOC entry 510 (class 1259 OID 14135245)
-- Name: latest_labelled_vessels; Type: MATERIALIZED VIEW; Schema: public; Owner: read_user
--

CREATE MATERIALIZED VIEW public.latest_labelled_vessels AS
 SELECT _voyages.mmsi,
    _voyages.type_and_cargo,
    _positions.navigation_status,
    _positions.longitude,
    _positions.latitude,
    _positions.rot,
    _positions.sog,
    _positions.cog
   FROM (ais.latest_voy_reports _voyages
     JOIN ais.pos_reports _positions ON (((_voyages.mmsi = _positions.mmsi) AND (_voyages.type_and_cargo IS NOT NULL) AND (length(_voyages.mmsi) > 7) AND (_voyages.mmsi <> '123456789'::text) AND (_voyages.mmsi <> '111111111'::text))))
  WHERE (((_positions.event_time >= '2022-08-01 00:00:00+00'::timestamp with time zone) AND (_positions.event_time <= '2022-08-02 00:00:00+00'::timestamp with time zone)) AND ((_voyages.event_time >= '2022-08-01 00:00:00+00'::timestamp with time zone) AND (_voyages.event_time <= '2022-08-02 00:00:00+00'::timestamp with time zone)))
  WITH NO DATA;


ALTER TABLE public.latest_labelled_vessels OWNER TO read_user;

--
-- TOC entry 501 (class 1259 OID 13576612)
-- Name: valid_trajectories; Type: MATERIALIZED VIEW; Schema: public; Owner: read_user
--

CREATE MATERIALIZED VIEW public.valid_trajectories AS
 SELECT _trajectories.mmsi,
    _voyages.type_and_cargo,
    _trajectories.geom_length,
    _trajectories.geom,
    public.st_astext(_trajectories.geom) AS st_astext,
    _trajectories.first_time,
    _trajectories.last_time,
    _voyages.event_time
   FROM (ais.trajectories _trajectories
     JOIN ais.latest_voy_reports _voyages ON (((_trajectories.mmsi = _voyages.mmsi) AND (_voyages.type_and_cargo IS NOT NULL) AND (length(_voyages.mmsi) > 7) AND (_voyages.mmsi <> '123456789'::text))))
  WHERE ((_trajectories.geom_length > (0)::double precision) AND ((_trajectories.first_time >= '2022-08-01 00:00:00+00'::timestamp with time zone) AND (_trajectories.first_time <= '2022-08-31 00:00:00+00'::timestamp with time zone)))
  WITH NO DATA;


ALTER TABLE public.valid_trajectories OWNER TO read_user;

--
-- TOC entry 356 (class 1259 OID 133292)
-- Name: aoi_hex_grid_1km2; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.aoi_hex_grid_1km2 AS
 WITH belgi_waters AS (
         SELECT public.st_transform(public.st_makeenvelope((0.2)::double precision, (49.5)::double precision, (7)::double precision, (53.8)::double precision, 4326), 31370) AS geom
        )
 SELECT row_number() OVER () AS gid,
    public.st_transform(hex.geom, 4326) AS geom
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((620)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE rory.aoi_hex_grid_1km2 OWNER TO vliz;

--
-- TOC entry 364 (class 1259 OID 142176)
-- Name: agg_test_2; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.agg_test_2 AS
 WITH segments AS (
         SELECT ais.mmsi,
            date(ais.event_time) AS event_date,
            voy.type_and_cargo,
            public.st_makeline(ais."position", lead(ais."position") OVER time_order) AS segment,
            ais."position" AS pos,
            lead(ais."position") OVER time_order AS pos2,
                CASE
                    WHEN (ais.sog < (50)::numeric) THEN ais.sog
                    WHEN (ais.sog > (50)::numeric) THEN NULL::numeric
                    ELSE NULL::numeric
                END AS sog,
            NULLIF(ais.cog, 360.0) AS cog,
            NULLIF(ais.hdg, 511.0) AS hdg,
            COALESCE(ais.navigation_status, '15'::character varying) AS nav,
            ais.rot,
            date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) AS time_delta,
            NULLIF((voy.to_bow + voy.to_stern), 0) AS l,
            NULLIF((voy.to_port + voy.to_starboard), 0) AS w
           FROM (ais.pos_reports ais
             JOIN ais.latest_voy_reports voy ON ((ais.mmsi = voy.mmsi)))
          WHERE ((ais.event_time >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (ais.event_time <= '2022-01-02 00:00:00+00'::timestamp with time zone))
          WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)
        )
 SELECT segments.event_date,
    segments.type_and_cargo,
    segments.nav,
    grid.geom,
    public.st_astext(grid.geom) AS st_astext,
    sum(((public.st_length(public.st_intersection(segments.segment, grid.geom)) * segments.time_delta) / public.st_length(segments.segment))) AS secs_in_cell,
    avg(segments.cog) AS cog_avg,
    stddev(segments.cog) AS cog_stddev,
    avg(segments.sog) AS sog_avg,
    stddev(segments.sog) AS sog_stddev,
    avg(segments.hdg) AS hdg_avg,
    stddev(segments.hdg) AS hdg_stddev,
    avg(segments.rot) AS rot_avg,
    stddev(segments.rot) AS rot_stddev,
    avg(segments.time_delta) AS time_delta_avg,
    stddev(segments.time_delta) AS time_delta_stddev,
    avg(segments.w) AS w_avg,
    stddev(segments.w) AS w_stddev,
    avg(segments.l) AS l_avg,
    stddev(segments.l) AS l_stddev
   FROM (segments
     JOIN rory.aoi_hex_grid_1km2 grid ON (public.st_within(segments.segment, grid.geom)))
  WHERE ((segments.time_delta > (0)::double precision) AND (segments.time_delta < (600)::double precision) AND (public.st_length(segments.segment) > (0)::double precision) AND (public.st_length(segments.segment) < (1)::double precision))
  GROUP BY segments.event_date, segments.type_and_cargo, grid.geom, segments.nav
  WITH NO DATA;


ALTER TABLE rory.agg_test_2 OWNER TO vliz;

--
-- TOC entry 365 (class 1259 OID 142196)
-- Name: agg_test_3; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.agg_test_3 AS
 WITH segments AS (
         SELECT ais.mmsi,
            date(ais.event_time) AS event_date,
            voy.type_and_cargo,
            public.st_makeline(ais."position", lead(ais."position") OVER time_order) AS segment,
            ais."position" AS pos,
            lead(ais."position") OVER time_order AS pos2,
                CASE
                    WHEN (ais.sog < (50)::numeric) THEN ais.sog
                    WHEN (ais.sog > (50)::numeric) THEN NULL::numeric
                    ELSE NULL::numeric
                END AS sog,
            NULLIF(ais.cog, 360.0) AS cog,
            ((ais.sog)::double precision * sin(radians((ais.cog)::double precision))) AS cog_y,
            ((ais.sog)::double precision * cos(radians((ais.cog)::double precision))) AS cog_x,
            NULLIF(ais.hdg, 511.0) AS hdg,
            COALESCE(ais.navigation_status, '15'::character varying) AS nav,
            ais.rot,
            (date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) / (3600)::double precision) AS time_delta,
            NULLIF((voy.to_bow + voy.to_stern), 0) AS l,
            NULLIF((voy.to_port + voy.to_starboard), 0) AS w
           FROM (ais.pos_reports ais
             JOIN ais.latest_voy_reports voy ON ((ais.mmsi = voy.mmsi)))
          WHERE ((ais.event_time >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (ais.event_time <= '2022-01-02 00:00:00+00'::timestamp with time zone))
          WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)
        )
 SELECT segments.mmsi,
    segments.event_date,
    segments.type_and_cargo,
    segments.segment,
    segments.pos,
    segments.pos2,
    segments.sog,
    segments.cog,
    segments.cog_y,
    segments.cog_x,
    segments.hdg,
    segments.nav,
    segments.rot,
    segments.time_delta,
    segments.l,
    segments.w
   FROM segments
  WHERE ((segments.time_delta > (0)::double precision) AND (segments.time_delta < (600)::double precision) AND (public.st_length(segments.segment) > (0)::double precision) AND (public.st_length(segments.segment) < (1)::double precision))
 LIMIT 10000
  WITH NO DATA;


ALTER TABLE rory.agg_test_3 OWNER TO vliz;

--
-- TOC entry 376 (class 1259 OID 175850)
-- Name: agg_test_4; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.agg_test_4 AS
 SELECT
        CASE
            WHEN ((ais.msg_type)::text = ANY ((ARRAY['1'::character varying, '2'::character varying, '3'::character varying])::text[])) THEN 'A'::character varying
            WHEN ((ais.msg_type)::text = ANY ((ARRAY['18'::character varying, '19'::character varying])::text[])) THEN 'B'::character varying
            ELSE ais.msg_type
        END AS ais_class,
    ais.routing_key,
    ais.event_time,
    ais.navigation_status,
    ais."position",
    ais.mmsi,
    ais.cog,
    ais.sog,
    ais.hdg,
    ((NULLIF(ais.sog, 102.3))::double precision * sin(radians((NULLIF(ais.cog, 360.0))::double precision))) AS cog_x,
    ((NULLIF(ais.sog, 102.3))::double precision * cos(radians((NULLIF(ais.cog, 360.0))::double precision))) AS cog_y,
    ((NULLIF(ais.sog, 102.3))::double precision * sin(radians((NULLIF(ais.hdg, 511.0))::double precision))) AS hdg_x,
    ((NULLIF(ais.sog, 102.3))::double precision * cos(radians((NULLIF(ais.hdg, 511.0))::double precision))) AS hdg_y
   FROM ais.pos_reports_1h_cagg ais
  WHERE ((ais.mmsi = '232024430'::text) AND ((ais.bucket >= '2021-09-24 00:00:00+00'::timestamp with time zone) AND (ais.bucket <= '2021-09-27 00:00:00+00'::timestamp with time zone)))
 LIMIT 10000
  WITH NO DATA;


ALTER TABLE rory.agg_test_4 OWNER TO vliz;

--
-- TOC entry 405 (class 1259 OID 5913576)
-- Name: ais_agg_ver2; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.ais_agg_ver2 (
    gid double precision,
    event_date date,
    type_and_cargo character varying,
    cardinal_seg numeric,
    sog_bin numeric,
    track_count bigint,
    avg_time_delta double precision,
    cum_time_in_grid double precision
);


ALTER TABLE rory.ais_agg_ver2 OWNER TO vliz;

--
-- TOC entry 416 (class 1259 OID 6522350)
-- Name: anchorage; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.anchorage AS
 WITH anchorages AS (
         SELECT pos_reports_1h_cagg."position" AS geom,
            public.st_clusterdbscan(pos_reports_1h_cagg."position", eps => (0.1)::double precision, minpoints => 20) OVER () AS cid
           FROM ais.pos_reports_1h_cagg
          WHERE (((pos_reports_1h_cagg.navigation_status)::text = '1'::text) AND ((pos_reports_1h_cagg.bucket >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (pos_reports_1h_cagg.bucket <= '2022-01-07 00:00:00+00'::timestamp with time zone)))
        )
 SELECT anchorages.cid,
    public.st_astext(public.st_makevalid(public.st_concavehull(public.st_collect(anchorages.geom), (0.8)::double precision))) AS cluster_wkt,
    public.st_makevalid(public.st_concavehull(public.st_collect(anchorages.geom), (0.8)::double precision)) AS geom,
    public.st_makevalid(public.st_convexhull(public.st_collect(anchorages.geom))) AS geom2
   FROM anchorages
  WHERE (anchorages.cid IS NOT NULL)
  GROUP BY anchorages.cid
  WITH NO DATA;


ALTER TABLE rory.anchorage OWNER TO vliz;

--
-- TOC entry 341 (class 1259 OID 123898)
-- Name: aoi_hex_grid_100m2; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.aoi_hex_grid_100m2 AS
 WITH belgi_waters AS (
         SELECT public.st_transform(public.st_makeenvelope((0.2)::double precision, (49.5)::double precision, (7)::double precision, (53.8)::double precision, 4326), 31370) AS geom
        )
 SELECT row_number() OVER () AS gid,
    public.st_transform(hex.geom, 4326) AS geom,
    public.st_astext(public.st_transform(hex.geom, 4326)) AS wkt
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((196)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE rory.aoi_hex_grid_100m2 OWNER TO vliz;

--
-- TOC entry 333 (class 1259 OID 74239)
-- Name: belgium_eez_bounding_box; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.belgium_eez_bounding_box AS
 SELECT world_eez.gid,
    public.st_setsrid((public.st_extent(public.st_buffer(world_eez.geom, (0.1)::double precision)))::public.geometry, 4326) AS geom,
    public.st_astext(public.st_setsrid((public.st_extent(public.st_buffer(world_eez.geom, (0.1)::double precision)))::public.geometry, 4326)) AS wkt
   FROM geo.world_eez
  WHERE ((world_eez.geoname)::text ~~ '%Belgian%'::text)
  GROUP BY world_eez.gid
  WITH NO DATA;


ALTER TABLE rory.belgium_eez_bounding_box OWNER TO vliz;

--
-- TOC entry 332 (class 1259 OID 73307)
-- Name: belgium_hex_grid_001deg; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.belgium_hex_grid_001deg AS
 WITH belgi_waters AS (
         SELECT public.st_makeenvelope((0.2)::double precision, (49.5)::double precision, (7)::double precision, (53.8)::double precision, 4326) AS geom
        )
 SELECT public.st_setsrid(hex.geom, 4326) AS geom
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((0.01)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE rory.belgium_hex_grid_001deg OWNER TO vliz;

--
-- TOC entry 346 (class 1259 OID 126554)
-- Name: belgium_hex_grid_100m2; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.belgium_hex_grid_100m2 AS
 WITH belgi_waters AS (
         SELECT world_eez.gid,
            public.st_transform(public.st_setsrid(world_eez.geom, 4326), 31370) AS geom
           FROM geo.world_eez
          WHERE ((world_eez.geoname)::text ~~ '%Belgian%'::text)
        )
 SELECT belgi_waters.gid,
    public.st_transform(hex.geom, 4326) AS geom
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((200)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE rory.belgium_hex_grid_100m2 OWNER TO vliz;

--
-- TOC entry 313 (class 1259 OID 52070)
-- Name: belgium_hex_grid_1km2; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.belgium_hex_grid_1km2 AS
 WITH belgi_waters AS (
         SELECT world_eez.gid,
            public.st_transform(public.st_setsrid(world_eez.geom, 4326), 31370) AS geom
           FROM geo.world_eez
          WHERE ((world_eez.geoname)::text ~~ '%Belgian%'::text)
        )
 SELECT belgi_waters.gid,
    public.st_transform(hex.geom, 4326) AS geom
   FROM (belgi_waters
     CROSS JOIN LATERAL public.st_hexagongrid((620)::double precision, belgi_waters.geom) hex(geom, i, j))
  WHERE public.st_intersects(belgi_waters.geom, hex.geom)
  WITH NO DATA;


ALTER TABLE rory.belgium_hex_grid_1km2 OWNER TO vliz;

--
-- TOC entry 419 (class 1259 OID 6817165)
-- Name: mt_pos; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.mt_pos (
    mmsi text,
    imo text,
    ship_id text,
    lat text,
    lon text,
    heading text,
    course text,
    status text,
    sog text,
    "timestamp" text
);


ALTER TABLE rory.mt_pos OWNER TO vliz;

--
-- TOC entry 420 (class 1259 OID 6817190)
-- Name: clea; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.clea AS
 SELECT mt_pos.mmsi,
    mt_pos.status AS navigation_status,
    NULL::text AS rot,
    ((mt_pos.sog)::double precision / (10)::double precision) AS sog,
    (mt_pos.lon)::double precision AS longitude,
    (mt_pos.lat)::double precision AS latitude,
    public.st_setsrid(public.st_point((mt_pos.lon)::double precision, (mt_pos.lat)::double precision), 4326) AS "position",
    (NULLIF(mt_pos.course, 'NULL'::text))::double precision AS cog,
    (NULLIF(mt_pos.heading, 'NULL'::text))::double precision AS hdg,
    to_timestamp(mt_pos."timestamp", 'YYYY-MM-DD HH24:MI:SS'::text) AS event_time,
    NULL::text AS msg_type,
    'ais.mt.sample'::text AS routing_key
   FROM rory.mt_pos
 LIMIT 10000
  WITH NO DATA;


ALTER TABLE rory.clea OWNER TO vliz;

--
-- TOC entry 363 (class 1259 OID 141470)
-- Name: complex_ais_agg; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.complex_ais_agg (
    id double precision,
    event_date date,
    geom public.geometry,
    type_and_cargo character varying,
    cardinal_seg numeric,
    track_count bigint,
    avg_y_disturbance double precision,
    var_y_disturbance double precision,
    avg_x_disturbance double precision,
    var_x_disturbance double precision,
    avg_cog numeric,
    avg_hdg numeric,
    avg_sog numeric,
    max_sog numeric,
    avg_time_delta double precision,
    cum_time_in_grid double precision
);


ALTER TABLE rory.complex_ais_agg OWNER TO vliz;

--
-- TOC entry 336 (class 1259 OID 79058)
-- Name: daily_vessel_trajectory_w_breaks; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.daily_vessel_trajectory_w_breaks AS
 WITH lead_lag AS (
         SELECT ais.mmsi,
            ais."position",
            ais.event_time,
            ais.sog,
            (lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time) <= (ais.event_time - '01:00:00'::interval)) AS time_step,
            ((public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) < (0)::double precision) OR (public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) > (0.1)::double precision)) AS dist_step,
            ((public.st_distancesphere(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) / NULLIF(date_part('epoch'::text, (ais.event_time - lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time))), (0)::double precision)) >= (((2)::numeric * (ais.sog + 0.1)))::double precision) AS sog_step,
            public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) AS dist
           FROM ais.pos_reports ais,
            rory.belgium_eez_bounding_box
          WHERE ((ais.event_time >= '2021-10-01 00:00:00+00'::timestamp with time zone) AND (ais.event_time <= '2021-10-02 00:00:00+00'::timestamp with time zone) AND public.st_within(ais."position", belgium_eez_bounding_box.geom))
        ), lead_lag_groups AS (
         SELECT lead_lag_1.mmsi,
            lead_lag_1."position",
            lead_lag_1.event_time,
            lead_lag_1.sog,
            lead_lag_1.time_step,
            lead_lag_1.dist_step,
            lead_lag_1.dist,
            lead_lag_1.sog_step,
            count(*) FILTER (WHERE lead_lag_1.time_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS time_grp,
            count(*) FILTER (WHERE lead_lag_1.dist_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS dist_grp,
            count(*) FILTER (WHERE lead_lag_1.sog_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS sog_grp
           FROM lead_lag lead_lag_1
          WHERE (lead_lag_1.dist > (0)::double precision)
        )
 SELECT lead_lag.mmsi,
    lead_lag.time_grp,
    lead_lag.dist_grp,
    lead_lag.sog_grp,
    public.first(lead_lag.event_time, lead_lag.event_time) AS first_time,
    public.last(lead_lag.event_time, lead_lag.event_time) AS last_time,
    public.st_length(public.st_setsrid(public.st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS geom_length,
    public.st_setsrid(public.st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326) AS geom,
    public.st_astext(public.st_setsrid(public.st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS st_astext
   FROM lead_lag_groups lead_lag
  GROUP BY lead_lag.mmsi, lead_lag.time_grp, lead_lag.dist_grp, lead_lag.sog_grp
  WITH NO DATA;


ALTER TABLE rory.daily_vessel_trajectory_w_breaks OWNER TO vliz;

--
-- TOC entry 525 (class 1259 OID 16424568)
-- Name: geoserver_test; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.geoserver_test AS
 WITH griddata AS (
         SELECT ais_agg_ver2.gid,
            sum(ais_agg_ver2.cum_time_in_grid) AS time_in_cell,
            sum(ais_agg_ver2.track_count) AS number_of_tracks
           FROM rory.ais_agg_ver2
          GROUP BY ais_agg_ver2.gid
        )
 SELECT griddata.gid,
    griddata.time_in_cell,
    griddata.number_of_tracks,
    public.st_setsrid(grid.geom, 3857) AS geom
   FROM (griddata
     JOIN rory.aoi_hex_grid_1km2 grid ON (((grid.gid)::double precision = griddata.gid)))
  WITH NO DATA;


ALTER TABLE rory.geoserver_test OWNER TO vliz;

--
-- TOC entry 534 (class 1259 OID 17550106)
-- Name: geoserver_test_timeseries; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.geoserver_test_timeseries AS
 WITH griddata AS (
         SELECT ais_agg_ver2.gid,
            date_trunc('month'::text, (ais_agg_ver2.event_date)::timestamp with time zone) AS month,
            sum(ais_agg_ver2.cum_time_in_grid) AS time_in_cell,
            sum(ais_agg_ver2.track_count) AS number_of_tracks
           FROM rory.ais_agg_ver2
          GROUP BY ais_agg_ver2.gid, (date_trunc('month'::text, (ais_agg_ver2.event_date)::timestamp with time zone))
        )
 SELECT griddata.gid,
    griddata.month,
    griddata.time_in_cell,
    griddata.number_of_tracks,
    public.st_setsrid(grid.geom, 3857) AS geom
   FROM (griddata
     JOIN rory.aoi_hex_grid_1km2 grid ON (((grid.gid)::double precision = griddata.gid)))
  WITH NO DATA;


ALTER TABLE rory.geoserver_test_timeseries OWNER TO vliz;

--
-- TOC entry 418 (class 1259 OID 6817155)
-- Name: mt_static3; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.mt_static3 (
    mmsi text,
    imo text,
    ship_id text,
    vessel_type text,
    length text,
    width text,
    year_built text,
    dwt text,
    engine_model text
);


ALTER TABLE rory.mt_static3 OWNER TO vliz;

--
-- TOC entry 537 (class 1259 OID 17552304)
-- Name: phd; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.phd AS
 SELECT DISTINCT ON (aa.mmsi) aa.mmsi,
    aa.type_and_cargo,
    ais_num_to_type.type AS vessel_class,
    aa.msg_type,
    aa.event_time AS voy_report_time,
    bb.event_time AS pos_report_time,
    bb.longitude,
    bb.latitude,
    bb.sog,
    bb.cog
   FROM geo.maritime_boundaries,
    ((ais.latest_voy_reports aa
     RIGHT JOIN ais.pos_reports_1h_cagg bb ON ((aa.mmsi = bb.mmsi)))
     LEFT JOIN ais.ais_num_to_type ON (((aa.type_and_cargo)::text = (ais_num_to_type.ais_num)::text)))
  WHERE (((bb.bucket >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (bb.bucket <= '2022-10-01 00:00:00+00'::timestamp with time zone)) AND public.st_within(bb."position", maritime_boundaries.geom) AND (maritime_boundaries.territory = 'Belgium'::text) AND (maritime_boundaries.pol_type <> 'Sovereign country'::text))
  ORDER BY aa.mmsi, bb.bucket
  WITH NO DATA;


ALTER TABLE rory.phd OWNER TO vliz;

--
-- TOC entry 504 (class 1259 OID 14127666)
-- Name: unseen; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.unseen (
    gid integer NOT NULL,
    id character varying(50),
    timestamp_ character varying(50),
    rf_frequen numeric,
    latitude_d numeric,
    longitude_ numeric,
    accuracy_l character varying(50),
    pulses_dur numeric,
    pulses_rep numeric,
    geom public.geometry(Point)
);


ALTER TABLE rory.unseen OWNER TO vliz;

--
-- TOC entry 503 (class 1259 OID 14127664)
-- Name: unseen_gid_seq; Type: SEQUENCE; Schema: rory; Owner: vliz
--

CREATE SEQUENCE rory.unseen_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rory.unseen_gid_seq OWNER TO vliz;

--
-- TOC entry 7682 (class 0 OID 0)
-- Dependencies: 503
-- Name: unseen_gid_seq; Type: SEQUENCE OWNED BY; Schema: rory; Owner: vliz
--

ALTER SEQUENCE rory.unseen_gid_seq OWNED BY rory.unseen.gid;


--
-- TOC entry 502 (class 1259 OID 14127649)
-- Name: unseen_sep5; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.unseen_sep5 AS
 SELECT pos_reports.mmsi,
    public.st_makeline(public.st_makepointm(pos_reports.longitude, pos_reports.latitude, date_part('epoch'::text, pos_reports.event_time)) ORDER BY pos_reports.event_time) AS st_makeline
   FROM ais.pos_reports
  WHERE ((pos_reports.event_time >= '2022-09-05 11:00:00+00'::timestamp with time zone) AND (pos_reports.event_time <= '2022-09-05 13:00:00+00'::timestamp with time zone))
  GROUP BY pos_reports.mmsi
  WITH NO DATA;


ALTER TABLE rory.unseen_sep5 OWNER TO vliz;

--
-- TOC entry 505 (class 1259 OID 14129954)
-- Name: unseen_sep5_matches; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.unseen_sep5_matches AS
 WITH lead_lag AS (
         SELECT ais.mmsi,
            ais."position",
            ais.event_time,
            ais.sog,
            (lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time) <= (ais.event_time - '01:00:00'::interval)) AS time_step,
            ((public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) < (0)::double precision) OR (public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) > (0.1)::double precision)) AS dist_step,
            ((public.st_distancesphere(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) / NULLIF(date_part('epoch'::text, (ais.event_time - lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time))), (0)::double precision)) >= (((2)::numeric * (ais.sog + 0.1)))::double precision) AS sog_step,
            public.st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) AS dist
           FROM ais.pos_reports ais,
            rory.belgium_eez_bounding_box
          WHERE ((ais.event_time >= '2022-09-05 11:00:00+00'::timestamp with time zone) AND (ais.event_time <= '2022-09-05 13:00:00+00'::timestamp with time zone))
        ), lead_lag_groups AS (
         SELECT lead_lag_1.mmsi,
            lead_lag_1."position",
            lead_lag_1.event_time,
            lead_lag_1.sog,
            lead_lag_1.time_step,
            lead_lag_1.dist_step,
            lead_lag_1.dist,
            lead_lag_1.sog_step,
            count(*) FILTER (WHERE lead_lag_1.time_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS time_grp,
            count(*) FILTER (WHERE lead_lag_1.dist_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS dist_grp,
            count(*) FILTER (WHERE lead_lag_1.sog_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS sog_grp
           FROM lead_lag lead_lag_1
          WHERE (lead_lag_1.dist > (0)::double precision)
        )
 SELECT lead_lag.mmsi,
    lead_lag.time_grp,
    lead_lag.dist_grp,
    lead_lag.sog_grp,
    public.first(lead_lag.event_time, lead_lag.event_time) AS first_time,
    public.last(lead_lag.event_time, lead_lag.event_time) AS last_time,
    public.st_length(public.st_setsrid(public.st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS geom_length,
    public.st_setsrid(public.st_makeline(public.st_makepointm(public.st_x(lead_lag."position"), public.st_y(lead_lag."position"), date_part('epoch'::text, lead_lag.event_time)) ORDER BY lead_lag.event_time), 4326) AS geom,
    public.st_astext(public.st_setsrid(public.st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS st_astext
   FROM lead_lag_groups lead_lag
  GROUP BY lead_lag.mmsi, lead_lag.time_grp, lead_lag.dist_grp, lead_lag.sog_grp
  WITH NO DATA;


ALTER TABLE rory.unseen_sep5_matches OWNER TO vliz;

--
-- TOC entry 507 (class 1259 OID 14132915)
-- Name: unseenfootprint; Type: TABLE; Schema: rory; Owner: vliz
--

CREATE TABLE rory.unseenfootprint (
    gid integer NOT NULL,
    datetime character varying(50),
    geom public.geometry(MultiPolygon)
);


ALTER TABLE rory.unseenfootprint OWNER TO vliz;

--
-- TOC entry 508 (class 1259 OID 14132981)
-- Name: unseenaugmatches; Type: MATERIALIZED VIEW; Schema: rory; Owner: vliz
--

CREATE MATERIALIZED VIEW rory.unseenaugmatches AS
 SELECT DISTINCT ON (aa.mmsi) aa.mmsi,
    aa.navigation_status,
    aa.rot,
    aa.sog,
    aa.longitude,
    aa.latitude,
    aa."position",
    aa.cog,
    aa.hdg,
    aa.event_time,
    aa.server_time,
    aa.msg_type,
    aa.routing_key,
    date_part('epoch'::text, (aa.event_time - '2022-09-05 12:03:00+00'::timestamp with time zone)) AS timedelta
   FROM ais.pos_reports aa,
    rory.unseenfootprint bb
  WHERE (public.st_within(aa."position", public.st_setsrid(bb.geom, 4326)) AND ((aa.event_time >= '2022-09-05 11:03:00+00'::timestamp with time zone) AND (aa.event_time <= '2022-09-05 13:03:00+00'::timestamp with time zone)))
  ORDER BY aa.mmsi, (abs(date_part('epoch'::text, (aa.event_time - ('2022-09-05 12:03:00'::timestamp without time zone)::timestamp with time zone))))
  WITH NO DATA;


ALTER TABLE rory.unseenaugmatches OWNER TO vliz;

--
-- TOC entry 506 (class 1259 OID 14132913)
-- Name: unseenfootprint_gid_seq; Type: SEQUENCE; Schema: rory; Owner: vliz
--

CREATE SEQUENCE rory.unseenfootprint_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rory.unseenfootprint_gid_seq OWNER TO vliz;

--
-- TOC entry 7683 (class 0 OID 0)
-- Dependencies: 506
-- Name: unseenfootprint_gid_seq; Type: SEQUENCE OWNED BY; Schema: rory; Owner: vliz
--

ALTER SEQUENCE rory.unseenfootprint_gid_seq OWNED BY rory.unseenfootprint.gid;


--
-- TOC entry 558 (class 1259 OID 23017158)
-- Name: demo_traj; Type: MATERIALIZED VIEW; Schema: schelde; Owner: vliz
--

CREATE MATERIALIZED VIEW schelde.demo_traj AS
 SELECT DISTINCT ON (traj.mmsi, traj.first_time) traj.mmsi,
    traj.first_time,
    traj.last_time,
    traj.geom,
    public.st_astext(traj.geom) AS wkt,
    ais_num_to_type.type AS class,
    voy.imo,
    voy.callsign,
    voy.name,
    voy.type_and_cargo,
    voy.to_bow,
    voy.to_stern,
    voy.to_port,
    voy.to_starboard,
    voy.draught,
    voy.destination
   FROM ((ais.trajectories traj
     LEFT JOIN ais.latest_voy_reports voy ON ((traj.mmsi = voy.mmsi)))
     LEFT JOIN ais.ais_num_to_type ON (((ais_num_to_type.ais_num)::text = (voy.type_and_cargo)::text)))
  WHERE (public.st_intersects(traj.geom, public.st_makeenvelope((2.9)::double precision, (50.9)::double precision, (4.6)::double precision, (51.7)::double precision, 4326)) AND ((traj.first_time >= '2022-01-01 00:00:00+00'::timestamp with time zone) AND (traj.first_time <= '2022-01-07 00:00:00+00'::timestamp with time zone)))
  ORDER BY traj.mmsi, traj.first_time, voy.draught
  WITH NO DATA;


ALTER TABLE schelde.demo_traj OWNER TO vliz;

--
-- TOC entry 560 (class 1259 OID 23019250)
-- Name: gebiedindeling_emse; Type: TABLE; Schema: schelde; Owner: vliz
--

CREATE TABLE schelde.gebiedindeling_emse (
    gid integer NOT NULL,
    objectid numeric,
    niveau1 character varying(254),
    niveau2 character varying(254),
    niveau3 character varying(254),
    niveau3_nr character varying(254),
    niveau3_om character varying(254),
    niveau4 character varying(254),
    niv4_begin numeric,
    niv4_eind_ numeric,
    niveau4_om character varying(254),
    krw character varying(254),
    shape_area numeric,
    geul character varying(254),
    geom public.geometry(MultiPolygon,25831)
);


ALTER TABLE schelde.gebiedindeling_emse OWNER TO vliz;

--
-- TOC entry 559 (class 1259 OID 23019248)
-- Name: gebiedindeling_emse_gid_seq; Type: SEQUENCE; Schema: schelde; Owner: vliz
--

CREATE SEQUENCE schelde.gebiedindeling_emse_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE schelde.gebiedindeling_emse_gid_seq OWNER TO vliz;

--
-- TOC entry 7684 (class 0 OID 0)
-- Dependencies: 559
-- Name: gebiedindeling_emse_gid_seq; Type: SEQUENCE OWNED BY; Schema: schelde; Owner: vliz
--

ALTER SEQUENCE schelde.gebiedindeling_emse_gid_seq OWNED BY schelde.gebiedindeling_emse.gid;


--
-- TOC entry 563 (class 1259 OID 25831015)
-- Name: heatmap; Type: MATERIALIZED VIEW; Schema: schelde; Owner: vliz
--

CREATE MATERIALIZED VIEW schelde.heatmap AS
 WITH new_grid AS (
         SELECT grid.gid,
            grid.objectid,
            grid.niveau1,
            grid.niveau2,
            grid.niveau3,
            grid.niveau3_nr,
            grid.niveau3_om,
            grid.niveau4,
            grid.niv4_begin,
            grid.niv4_eind_,
            grid.niveau4_om,
            grid.krw,
            grid.shape_area,
            grid.geul,
            grid.geom,
            public.st_transform(grid.geom, 4326) AS geom_4326
           FROM schelde.gebiedindeling_emse grid
        ), new_traj AS (
         SELECT subquery.mmsi,
            date_part('epoch'::text, (subquery.last_time - subquery.first_time)) AS time_delta,
            subquery.type_and_cargo,
            ais_num_to_type.type,
            subquery.geom,
            public.st_length(subquery.geom) AS traj_dist
           FROM (schelde.demo_traj subquery
             LEFT JOIN ais.ais_num_to_type ON (((subquery.type_and_cargo)::text = (ais_num_to_type.ais_num)::text)))
          WHERE ((public.st_length(subquery.geom) > (0)::double precision) AND (date_part('epoch'::text, (subquery.last_time - subquery.first_time)) > (0)::double precision))
        )
 SELECT new_grid.gid,
    traj.type_and_cargo,
    sum(((public.st_length(public.st_intersection(traj.geom, new_grid.geom_4326)) * traj.time_delta) / traj.traj_dist)) AS cum_time_in_grid,
    count(traj.geom) AS track_count
   FROM (new_traj traj
     JOIN new_grid ON (public.st_intersects(traj.geom, new_grid.geom_4326)))
  GROUP BY new_grid.gid, traj.type_and_cargo
  WITH NO DATA;


ALTER TABLE schelde.heatmap OWNER TO vliz;

--
-- TOC entry 6055 (class 2604 OID 67966)
-- Name: admin_0_countries gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.admin_0_countries ALTER COLUMN gid SET DEFAULT nextval('geo.admin_0_countries_gid_seq'::regclass);


--
-- TOC entry 6017 (class 2604 OID 18783)
-- Name: eez_12nm gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_12nm ALTER COLUMN gid SET DEFAULT nextval('geo.eez_12nm_gid_seq'::regclass);


--
-- TOC entry 6016 (class 2604 OID 18516)
-- Name: eez_24nm gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_24nm ALTER COLUMN gid SET DEFAULT nextval('geo.eez_24nm_gid_seq'::regclass);


--
-- TOC entry 6019 (class 2604 OID 19239)
-- Name: eez_archipelagic_waters gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_archipelagic_waters ALTER COLUMN gid SET DEFAULT nextval('geo.eez_archipelagic_waters_gid_seq'::regclass);


--
-- TOC entry 6018 (class 2604 OID 19054)
-- Name: eez_internal_waters gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_internal_waters ALTER COLUMN gid SET DEFAULT nextval('geo.eez_internal_waters_gid_seq'::regclass);


--
-- TOC entry 6020 (class 2604 OID 19299)
-- Name: oceans_world gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.oceans_world ALTER COLUMN gid SET DEFAULT nextval('geo.oceans_world_gid_seq'::regclass);


--
-- TOC entry 6022 (class 2604 OID 19327)
-- Name: sampaz gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.sampaz ALTER COLUMN gid SET DEFAULT nextval('geo.sampaz_gid_seq'::regclass);


--
-- TOC entry 6015 (class 2604 OID 17990)
-- Name: world_eez gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.world_eez ALTER COLUMN gid SET DEFAULT nextval('geo.world_eez_gid_seq'::regclass);


--
-- TOC entry 6021 (class 2604 OID 19313)
-- Name: world_port_index gid; Type: DEFAULT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.world_port_index ALTER COLUMN gid SET DEFAULT nextval('geo.world_port_index_gid_seq'::regclass);


--
-- TOC entry 6166 (class 2604 OID 14127669)
-- Name: unseen gid; Type: DEFAULT; Schema: rory; Owner: vliz
--

ALTER TABLE ONLY rory.unseen ALTER COLUMN gid SET DEFAULT nextval('rory.unseen_gid_seq'::regclass);


--
-- TOC entry 6167 (class 2604 OID 14132918)
-- Name: unseenfootprint gid; Type: DEFAULT; Schema: rory; Owner: vliz
--

ALTER TABLE ONLY rory.unseenfootprint ALTER COLUMN gid SET DEFAULT nextval('rory.unseenfootprint_gid_seq'::regclass);


--
-- TOC entry 6196 (class 2604 OID 23019253)
-- Name: gebiedindeling_emse gid; Type: DEFAULT; Schema: schelde; Owner: vliz
--

ALTER TABLE ONLY schelde.gebiedindeling_emse ALTER COLUMN gid SET DEFAULT nextval('schelde.gebiedindeling_emse_gid_seq'::regclass);


--
-- TOC entry 6465 (class 2606 OID 129967)
-- Name: latest_voy_reports mmsi_rkey; Type: CONSTRAINT; Schema: ais; Owner: vliz
--

ALTER TABLE ONLY ais.latest_voy_reports
    ADD CONSTRAINT mmsi_rkey UNIQUE (mmsi, routing_key);


--
-- TOC entry 6422 (class 2606 OID 67971)
-- Name: admin_0_countries admin_0_countries_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.admin_0_countries
    ADD CONSTRAINT admin_0_countries_pkey PRIMARY KEY (gid);


--
-- TOC entry 6315 (class 2606 OID 18788)
-- Name: eez_12nm eez_12nm_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_12nm
    ADD CONSTRAINT eez_12nm_pkey PRIMARY KEY (gid);


--
-- TOC entry 6312 (class 2606 OID 18521)
-- Name: eez_24nm eez_24nm_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_24nm
    ADD CONSTRAINT eez_24nm_pkey PRIMARY KEY (gid);


--
-- TOC entry 6321 (class 2606 OID 19244)
-- Name: eez_archipelagic_waters eez_archipelagic_waters_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_archipelagic_waters
    ADD CONSTRAINT eez_archipelagic_waters_pkey PRIMARY KEY (gid);


--
-- TOC entry 6318 (class 2606 OID 19059)
-- Name: eez_internal_waters eez_internal_waters_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.eez_internal_waters
    ADD CONSTRAINT eez_internal_waters_pkey PRIMARY KEY (gid);


--
-- TOC entry 6324 (class 2606 OID 19304)
-- Name: oceans_world oceans_world_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.oceans_world
    ADD CONSTRAINT oceans_world_pkey PRIMARY KEY (gid);


--
-- TOC entry 6330 (class 2606 OID 19332)
-- Name: sampaz sampaz_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.sampaz
    ADD CONSTRAINT sampaz_pkey PRIMARY KEY (gid);


--
-- TOC entry 6309 (class 2606 OID 17995)
-- Name: world_eez world_eez_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.world_eez
    ADD CONSTRAINT world_eez_pkey PRIMARY KEY (gid);


--
-- TOC entry 6327 (class 2606 OID 19318)
-- Name: world_port_index world_port_index_pkey; Type: CONSTRAINT; Schema: geo; Owner: vliz
--

ALTER TABLE ONLY geo.world_port_index
    ADD CONSTRAINT world_port_index_pkey PRIMARY KEY (gid);


--
-- TOC entry 6772 (class 2606 OID 14127674)
-- Name: unseen unseen_pkey; Type: CONSTRAINT; Schema: rory; Owner: vliz
--

ALTER TABLE ONLY rory.unseen
    ADD CONSTRAINT unseen_pkey PRIMARY KEY (gid);


--
-- TOC entry 6774 (class 2606 OID 14132920)
-- Name: unseenfootprint unseenfootprint_pkey; Type: CONSTRAINT; Schema: rory; Owner: vliz
--

ALTER TABLE ONLY rory.unseenfootprint
    ADD CONSTRAINT unseenfootprint_pkey PRIMARY KEY (gid);


--
-- TOC entry 6867 (class 2606 OID 23019258)
-- Name: gebiedindeling_emse gebiedindeling_emse_pkey; Type: CONSTRAINT; Schema: schelde; Owner: vliz
--

ALTER TABLE ONLY schelde.gebiedindeling_emse
    ADD CONSTRAINT gebiedindeling_emse_pkey PRIMARY KEY (gid);


--
-- TOC entry 6520 (class 1259 OID 180188)
-- Name: _compressed_hypertable_6_mmsi__ts_meta_sequence_num_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _compressed_hypertable_6_mmsi__ts_meta_sequence_num_idx ON _timescaledb_internal._compressed_hypertable_6 USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6573 (class 1259 OID 6521423)
-- Name: _hyper_1_100_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_100_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_100_chunk USING btree (event_time DESC);


--
-- TOC entry 6574 (class 1259 OID 6521424)
-- Name: _hyper_1_100_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_100_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_100_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6575 (class 1259 OID 6521425)
-- Name: _hyper_1_100_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_100_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_100_chunk USING gist ("position");


--
-- TOC entry 6579 (class 1259 OID 6819876)
-- Name: _hyper_1_118_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_118_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_118_chunk USING btree (event_time DESC);


--
-- TOC entry 6580 (class 1259 OID 6819877)
-- Name: _hyper_1_118_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_118_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_118_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6581 (class 1259 OID 6819878)
-- Name: _hyper_1_118_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_118_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_118_chunk USING gist ("position");


--
-- TOC entry 6582 (class 1259 OID 6819887)
-- Name: _hyper_1_119_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_119_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_119_chunk USING btree (event_time DESC);


--
-- TOC entry 6583 (class 1259 OID 6819888)
-- Name: _hyper_1_119_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_119_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_119_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6584 (class 1259 OID 6819889)
-- Name: _hyper_1_119_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_119_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_119_chunk USING gist ("position");


--
-- TOC entry 6364 (class 1259 OID 25881)
-- Name: _hyper_1_11_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_11_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_11_chunk USING btree (event_time DESC);


--
-- TOC entry 6365 (class 1259 OID 25882)
-- Name: _hyper_1_11_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_11_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_11_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6366 (class 1259 OID 25883)
-- Name: _hyper_1_11_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_11_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_11_chunk USING gist ("position");


--
-- TOC entry 6585 (class 1259 OID 6819898)
-- Name: _hyper_1_120_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_120_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_120_chunk USING btree (event_time DESC);


--
-- TOC entry 6586 (class 1259 OID 6819899)
-- Name: _hyper_1_120_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_120_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_120_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6587 (class 1259 OID 6819900)
-- Name: _hyper_1_120_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_120_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_120_chunk USING gist ("position");


--
-- TOC entry 6588 (class 1259 OID 6819909)
-- Name: _hyper_1_121_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_121_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_121_chunk USING btree (event_time DESC);


--
-- TOC entry 6589 (class 1259 OID 6819910)
-- Name: _hyper_1_121_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_121_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_121_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6590 (class 1259 OID 6819911)
-- Name: _hyper_1_121_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_121_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_121_chunk USING gist ("position");


--
-- TOC entry 6591 (class 1259 OID 6819920)
-- Name: _hyper_1_122_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_122_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_122_chunk USING btree (event_time DESC);


--
-- TOC entry 6592 (class 1259 OID 6819921)
-- Name: _hyper_1_122_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_122_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_122_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6593 (class 1259 OID 6819922)
-- Name: _hyper_1_122_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_122_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_122_chunk USING gist ("position");


--
-- TOC entry 6594 (class 1259 OID 6819931)
-- Name: _hyper_1_123_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_123_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_123_chunk USING btree (event_time DESC);


--
-- TOC entry 6595 (class 1259 OID 6819932)
-- Name: _hyper_1_123_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_123_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_123_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6596 (class 1259 OID 6819933)
-- Name: _hyper_1_123_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_123_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_123_chunk USING gist ("position");


--
-- TOC entry 6597 (class 1259 OID 6819942)
-- Name: _hyper_1_124_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_124_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_124_chunk USING btree (event_time DESC);


--
-- TOC entry 6598 (class 1259 OID 6819943)
-- Name: _hyper_1_124_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_124_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_124_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6599 (class 1259 OID 6819944)
-- Name: _hyper_1_124_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_124_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_124_chunk USING gist ("position");


--
-- TOC entry 6600 (class 1259 OID 6819953)
-- Name: _hyper_1_125_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_125_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_125_chunk USING btree (event_time DESC);


--
-- TOC entry 6601 (class 1259 OID 6819954)
-- Name: _hyper_1_125_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_125_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_125_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6602 (class 1259 OID 6819955)
-- Name: _hyper_1_125_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_125_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_125_chunk USING gist ("position");


--
-- TOC entry 6603 (class 1259 OID 6819964)
-- Name: _hyper_1_126_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_126_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_126_chunk USING btree (event_time DESC);


--
-- TOC entry 6604 (class 1259 OID 6819965)
-- Name: _hyper_1_126_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_126_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_126_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6605 (class 1259 OID 6819966)
-- Name: _hyper_1_126_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_126_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_126_chunk USING gist ("position");


--
-- TOC entry 6606 (class 1259 OID 6819975)
-- Name: _hyper_1_127_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_127_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_127_chunk USING btree (event_time DESC);


--
-- TOC entry 6607 (class 1259 OID 6819976)
-- Name: _hyper_1_127_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_127_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_127_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6608 (class 1259 OID 6819977)
-- Name: _hyper_1_127_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_127_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_127_chunk USING gist ("position");


--
-- TOC entry 6609 (class 1259 OID 6819986)
-- Name: _hyper_1_128_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_128_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_128_chunk USING btree (event_time DESC);


--
-- TOC entry 6610 (class 1259 OID 6819987)
-- Name: _hyper_1_128_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_128_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_128_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6611 (class 1259 OID 6819988)
-- Name: _hyper_1_128_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_128_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_128_chunk USING gist ("position");


--
-- TOC entry 6612 (class 1259 OID 6819997)
-- Name: _hyper_1_129_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_129_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_129_chunk USING btree (event_time DESC);


--
-- TOC entry 6613 (class 1259 OID 6819998)
-- Name: _hyper_1_129_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_129_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_129_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6614 (class 1259 OID 6819999)
-- Name: _hyper_1_129_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_129_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_129_chunk USING gist ("position");


--
-- TOC entry 6615 (class 1259 OID 6820008)
-- Name: _hyper_1_130_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_130_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_130_chunk USING btree (event_time DESC);


--
-- TOC entry 6616 (class 1259 OID 6820009)
-- Name: _hyper_1_130_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_130_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_130_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6617 (class 1259 OID 6820010)
-- Name: _hyper_1_130_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_130_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_130_chunk USING gist ("position");


--
-- TOC entry 6618 (class 1259 OID 6820019)
-- Name: _hyper_1_131_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_131_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_131_chunk USING btree (event_time DESC);


--
-- TOC entry 6619 (class 1259 OID 6820020)
-- Name: _hyper_1_131_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_131_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_131_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6620 (class 1259 OID 6820021)
-- Name: _hyper_1_131_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_131_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_131_chunk USING gist ("position");


--
-- TOC entry 6621 (class 1259 OID 6820030)
-- Name: _hyper_1_132_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_132_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_132_chunk USING btree (event_time DESC);


--
-- TOC entry 6622 (class 1259 OID 6820031)
-- Name: _hyper_1_132_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_132_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_132_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6623 (class 1259 OID 6820032)
-- Name: _hyper_1_132_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_132_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_132_chunk USING gist ("position");


--
-- TOC entry 6624 (class 1259 OID 6820041)
-- Name: _hyper_1_133_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_133_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_133_chunk USING btree (event_time DESC);


--
-- TOC entry 6625 (class 1259 OID 6820042)
-- Name: _hyper_1_133_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_133_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_133_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6626 (class 1259 OID 6820043)
-- Name: _hyper_1_133_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_133_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_133_chunk USING gist ("position");


--
-- TOC entry 6627 (class 1259 OID 6820052)
-- Name: _hyper_1_134_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_134_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_134_chunk USING btree (event_time DESC);


--
-- TOC entry 6628 (class 1259 OID 6820053)
-- Name: _hyper_1_134_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_134_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_134_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6629 (class 1259 OID 6820054)
-- Name: _hyper_1_134_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_134_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_134_chunk USING gist ("position");


--
-- TOC entry 6630 (class 1259 OID 6820063)
-- Name: _hyper_1_135_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_135_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_135_chunk USING btree (event_time DESC);


--
-- TOC entry 6631 (class 1259 OID 6820064)
-- Name: _hyper_1_135_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_135_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_135_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6632 (class 1259 OID 6820065)
-- Name: _hyper_1_135_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_135_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_135_chunk USING gist ("position");


--
-- TOC entry 6633 (class 1259 OID 6820074)
-- Name: _hyper_1_136_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_136_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_136_chunk USING btree (event_time DESC);


--
-- TOC entry 6634 (class 1259 OID 6820075)
-- Name: _hyper_1_136_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_136_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_136_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6635 (class 1259 OID 6820076)
-- Name: _hyper_1_136_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_136_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_136_chunk USING gist ("position");


--
-- TOC entry 6636 (class 1259 OID 6820085)
-- Name: _hyper_1_137_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_137_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_137_chunk USING btree (event_time DESC);


--
-- TOC entry 6637 (class 1259 OID 6820086)
-- Name: _hyper_1_137_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_137_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_137_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6638 (class 1259 OID 6820087)
-- Name: _hyper_1_137_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_137_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_137_chunk USING gist ("position");


--
-- TOC entry 6639 (class 1259 OID 6820096)
-- Name: _hyper_1_138_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_138_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_138_chunk USING btree (event_time DESC);


--
-- TOC entry 6640 (class 1259 OID 6820097)
-- Name: _hyper_1_138_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_138_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_138_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6641 (class 1259 OID 6820098)
-- Name: _hyper_1_138_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_138_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_138_chunk USING gist ("position");


--
-- TOC entry 6642 (class 1259 OID 6820107)
-- Name: _hyper_1_139_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_139_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_139_chunk USING btree (event_time DESC);


--
-- TOC entry 6643 (class 1259 OID 6820108)
-- Name: _hyper_1_139_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_139_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_139_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6644 (class 1259 OID 6820109)
-- Name: _hyper_1_139_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_139_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_139_chunk USING gist ("position");


--
-- TOC entry 6369 (class 1259 OID 36435)
-- Name: _hyper_1_13_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_13_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_13_chunk USING btree (event_time DESC);


--
-- TOC entry 6370 (class 1259 OID 36436)
-- Name: _hyper_1_13_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_13_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_13_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6371 (class 1259 OID 36437)
-- Name: _hyper_1_13_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_13_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_13_chunk USING gist ("position");


--
-- TOC entry 6645 (class 1259 OID 6820118)
-- Name: _hyper_1_140_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_140_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_140_chunk USING btree (event_time DESC);


--
-- TOC entry 6646 (class 1259 OID 6820119)
-- Name: _hyper_1_140_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_140_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_140_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6647 (class 1259 OID 6820120)
-- Name: _hyper_1_140_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_140_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_140_chunk USING gist ("position");


--
-- TOC entry 6648 (class 1259 OID 6820129)
-- Name: _hyper_1_141_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_141_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_141_chunk USING btree (event_time DESC);


--
-- TOC entry 6649 (class 1259 OID 6820130)
-- Name: _hyper_1_141_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_141_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_141_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6650 (class 1259 OID 6820131)
-- Name: _hyper_1_141_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_141_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_141_chunk USING gist ("position");


--
-- TOC entry 6651 (class 1259 OID 6820140)
-- Name: _hyper_1_142_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_142_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_142_chunk USING btree (event_time DESC);


--
-- TOC entry 6652 (class 1259 OID 6820141)
-- Name: _hyper_1_142_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_142_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_142_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6653 (class 1259 OID 6820142)
-- Name: _hyper_1_142_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_142_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_142_chunk USING gist ("position");


--
-- TOC entry 6654 (class 1259 OID 6820151)
-- Name: _hyper_1_143_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_143_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_143_chunk USING btree (event_time DESC);


--
-- TOC entry 6655 (class 1259 OID 6820152)
-- Name: _hyper_1_143_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_143_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_143_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6656 (class 1259 OID 6820153)
-- Name: _hyper_1_143_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_143_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_143_chunk USING gist ("position");


--
-- TOC entry 6657 (class 1259 OID 6820162)
-- Name: _hyper_1_144_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_144_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_144_chunk USING btree (event_time DESC);


--
-- TOC entry 6658 (class 1259 OID 6820163)
-- Name: _hyper_1_144_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_144_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_144_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6659 (class 1259 OID 6820164)
-- Name: _hyper_1_144_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_144_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_144_chunk USING gist ("position");


--
-- TOC entry 6660 (class 1259 OID 6820173)
-- Name: _hyper_1_145_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_145_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_145_chunk USING btree (event_time DESC);


--
-- TOC entry 6661 (class 1259 OID 6820174)
-- Name: _hyper_1_145_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_145_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_145_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6662 (class 1259 OID 6820175)
-- Name: _hyper_1_145_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_145_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_145_chunk USING gist ("position");


--
-- TOC entry 6669 (class 1259 OID 6822279)
-- Name: _hyper_1_148_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_148_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_148_chunk USING btree (event_time DESC);


--
-- TOC entry 6670 (class 1259 OID 6822280)
-- Name: _hyper_1_148_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_148_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_148_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6671 (class 1259 OID 6822281)
-- Name: _hyper_1_148_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_148_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_148_chunk USING gist ("position");


--
-- TOC entry 6675 (class 1259 OID 7148773)
-- Name: _hyper_1_151_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_151_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_151_chunk USING btree (event_time DESC);


--
-- TOC entry 6676 (class 1259 OID 7148774)
-- Name: _hyper_1_151_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_151_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_151_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6677 (class 1259 OID 7148775)
-- Name: _hyper_1_151_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_151_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_151_chunk USING gist ("position");


--
-- TOC entry 6681 (class 1259 OID 7479149)
-- Name: _hyper_1_154_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_154_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_154_chunk USING btree (event_time DESC);


--
-- TOC entry 6682 (class 1259 OID 7479150)
-- Name: _hyper_1_154_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_154_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_154_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6683 (class 1259 OID 7479151)
-- Name: _hyper_1_154_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_154_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_154_chunk USING gist ("position");


--
-- TOC entry 6687 (class 1259 OID 7839723)
-- Name: _hyper_1_157_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_157_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_157_chunk USING btree (event_time DESC);


--
-- TOC entry 6688 (class 1259 OID 7839724)
-- Name: _hyper_1_157_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_157_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_157_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6689 (class 1259 OID 7839725)
-- Name: _hyper_1_157_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_157_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_157_chunk USING gist ("position");


--
-- TOC entry 6374 (class 1259 OID 36816)
-- Name: _hyper_1_15_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_15_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_15_chunk USING btree (event_time DESC);


--
-- TOC entry 6375 (class 1259 OID 36817)
-- Name: _hyper_1_15_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_15_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_15_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6376 (class 1259 OID 36818)
-- Name: _hyper_1_15_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_15_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_15_chunk USING gist ("position");


--
-- TOC entry 6696 (class 1259 OID 8547908)
-- Name: _hyper_1_162_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_162_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_162_chunk USING btree (event_time DESC);


--
-- TOC entry 6697 (class 1259 OID 8547909)
-- Name: _hyper_1_162_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_162_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_162_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6698 (class 1259 OID 8547910)
-- Name: _hyper_1_162_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_162_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_162_chunk USING gist ("position");


--
-- TOC entry 6700 (class 1259 OID 8980675)
-- Name: _hyper_1_164_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_164_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_164_chunk USING btree (event_time DESC);


--
-- TOC entry 6701 (class 1259 OID 8980676)
-- Name: _hyper_1_164_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_164_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_164_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6702 (class 1259 OID 8980677)
-- Name: _hyper_1_164_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_164_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_164_chunk USING gist ("position");


--
-- TOC entry 6706 (class 1259 OID 9267746)
-- Name: _hyper_1_167_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_167_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_167_chunk USING btree (event_time DESC);


--
-- TOC entry 6707 (class 1259 OID 9267747)
-- Name: _hyper_1_167_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_167_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_167_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6708 (class 1259 OID 9267748)
-- Name: _hyper_1_167_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_167_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_167_chunk USING gist ("position");


--
-- TOC entry 6718 (class 1259 OID 9736633)
-- Name: _hyper_1_172_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_172_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_172_chunk USING btree (event_time DESC);


--
-- TOC entry 6719 (class 1259 OID 9736634)
-- Name: _hyper_1_172_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_172_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_172_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6720 (class 1259 OID 9736635)
-- Name: _hyper_1_172_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_172_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_172_chunk USING gist ("position");


--
-- TOC entry 6724 (class 1259 OID 10228147)
-- Name: _hyper_1_175_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_175_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_175_chunk USING btree (event_time DESC);


--
-- TOC entry 6725 (class 1259 OID 10228148)
-- Name: _hyper_1_175_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_175_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_175_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6726 (class 1259 OID 10228149)
-- Name: _hyper_1_175_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_175_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_175_chunk USING gist ("position");


--
-- TOC entry 6730 (class 1259 OID 10732085)
-- Name: _hyper_1_178_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_178_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_178_chunk USING btree (event_time DESC);


--
-- TOC entry 6731 (class 1259 OID 10732086)
-- Name: _hyper_1_178_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_178_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_178_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6732 (class 1259 OID 10732087)
-- Name: _hyper_1_178_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_178_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_178_chunk USING gist ("position");


--
-- TOC entry 6379 (class 1259 OID 37191)
-- Name: _hyper_1_17_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_17_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_17_chunk USING btree (event_time DESC);


--
-- TOC entry 6380 (class 1259 OID 37192)
-- Name: _hyper_1_17_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_17_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_17_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6381 (class 1259 OID 37193)
-- Name: _hyper_1_17_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_17_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_17_chunk USING gist ("position");


--
-- TOC entry 6736 (class 1259 OID 11235465)
-- Name: _hyper_1_181_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_181_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_181_chunk USING btree (event_time DESC);


--
-- TOC entry 6737 (class 1259 OID 11235466)
-- Name: _hyper_1_181_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_181_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_181_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6738 (class 1259 OID 11235467)
-- Name: _hyper_1_181_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_181_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_181_chunk USING gist ("position");


--
-- TOC entry 6742 (class 1259 OID 11758318)
-- Name: _hyper_1_184_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_184_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_184_chunk USING btree (event_time DESC);


--
-- TOC entry 6743 (class 1259 OID 11758319)
-- Name: _hyper_1_184_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_184_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_184_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6744 (class 1259 OID 11758320)
-- Name: _hyper_1_184_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_184_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_184_chunk USING gist ("position");


--
-- TOC entry 6748 (class 1259 OID 12285410)
-- Name: _hyper_1_187_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_187_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_187_chunk USING btree (event_time DESC);


--
-- TOC entry 6749 (class 1259 OID 12285411)
-- Name: _hyper_1_187_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_187_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_187_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6750 (class 1259 OID 12285412)
-- Name: _hyper_1_187_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_187_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_187_chunk USING gist ("position");


--
-- TOC entry 6754 (class 1259 OID 12492986)
-- Name: _hyper_1_190_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_190_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_190_chunk USING btree (event_time DESC);


--
-- TOC entry 6755 (class 1259 OID 12492987)
-- Name: _hyper_1_190_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_190_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_190_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6756 (class 1259 OID 12492988)
-- Name: _hyper_1_190_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_190_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_190_chunk USING gist ("position");


--
-- TOC entry 6759 (class 1259 OID 12498854)
-- Name: _hyper_1_192_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_192_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_192_chunk USING btree (event_time DESC);


--
-- TOC entry 6760 (class 1259 OID 12498855)
-- Name: _hyper_1_192_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_192_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_192_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6761 (class 1259 OID 12498856)
-- Name: _hyper_1_192_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_192_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_192_chunk USING gist ("position");


--
-- TOC entry 6765 (class 1259 OID 13022945)
-- Name: _hyper_1_195_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_195_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_195_chunk USING btree (event_time DESC);


--
-- TOC entry 6766 (class 1259 OID 13022946)
-- Name: _hyper_1_195_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_195_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_195_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6767 (class 1259 OID 13022947)
-- Name: _hyper_1_195_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_195_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_195_chunk USING gist ("position");


--
-- TOC entry 6775 (class 1259 OID 14137178)
-- Name: _hyper_1_198_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_198_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_198_chunk USING btree (event_time DESC);


--
-- TOC entry 6776 (class 1259 OID 14137179)
-- Name: _hyper_1_198_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_198_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_198_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6777 (class 1259 OID 14137180)
-- Name: _hyper_1_198_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_198_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_198_chunk USING gist ("position");


--
-- TOC entry 6384 (class 1259 OID 52091)
-- Name: _hyper_1_19_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_19_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_19_chunk USING btree (event_time DESC);


--
-- TOC entry 6385 (class 1259 OID 52092)
-- Name: _hyper_1_19_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_19_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_19_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6386 (class 1259 OID 52093)
-- Name: _hyper_1_19_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_19_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_19_chunk USING gist ("position");


--
-- TOC entry 6331 (class 1259 OID 24583)
-- Name: _hyper_1_1_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_1_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_1_chunk USING btree (event_time DESC);


--
-- TOC entry 6332 (class 1259 OID 24584)
-- Name: _hyper_1_1_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_1_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_1_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6333 (class 1259 OID 24585)
-- Name: _hyper_1_1_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_1_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_1_chunk USING gist ("position");


--
-- TOC entry 6787 (class 1259 OID 14694316)
-- Name: _hyper_1_203_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_203_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_203_chunk USING btree (event_time DESC);


--
-- TOC entry 6788 (class 1259 OID 14694317)
-- Name: _hyper_1_203_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_203_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_203_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6789 (class 1259 OID 14694318)
-- Name: _hyper_1_203_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_203_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_203_chunk USING gist ("position");


--
-- TOC entry 6793 (class 1259 OID 15271006)
-- Name: _hyper_1_206_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_206_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_206_chunk USING btree (event_time DESC);


--
-- TOC entry 6794 (class 1259 OID 15271007)
-- Name: _hyper_1_206_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_206_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_206_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6795 (class 1259 OID 15271008)
-- Name: _hyper_1_206_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_206_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_206_chunk USING gist ("position");


--
-- TOC entry 6799 (class 1259 OID 15848144)
-- Name: _hyper_1_209_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_209_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_209_chunk USING btree (event_time DESC);


--
-- TOC entry 6800 (class 1259 OID 15848145)
-- Name: _hyper_1_209_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_209_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_209_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6801 (class 1259 OID 15848146)
-- Name: _hyper_1_209_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_209_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_209_chunk USING gist ("position");


--
-- TOC entry 6805 (class 1259 OID 16429906)
-- Name: _hyper_1_212_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_212_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_212_chunk USING btree (event_time DESC);


--
-- TOC entry 6806 (class 1259 OID 16429907)
-- Name: _hyper_1_212_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_212_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_212_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6807 (class 1259 OID 16429908)
-- Name: _hyper_1_212_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_212_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_212_chunk USING gist ("position");


--
-- TOC entry 6814 (class 1259 OID 16996379)
-- Name: _hyper_1_216_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_216_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_216_chunk USING btree (event_time DESC);


--
-- TOC entry 6815 (class 1259 OID 16996380)
-- Name: _hyper_1_216_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_216_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_216_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6816 (class 1259 OID 16996381)
-- Name: _hyper_1_216_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_216_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_216_chunk USING gist ("position");


--
-- TOC entry 6821 (class 1259 OID 17552494)
-- Name: _hyper_1_218_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_218_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_218_chunk USING btree (event_time DESC);


--
-- TOC entry 6822 (class 1259 OID 17552495)
-- Name: _hyper_1_218_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_218_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_218_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6823 (class 1259 OID 17552496)
-- Name: _hyper_1_218_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_218_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_218_chunk USING gist ("position");


--
-- TOC entry 6389 (class 1259 OID 52554)
-- Name: _hyper_1_21_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_21_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_21_chunk USING btree (event_time DESC);


--
-- TOC entry 6390 (class 1259 OID 52555)
-- Name: _hyper_1_21_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_21_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_21_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6391 (class 1259 OID 52556)
-- Name: _hyper_1_21_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_21_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_21_chunk USING gist ("position");


--
-- TOC entry 6827 (class 1259 OID 18081993)
-- Name: _hyper_1_221_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_221_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_221_chunk USING btree (event_time DESC);


--
-- TOC entry 6828 (class 1259 OID 18081994)
-- Name: _hyper_1_221_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_221_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_221_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6829 (class 1259 OID 18081995)
-- Name: _hyper_1_221_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_221_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_221_chunk USING gist ("position");


--
-- TOC entry 6835 (class 1259 OID 18797344)
-- Name: _hyper_1_224_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_224_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_224_chunk USING btree (event_time DESC);


--
-- TOC entry 6836 (class 1259 OID 18797345)
-- Name: _hyper_1_224_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_224_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_224_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6837 (class 1259 OID 18797346)
-- Name: _hyper_1_224_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_224_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_224_chunk USING gist ("position");


--
-- TOC entry 6841 (class 1259 OID 20176729)
-- Name: _hyper_1_227_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_227_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_227_chunk USING btree (event_time DESC);


--
-- TOC entry 6842 (class 1259 OID 20176730)
-- Name: _hyper_1_227_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_227_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_227_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6843 (class 1259 OID 20176731)
-- Name: _hyper_1_227_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_227_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_227_chunk USING gist ("position");


--
-- TOC entry 6847 (class 1259 OID 21597023)
-- Name: _hyper_1_230_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_230_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_230_chunk USING btree (event_time DESC);


--
-- TOC entry 6848 (class 1259 OID 21597024)
-- Name: _hyper_1_230_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_230_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_230_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6849 (class 1259 OID 21597025)
-- Name: _hyper_1_230_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_230_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_230_chunk USING gist ("position");


--
-- TOC entry 6859 (class 1259 OID 23006082)
-- Name: _hyper_1_235_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_235_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_235_chunk USING btree (event_time DESC);


--
-- TOC entry 6860 (class 1259 OID 23006083)
-- Name: _hyper_1_235_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_235_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_235_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6861 (class 1259 OID 23006084)
-- Name: _hyper_1_235_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_235_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_235_chunk USING gist ("position");


--
-- TOC entry 6870 (class 1259 OID 25832596)
-- Name: _hyper_1_239_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_239_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_239_chunk USING btree (event_time DESC);


--
-- TOC entry 6871 (class 1259 OID 25832597)
-- Name: _hyper_1_239_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_239_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_239_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6872 (class 1259 OID 25832598)
-- Name: _hyper_1_239_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_239_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_239_chunk USING gist ("position");


--
-- TOC entry 6394 (class 1259 OID 52926)
-- Name: _hyper_1_23_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_23_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_23_chunk USING btree (event_time DESC);


--
-- TOC entry 6395 (class 1259 OID 52927)
-- Name: _hyper_1_23_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_23_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_23_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6396 (class 1259 OID 52928)
-- Name: _hyper_1_23_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_23_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_23_chunk USING gist ("position");


--
-- TOC entry 6876 (class 1259 OID 27178898)
-- Name: _hyper_1_242_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_242_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_242_chunk USING btree (event_time DESC);


--
-- TOC entry 6877 (class 1259 OID 27178899)
-- Name: _hyper_1_242_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_242_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_242_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6878 (class 1259 OID 27178900)
-- Name: _hyper_1_242_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_242_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_242_chunk USING gist ("position");


--
-- TOC entry 6882 (class 1259 OID 28545445)
-- Name: _hyper_1_245_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_245_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_245_chunk USING btree (event_time DESC);


--
-- TOC entry 6883 (class 1259 OID 28545446)
-- Name: _hyper_1_245_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_245_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_245_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6884 (class 1259 OID 28545447)
-- Name: _hyper_1_245_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_245_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_245_chunk USING gist ("position");


--
-- TOC entry 6888 (class 1259 OID 29876899)
-- Name: _hyper_1_248_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_248_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_248_chunk USING btree (event_time DESC);


--
-- TOC entry 6889 (class 1259 OID 29876900)
-- Name: _hyper_1_248_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_248_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_248_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6890 (class 1259 OID 29876901)
-- Name: _hyper_1_248_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_248_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_248_chunk USING gist ("position");


--
-- TOC entry 6894 (class 1259 OID 31351418)
-- Name: _hyper_1_251_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_251_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_251_chunk USING btree (event_time DESC);


--
-- TOC entry 6895 (class 1259 OID 31351419)
-- Name: _hyper_1_251_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_251_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_251_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6896 (class 1259 OID 31351420)
-- Name: _hyper_1_251_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_251_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_251_chunk USING gist ("position");


--
-- TOC entry 6902 (class 1259 OID 32687040)
-- Name: _hyper_1_255_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_255_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_255_chunk USING btree (event_time DESC);


--
-- TOC entry 6903 (class 1259 OID 32687041)
-- Name: _hyper_1_255_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_255_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_255_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6904 (class 1259 OID 32687042)
-- Name: _hyper_1_255_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_255_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_255_chunk USING gist ("position");


--
-- TOC entry 6906 (class 1259 OID 34051006)
-- Name: _hyper_1_257_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_257_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_257_chunk USING btree (event_time DESC);


--
-- TOC entry 6907 (class 1259 OID 34051007)
-- Name: _hyper_1_257_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_257_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_257_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6908 (class 1259 OID 34051008)
-- Name: _hyper_1_257_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_257_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_257_chunk USING gist ("position");


--
-- TOC entry 6399 (class 1259 OID 66590)
-- Name: _hyper_1_25_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_25_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_25_chunk USING btree (event_time DESC);


--
-- TOC entry 6400 (class 1259 OID 66591)
-- Name: _hyper_1_25_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_25_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_25_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6401 (class 1259 OID 66592)
-- Name: _hyper_1_25_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_25_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_25_chunk USING gist ("position");


--
-- TOC entry 6912 (class 1259 OID 35482477)
-- Name: _hyper_1_260_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_260_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_260_chunk USING btree (event_time DESC);


--
-- TOC entry 6913 (class 1259 OID 35482478)
-- Name: _hyper_1_260_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_260_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_260_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6914 (class 1259 OID 35482479)
-- Name: _hyper_1_260_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_260_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_260_chunk USING gist ("position");


--
-- TOC entry 6917 (class 1259 OID 35494467)
-- Name: _hyper_1_262_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_262_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_262_chunk USING btree (event_time DESC);


--
-- TOC entry 6918 (class 1259 OID 35494468)
-- Name: _hyper_1_262_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_262_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_262_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6919 (class 1259 OID 35494469)
-- Name: _hyper_1_262_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_262_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_262_chunk USING gist ("position");


--
-- TOC entry 6929 (class 1259 OID 36945278)
-- Name: _hyper_1_267_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_267_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_267_chunk USING btree (event_time DESC);


--
-- TOC entry 6930 (class 1259 OID 36945279)
-- Name: _hyper_1_267_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_267_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_267_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6931 (class 1259 OID 36945280)
-- Name: _hyper_1_267_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_267_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_267_chunk USING gist ("position");


--
-- TOC entry 6935 (class 1259 OID 38434299)
-- Name: _hyper_1_270_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_270_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_270_chunk USING btree (event_time DESC);


--
-- TOC entry 6936 (class 1259 OID 38434300)
-- Name: _hyper_1_270_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_270_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_270_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6937 (class 1259 OID 38434301)
-- Name: _hyper_1_270_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_270_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_270_chunk USING gist ("position");


--
-- TOC entry 6941 (class 1259 OID 40050748)
-- Name: _hyper_1_273_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_273_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_273_chunk USING btree (event_time DESC);


--
-- TOC entry 6942 (class 1259 OID 40050749)
-- Name: _hyper_1_273_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_273_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_273_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6943 (class 1259 OID 40050750)
-- Name: _hyper_1_273_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_273_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_273_chunk USING gist ("position");


--
-- TOC entry 6947 (class 1259 OID 41383284)
-- Name: _hyper_1_276_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_276_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_276_chunk USING btree (event_time DESC);


--
-- TOC entry 6948 (class 1259 OID 41383285)
-- Name: _hyper_1_276_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_276_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_276_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6949 (class 1259 OID 41383286)
-- Name: _hyper_1_276_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_276_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_276_chunk USING gist ("position");


--
-- TOC entry 6404 (class 1259 OID 67011)
-- Name: _hyper_1_27_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_27_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_27_chunk USING btree (event_time DESC);


--
-- TOC entry 6405 (class 1259 OID 67012)
-- Name: _hyper_1_27_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_27_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_27_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6406 (class 1259 OID 67013)
-- Name: _hyper_1_27_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_27_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_27_chunk USING gist ("position");


--
-- TOC entry 6954 (class 1259 OID 44240097)
-- Name: _hyper_1_280_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_280_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_280_chunk USING btree (event_time DESC);


--
-- TOC entry 6955 (class 1259 OID 44240098)
-- Name: _hyper_1_280_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_280_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_280_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6956 (class 1259 OID 44240099)
-- Name: _hyper_1_280_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_280_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_280_chunk USING gist ("position");


--
-- TOC entry 6960 (class 1259 OID 45689983)
-- Name: _hyper_1_283_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_283_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_283_chunk USING btree (event_time DESC);


--
-- TOC entry 6961 (class 1259 OID 45689984)
-- Name: _hyper_1_283_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_283_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_283_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6962 (class 1259 OID 45689985)
-- Name: _hyper_1_283_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_283_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_283_chunk USING gist ("position");


--
-- TOC entry 6415 (class 1259 OID 67588)
-- Name: _hyper_1_31_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_31_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_31_chunk USING btree (event_time DESC);


--
-- TOC entry 6416 (class 1259 OID 67589)
-- Name: _hyper_1_31_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_31_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_31_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6417 (class 1259 OID 67590)
-- Name: _hyper_1_31_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_31_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_31_chunk USING gist ("position");


--
-- TOC entry 6424 (class 1259 OID 76859)
-- Name: _hyper_1_33_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_33_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_33_chunk USING btree (event_time DESC);


--
-- TOC entry 6425 (class 1259 OID 76860)
-- Name: _hyper_1_33_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_33_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_33_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6426 (class 1259 OID 76861)
-- Name: _hyper_1_33_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_33_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_33_chunk USING gist ("position");


--
-- TOC entry 6429 (class 1259 OID 123159)
-- Name: _hyper_1_35_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_35_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_35_chunk USING btree (event_time DESC);


--
-- TOC entry 6430 (class 1259 OID 123160)
-- Name: _hyper_1_35_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_35_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_35_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6431 (class 1259 OID 123161)
-- Name: _hyper_1_35_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_35_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_35_chunk USING gist ("position");


--
-- TOC entry 6434 (class 1259 OID 123533)
-- Name: _hyper_1_37_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_37_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_37_chunk USING btree (event_time DESC);


--
-- TOC entry 6435 (class 1259 OID 123534)
-- Name: _hyper_1_37_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_37_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_37_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6436 (class 1259 OID 123535)
-- Name: _hyper_1_37_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_37_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_37_chunk USING gist ("position");


--
-- TOC entry 6440 (class 1259 OID 123919)
-- Name: _hyper_1_39_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_39_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_39_chunk USING btree (event_time DESC);


--
-- TOC entry 6441 (class 1259 OID 123920)
-- Name: _hyper_1_39_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_39_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_39_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6442 (class 1259 OID 123921)
-- Name: _hyper_1_39_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_39_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_39_chunk USING gist ("position");


--
-- TOC entry 6445 (class 1259 OID 126261)
-- Name: _hyper_1_41_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_41_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_41_chunk USING btree (event_time DESC);


--
-- TOC entry 6446 (class 1259 OID 126262)
-- Name: _hyper_1_41_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_41_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_41_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6447 (class 1259 OID 126263)
-- Name: _hyper_1_41_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_41_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_41_chunk USING gist ("position");


--
-- TOC entry 6451 (class 1259 OID 126664)
-- Name: _hyper_1_43_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_43_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_43_chunk USING btree (event_time DESC);


--
-- TOC entry 6452 (class 1259 OID 126665)
-- Name: _hyper_1_43_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_43_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_43_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6453 (class 1259 OID 126666)
-- Name: _hyper_1_43_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_43_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_43_chunk USING gist ("position");


--
-- TOC entry 6456 (class 1259 OID 127035)
-- Name: _hyper_1_45_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_45_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_45_chunk USING btree (event_time DESC);


--
-- TOC entry 6457 (class 1259 OID 127036)
-- Name: _hyper_1_45_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_45_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_45_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6458 (class 1259 OID 127037)
-- Name: _hyper_1_45_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_45_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_45_chunk USING gist ("position");


--
-- TOC entry 6466 (class 1259 OID 133023)
-- Name: _hyper_1_47_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_47_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_47_chunk USING btree (event_time DESC);


--
-- TOC entry 6467 (class 1259 OID 133024)
-- Name: _hyper_1_47_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_47_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_47_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6468 (class 1259 OID 133025)
-- Name: _hyper_1_47_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_47_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_47_chunk USING gist ("position");


--
-- TOC entry 6472 (class 1259 OID 137239)
-- Name: _hyper_1_49_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_49_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_49_chunk USING btree (event_time DESC);


--
-- TOC entry 6473 (class 1259 OID 137240)
-- Name: _hyper_1_49_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_49_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_49_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6474 (class 1259 OID 137241)
-- Name: _hyper_1_49_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_49_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_49_chunk USING gist ("position");


--
-- TOC entry 6483 (class 1259 OID 141192)
-- Name: _hyper_1_53_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_53_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_53_chunk USING btree (event_time DESC);


--
-- TOC entry 6484 (class 1259 OID 141193)
-- Name: _hyper_1_53_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_53_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_53_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6485 (class 1259 OID 141194)
-- Name: _hyper_1_53_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_53_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_53_chunk USING gist ("position");


--
-- TOC entry 6490 (class 1259 OID 145611)
-- Name: _hyper_1_55_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_55_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_55_chunk USING btree (event_time DESC);


--
-- TOC entry 6491 (class 1259 OID 145612)
-- Name: _hyper_1_55_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_55_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_55_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6492 (class 1259 OID 145613)
-- Name: _hyper_1_55_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_55_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_55_chunk USING gist ("position");


--
-- TOC entry 6495 (class 1259 OID 150391)
-- Name: _hyper_1_57_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_57_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_57_chunk USING btree (event_time DESC);


--
-- TOC entry 6496 (class 1259 OID 150392)
-- Name: _hyper_1_57_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_57_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_57_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6497 (class 1259 OID 150393)
-- Name: _hyper_1_57_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_57_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_57_chunk USING gist ("position");


--
-- TOC entry 6500 (class 1259 OID 156239)
-- Name: _hyper_1_59_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_59_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_59_chunk USING btree (event_time DESC);


--
-- TOC entry 6501 (class 1259 OID 156240)
-- Name: _hyper_1_59_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_59_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_59_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6502 (class 1259 OID 156241)
-- Name: _hyper_1_59_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_59_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_59_chunk USING gist ("position");


--
-- TOC entry 6348 (class 1259 OID 24966)
-- Name: _hyper_1_5_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_5_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_5_chunk USING btree (event_time DESC);


--
-- TOC entry 6349 (class 1259 OID 24967)
-- Name: _hyper_1_5_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_5_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_5_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6350 (class 1259 OID 24968)
-- Name: _hyper_1_5_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_5_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_5_chunk USING gist ("position");


--
-- TOC entry 6505 (class 1259 OID 162851)
-- Name: _hyper_1_61_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_61_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_61_chunk USING btree (event_time DESC);


--
-- TOC entry 6506 (class 1259 OID 162852)
-- Name: _hyper_1_61_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_61_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_61_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6507 (class 1259 OID 162853)
-- Name: _hyper_1_61_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_61_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_61_chunk USING gist ("position");


--
-- TOC entry 6510 (class 1259 OID 170237)
-- Name: _hyper_1_63_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_63_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_63_chunk USING btree (event_time DESC);


--
-- TOC entry 6511 (class 1259 OID 170238)
-- Name: _hyper_1_63_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_63_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_63_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6512 (class 1259 OID 170239)
-- Name: _hyper_1_63_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_63_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_63_chunk USING gist ("position");


--
-- TOC entry 6515 (class 1259 OID 176692)
-- Name: _hyper_1_65_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_65_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_65_chunk USING btree (event_time DESC);


--
-- TOC entry 6516 (class 1259 OID 176693)
-- Name: _hyper_1_65_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_65_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_65_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6517 (class 1259 OID 176694)
-- Name: _hyper_1_65_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_65_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_65_chunk USING gist ("position");


--
-- TOC entry 6541 (class 1259 OID 5625474)
-- Name: _hyper_1_87_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_87_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_87_chunk USING btree (event_time DESC);


--
-- TOC entry 6542 (class 1259 OID 5625475)
-- Name: _hyper_1_87_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_87_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_87_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6543 (class 1259 OID 5625476)
-- Name: _hyper_1_87_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_87_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_87_chunk USING gist ("position");


--
-- TOC entry 6547 (class 1259 OID 5912408)
-- Name: _hyper_1_90_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_90_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_90_chunk USING btree (event_time DESC);


--
-- TOC entry 6548 (class 1259 OID 5912409)
-- Name: _hyper_1_90_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_90_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_90_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6549 (class 1259 OID 5912410)
-- Name: _hyper_1_90_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_90_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_90_chunk USING gist ("position");


--
-- TOC entry 6558 (class 1259 OID 6212219)
-- Name: _hyper_1_94_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_94_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_94_chunk USING btree (event_time DESC);


--
-- TOC entry 6559 (class 1259 OID 6212220)
-- Name: _hyper_1_94_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_94_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_94_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6560 (class 1259 OID 6212221)
-- Name: _hyper_1_94_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_94_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_94_chunk USING gist ("position");


--
-- TOC entry 6567 (class 1259 OID 6216978)
-- Name: _hyper_1_97_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_97_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_97_chunk USING btree (event_time DESC);


--
-- TOC entry 6568 (class 1259 OID 6216979)
-- Name: _hyper_1_97_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_97_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_97_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6569 (class 1259 OID 6216980)
-- Name: _hyper_1_97_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_97_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_97_chunk USING gist ("position");


--
-- TOC entry 6359 (class 1259 OID 25489)
-- Name: _hyper_1_9_chunk_pos_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_9_chunk_pos_reports_event_time_idx ON _timescaledb_internal._hyper_1_9_chunk USING btree (event_time DESC);


--
-- TOC entry 6360 (class 1259 OID 25490)
-- Name: _hyper_1_9_chunk_pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_9_chunk_pos_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_1_9_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6361 (class 1259 OID 25491)
-- Name: _hyper_1_9_chunk_pos_reports_position_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_1_9_chunk_pos_reports_position_idx ON _timescaledb_internal._hyper_1_9_chunk USING gist ("position");


--
-- TOC entry 6576 (class 1259 OID 6521435)
-- Name: _hyper_2_101_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_101_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_101_chunk USING btree (event_time DESC);


--
-- TOC entry 6577 (class 1259 OID 6521436)
-- Name: _hyper_2_101_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_101_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_101_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6362 (class 1259 OID 25616)
-- Name: _hyper_2_10_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_10_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_10_chunk USING btree (event_time DESC);


--
-- TOC entry 6363 (class 1259 OID 25617)
-- Name: _hyper_2_10_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_10_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_10_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6367 (class 1259 OID 25892)
-- Name: _hyper_2_12_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_12_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_12_chunk USING btree (event_time DESC);


--
-- TOC entry 6368 (class 1259 OID 25893)
-- Name: _hyper_2_12_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_12_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_12_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6672 (class 1259 OID 6822291)
-- Name: _hyper_2_149_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_149_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_149_chunk USING btree (event_time DESC);


--
-- TOC entry 6673 (class 1259 OID 6822292)
-- Name: _hyper_2_149_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_149_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_149_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6372 (class 1259 OID 36446)
-- Name: _hyper_2_14_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_14_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_14_chunk USING btree (event_time DESC);


--
-- TOC entry 6373 (class 1259 OID 36447)
-- Name: _hyper_2_14_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_14_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_14_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6678 (class 1259 OID 7148785)
-- Name: _hyper_2_152_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_152_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_152_chunk USING btree (event_time DESC);


--
-- TOC entry 6679 (class 1259 OID 7148786)
-- Name: _hyper_2_152_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_152_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_152_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6684 (class 1259 OID 7479161)
-- Name: _hyper_2_155_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_155_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_155_chunk USING btree (event_time DESC);


--
-- TOC entry 6685 (class 1259 OID 7479162)
-- Name: _hyper_2_155_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_155_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_155_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6690 (class 1259 OID 7839735)
-- Name: _hyper_2_158_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_158_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_158_chunk USING btree (event_time DESC);


--
-- TOC entry 6691 (class 1259 OID 7839736)
-- Name: _hyper_2_158_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_158_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_158_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6694 (class 1259 OID 8547898)
-- Name: _hyper_2_161_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_161_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_161_chunk USING btree (event_time DESC);


--
-- TOC entry 6695 (class 1259 OID 8547899)
-- Name: _hyper_2_161_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_161_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_161_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6703 (class 1259 OID 8980687)
-- Name: _hyper_2_165_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_165_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_165_chunk USING btree (event_time DESC);


--
-- TOC entry 6704 (class 1259 OID 8980688)
-- Name: _hyper_2_165_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_165_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_165_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6709 (class 1259 OID 9267758)
-- Name: _hyper_2_168_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_168_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_168_chunk USING btree (event_time DESC);


--
-- TOC entry 6710 (class 1259 OID 9267759)
-- Name: _hyper_2_168_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_168_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_168_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6377 (class 1259 OID 36827)
-- Name: _hyper_2_16_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_16_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_16_chunk USING btree (event_time DESC);


--
-- TOC entry 6378 (class 1259 OID 36828)
-- Name: _hyper_2_16_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_16_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_16_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6721 (class 1259 OID 9736645)
-- Name: _hyper_2_173_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_173_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_173_chunk USING btree (event_time DESC);


--
-- TOC entry 6722 (class 1259 OID 9736646)
-- Name: _hyper_2_173_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_173_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_173_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6727 (class 1259 OID 10228159)
-- Name: _hyper_2_176_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_176_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_176_chunk USING btree (event_time DESC);


--
-- TOC entry 6728 (class 1259 OID 10228160)
-- Name: _hyper_2_176_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_176_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_176_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6733 (class 1259 OID 10732097)
-- Name: _hyper_2_179_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_179_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_179_chunk USING btree (event_time DESC);


--
-- TOC entry 6734 (class 1259 OID 10732098)
-- Name: _hyper_2_179_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_179_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_179_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6739 (class 1259 OID 11235477)
-- Name: _hyper_2_182_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_182_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_182_chunk USING btree (event_time DESC);


--
-- TOC entry 6740 (class 1259 OID 11235478)
-- Name: _hyper_2_182_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_182_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_182_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6745 (class 1259 OID 11758330)
-- Name: _hyper_2_185_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_185_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_185_chunk USING btree (event_time DESC);


--
-- TOC entry 6746 (class 1259 OID 11758331)
-- Name: _hyper_2_185_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_185_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_185_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6751 (class 1259 OID 12285422)
-- Name: _hyper_2_188_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_188_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_188_chunk USING btree (event_time DESC);


--
-- TOC entry 6752 (class 1259 OID 12285423)
-- Name: _hyper_2_188_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_188_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_188_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6382 (class 1259 OID 37202)
-- Name: _hyper_2_18_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_18_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_18_chunk USING btree (event_time DESC);


--
-- TOC entry 6383 (class 1259 OID 37203)
-- Name: _hyper_2_18_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_18_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_18_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6757 (class 1259 OID 12492998)
-- Name: _hyper_2_191_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_191_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_191_chunk USING btree (event_time DESC);


--
-- TOC entry 6758 (class 1259 OID 12492999)
-- Name: _hyper_2_191_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_191_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_191_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6762 (class 1259 OID 12498866)
-- Name: _hyper_2_193_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_193_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_193_chunk USING btree (event_time DESC);


--
-- TOC entry 6763 (class 1259 OID 12498867)
-- Name: _hyper_2_193_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_193_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_193_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6768 (class 1259 OID 13022957)
-- Name: _hyper_2_196_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_196_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_196_chunk USING btree (event_time DESC);


--
-- TOC entry 6769 (class 1259 OID 13022958)
-- Name: _hyper_2_196_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_196_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_196_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6778 (class 1259 OID 14137190)
-- Name: _hyper_2_199_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_199_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_199_chunk USING btree (event_time DESC);


--
-- TOC entry 6779 (class 1259 OID 14137191)
-- Name: _hyper_2_199_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_199_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_199_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6790 (class 1259 OID 14694328)
-- Name: _hyper_2_204_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_204_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_204_chunk USING btree (event_time DESC);


--
-- TOC entry 6791 (class 1259 OID 14694329)
-- Name: _hyper_2_204_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_204_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_204_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6796 (class 1259 OID 15271018)
-- Name: _hyper_2_207_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_207_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_207_chunk USING btree (event_time DESC);


--
-- TOC entry 6797 (class 1259 OID 15271019)
-- Name: _hyper_2_207_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_207_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_207_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6387 (class 1259 OID 52102)
-- Name: _hyper_2_20_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_20_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_20_chunk USING btree (event_time DESC);


--
-- TOC entry 6388 (class 1259 OID 52103)
-- Name: _hyper_2_20_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_20_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_20_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6802 (class 1259 OID 15848156)
-- Name: _hyper_2_210_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_210_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_210_chunk USING btree (event_time DESC);


--
-- TOC entry 6803 (class 1259 OID 15848157)
-- Name: _hyper_2_210_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_210_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_210_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6808 (class 1259 OID 16429918)
-- Name: _hyper_2_213_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_213_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_213_chunk USING btree (event_time DESC);


--
-- TOC entry 6809 (class 1259 OID 16429919)
-- Name: _hyper_2_213_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_213_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_213_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6812 (class 1259 OID 16996369)
-- Name: _hyper_2_215_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_215_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_215_chunk USING btree (event_time DESC);


--
-- TOC entry 6813 (class 1259 OID 16996370)
-- Name: _hyper_2_215_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_215_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_215_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6824 (class 1259 OID 17552506)
-- Name: _hyper_2_219_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_219_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_219_chunk USING btree (event_time DESC);


--
-- TOC entry 6825 (class 1259 OID 17552507)
-- Name: _hyper_2_219_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_219_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_219_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6830 (class 1259 OID 18082005)
-- Name: _hyper_2_222_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_222_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_222_chunk USING btree (event_time DESC);


--
-- TOC entry 6831 (class 1259 OID 18082006)
-- Name: _hyper_2_222_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_222_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_222_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6838 (class 1259 OID 18797356)
-- Name: _hyper_2_225_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_225_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_225_chunk USING btree (event_time DESC);


--
-- TOC entry 6839 (class 1259 OID 18797357)
-- Name: _hyper_2_225_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_225_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_225_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6844 (class 1259 OID 20176741)
-- Name: _hyper_2_228_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_228_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_228_chunk USING btree (event_time DESC);


--
-- TOC entry 6845 (class 1259 OID 20176742)
-- Name: _hyper_2_228_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_228_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_228_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6392 (class 1259 OID 52565)
-- Name: _hyper_2_22_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_22_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_22_chunk USING btree (event_time DESC);


--
-- TOC entry 6393 (class 1259 OID 52566)
-- Name: _hyper_2_22_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_22_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_22_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6850 (class 1259 OID 21597035)
-- Name: _hyper_2_231_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_231_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_231_chunk USING btree (event_time DESC);


--
-- TOC entry 6851 (class 1259 OID 21597036)
-- Name: _hyper_2_231_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_231_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_231_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6862 (class 1259 OID 23006094)
-- Name: _hyper_2_236_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_236_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_236_chunk USING btree (event_time DESC);


--
-- TOC entry 6863 (class 1259 OID 23006095)
-- Name: _hyper_2_236_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_236_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_236_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6873 (class 1259 OID 25832608)
-- Name: _hyper_2_240_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_240_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_240_chunk USING btree (event_time DESC);


--
-- TOC entry 6874 (class 1259 OID 25832609)
-- Name: _hyper_2_240_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_240_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_240_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6879 (class 1259 OID 27178910)
-- Name: _hyper_2_243_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_243_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_243_chunk USING btree (event_time DESC);


--
-- TOC entry 6880 (class 1259 OID 27178911)
-- Name: _hyper_2_243_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_243_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_243_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6885 (class 1259 OID 28545457)
-- Name: _hyper_2_246_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_246_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_246_chunk USING btree (event_time DESC);


--
-- TOC entry 6886 (class 1259 OID 28545458)
-- Name: _hyper_2_246_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_246_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_246_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6891 (class 1259 OID 29876911)
-- Name: _hyper_2_249_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_249_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_249_chunk USING btree (event_time DESC);


--
-- TOC entry 6892 (class 1259 OID 29876912)
-- Name: _hyper_2_249_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_249_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_249_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6397 (class 1259 OID 52937)
-- Name: _hyper_2_24_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_24_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_24_chunk USING btree (event_time DESC);


--
-- TOC entry 6398 (class 1259 OID 52938)
-- Name: _hyper_2_24_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_24_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_24_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6897 (class 1259 OID 31351430)
-- Name: _hyper_2_252_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_252_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_252_chunk USING btree (event_time DESC);


--
-- TOC entry 6898 (class 1259 OID 31351431)
-- Name: _hyper_2_252_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_252_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_252_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6900 (class 1259 OID 32687030)
-- Name: _hyper_2_254_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_254_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_254_chunk USING btree (event_time DESC);


--
-- TOC entry 6901 (class 1259 OID 32687031)
-- Name: _hyper_2_254_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_254_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_254_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6909 (class 1259 OID 34051018)
-- Name: _hyper_2_258_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_258_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_258_chunk USING btree (event_time DESC);


--
-- TOC entry 6910 (class 1259 OID 34051019)
-- Name: _hyper_2_258_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_258_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_258_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6915 (class 1259 OID 35482489)
-- Name: _hyper_2_261_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_261_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_261_chunk USING btree (event_time DESC);


--
-- TOC entry 6916 (class 1259 OID 35482490)
-- Name: _hyper_2_261_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_261_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_261_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6920 (class 1259 OID 35494479)
-- Name: _hyper_2_263_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_263_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_263_chunk USING btree (event_time DESC);


--
-- TOC entry 6921 (class 1259 OID 35494480)
-- Name: _hyper_2_263_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_263_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_263_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6932 (class 1259 OID 36945290)
-- Name: _hyper_2_268_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_268_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_268_chunk USING btree (event_time DESC);


--
-- TOC entry 6933 (class 1259 OID 36945291)
-- Name: _hyper_2_268_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_268_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_268_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6402 (class 1259 OID 66601)
-- Name: _hyper_2_26_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_26_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_26_chunk USING btree (event_time DESC);


--
-- TOC entry 6403 (class 1259 OID 66602)
-- Name: _hyper_2_26_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_26_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_26_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6938 (class 1259 OID 38434311)
-- Name: _hyper_2_271_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_271_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_271_chunk USING btree (event_time DESC);


--
-- TOC entry 6939 (class 1259 OID 38434312)
-- Name: _hyper_2_271_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_271_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_271_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6944 (class 1259 OID 40050760)
-- Name: _hyper_2_274_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_274_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_274_chunk USING btree (event_time DESC);


--
-- TOC entry 6945 (class 1259 OID 40050761)
-- Name: _hyper_2_274_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_274_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_274_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6950 (class 1259 OID 41383296)
-- Name: _hyper_2_277_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_277_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_277_chunk USING btree (event_time DESC);


--
-- TOC entry 6951 (class 1259 OID 41383297)
-- Name: _hyper_2_277_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_277_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_277_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6957 (class 1259 OID 44240109)
-- Name: _hyper_2_281_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_281_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_281_chunk USING btree (event_time DESC);


--
-- TOC entry 6958 (class 1259 OID 44240110)
-- Name: _hyper_2_281_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_281_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_281_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6963 (class 1259 OID 45689995)
-- Name: _hyper_2_284_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_284_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_284_chunk USING btree (event_time DESC);


--
-- TOC entry 6964 (class 1259 OID 45689996)
-- Name: _hyper_2_284_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_284_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_284_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6407 (class 1259 OID 67022)
-- Name: _hyper_2_28_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_28_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_28_chunk USING btree (event_time DESC);


--
-- TOC entry 6408 (class 1259 OID 67023)
-- Name: _hyper_2_28_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_28_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_28_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6334 (class 1259 OID 24684)
-- Name: _hyper_2_2_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_2_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_2_chunk USING btree (event_time DESC);


--
-- TOC entry 6335 (class 1259 OID 24685)
-- Name: _hyper_2_2_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_2_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_2_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6418 (class 1259 OID 67599)
-- Name: _hyper_2_32_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_32_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_32_chunk USING btree (event_time DESC);


--
-- TOC entry 6419 (class 1259 OID 67600)
-- Name: _hyper_2_32_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_32_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_32_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6427 (class 1259 OID 76870)
-- Name: _hyper_2_34_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_34_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_34_chunk USING btree (event_time DESC);


--
-- TOC entry 6428 (class 1259 OID 76871)
-- Name: _hyper_2_34_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_34_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_34_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6432 (class 1259 OID 123170)
-- Name: _hyper_2_36_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_36_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_36_chunk USING btree (event_time DESC);


--
-- TOC entry 6433 (class 1259 OID 123171)
-- Name: _hyper_2_36_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_36_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_36_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6437 (class 1259 OID 123544)
-- Name: _hyper_2_38_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_38_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_38_chunk USING btree (event_time DESC);


--
-- TOC entry 6438 (class 1259 OID 123545)
-- Name: _hyper_2_38_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_38_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_38_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6443 (class 1259 OID 123930)
-- Name: _hyper_2_40_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_40_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_40_chunk USING btree (event_time DESC);


--
-- TOC entry 6444 (class 1259 OID 123931)
-- Name: _hyper_2_40_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_40_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_40_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6448 (class 1259 OID 126272)
-- Name: _hyper_2_42_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_42_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_42_chunk USING btree (event_time DESC);


--
-- TOC entry 6449 (class 1259 OID 126273)
-- Name: _hyper_2_42_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_42_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_42_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6454 (class 1259 OID 126675)
-- Name: _hyper_2_44_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_44_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_44_chunk USING btree (event_time DESC);


--
-- TOC entry 6455 (class 1259 OID 126676)
-- Name: _hyper_2_44_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_44_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_44_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6459 (class 1259 OID 127046)
-- Name: _hyper_2_46_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_46_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_46_chunk USING btree (event_time DESC);


--
-- TOC entry 6460 (class 1259 OID 127047)
-- Name: _hyper_2_46_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_46_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_46_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6469 (class 1259 OID 133035)
-- Name: _hyper_2_48_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_48_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_48_chunk USING btree (event_time DESC);


--
-- TOC entry 6470 (class 1259 OID 133036)
-- Name: _hyper_2_48_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_48_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_48_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6475 (class 1259 OID 137251)
-- Name: _hyper_2_50_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_50_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_50_chunk USING btree (event_time DESC);


--
-- TOC entry 6476 (class 1259 OID 137252)
-- Name: _hyper_2_50_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_50_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_50_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6486 (class 1259 OID 141204)
-- Name: _hyper_2_54_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_54_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_54_chunk USING btree (event_time DESC);


--
-- TOC entry 6487 (class 1259 OID 141205)
-- Name: _hyper_2_54_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_54_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_54_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6493 (class 1259 OID 145623)
-- Name: _hyper_2_56_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_56_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_56_chunk USING btree (event_time DESC);


--
-- TOC entry 6494 (class 1259 OID 145624)
-- Name: _hyper_2_56_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_56_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_56_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6498 (class 1259 OID 150403)
-- Name: _hyper_2_58_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_58_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_58_chunk USING btree (event_time DESC);


--
-- TOC entry 6499 (class 1259 OID 150404)
-- Name: _hyper_2_58_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_58_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_58_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6503 (class 1259 OID 156251)
-- Name: _hyper_2_60_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_60_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_60_chunk USING btree (event_time DESC);


--
-- TOC entry 6504 (class 1259 OID 156252)
-- Name: _hyper_2_60_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_60_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_60_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6508 (class 1259 OID 162863)
-- Name: _hyper_2_62_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_62_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_62_chunk USING btree (event_time DESC);


--
-- TOC entry 6509 (class 1259 OID 162864)
-- Name: _hyper_2_62_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_62_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_62_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6513 (class 1259 OID 170249)
-- Name: _hyper_2_64_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_64_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_64_chunk USING btree (event_time DESC);


--
-- TOC entry 6514 (class 1259 OID 170250)
-- Name: _hyper_2_64_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_64_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_64_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6518 (class 1259 OID 176704)
-- Name: _hyper_2_66_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_66_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_66_chunk USING btree (event_time DESC);


--
-- TOC entry 6519 (class 1259 OID 176705)
-- Name: _hyper_2_66_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_66_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_66_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6354 (class 1259 OID 25294)
-- Name: _hyper_2_7_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_7_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_7_chunk USING btree (event_time DESC);


--
-- TOC entry 6355 (class 1259 OID 25295)
-- Name: _hyper_2_7_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_7_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_7_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6544 (class 1259 OID 5625486)
-- Name: _hyper_2_88_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_88_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_88_chunk USING btree (event_time DESC);


--
-- TOC entry 6545 (class 1259 OID 5625487)
-- Name: _hyper_2_88_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_88_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_88_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6550 (class 1259 OID 5912420)
-- Name: _hyper_2_91_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_91_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_91_chunk USING btree (event_time DESC);


--
-- TOC entry 6551 (class 1259 OID 5912421)
-- Name: _hyper_2_91_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_91_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_91_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6556 (class 1259 OID 6212209)
-- Name: _hyper_2_93_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_93_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_93_chunk USING btree (event_time DESC);


--
-- TOC entry 6557 (class 1259 OID 6212210)
-- Name: _hyper_2_93_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_93_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_93_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6570 (class 1259 OID 6216990)
-- Name: _hyper_2_98_chunk_voy_reports_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_98_chunk_voy_reports_event_time_idx ON _timescaledb_internal._hyper_2_98_chunk USING btree (event_time DESC);


--
-- TOC entry 6571 (class 1259 OID 6216991)
-- Name: _hyper_2_98_chunk_voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_2_98_chunk_voy_reports_mmsi_event_time_idx ON _timescaledb_internal._hyper_2_98_chunk USING btree (mmsi, event_time DESC);


--
-- TOC entry 6663 (class 1259 OID 6821067)
-- Name: _hyper_4_146_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_146_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_146_chunk USING btree (bucket DESC);


--
-- TOC entry 6664 (class 1259 OID 6821068)
-- Name: _hyper_4_146_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_146_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_146_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6665 (class 1259 OID 6821069)
-- Name: _hyper_4_146_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_146_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_146_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6666 (class 1259 OID 6821077)
-- Name: _hyper_4_147_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_147_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_147_chunk USING btree (bucket DESC);


--
-- TOC entry 6667 (class 1259 OID 6821078)
-- Name: _hyper_4_147_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_147_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_147_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6668 (class 1259 OID 6821079)
-- Name: _hyper_4_147_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_147_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_147_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6711 (class 1259 OID 9268405)
-- Name: _hyper_4_169_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_169_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_169_chunk USING btree (bucket DESC);


--
-- TOC entry 6712 (class 1259 OID 9268406)
-- Name: _hyper_4_169_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_169_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_169_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6713 (class 1259 OID 9268407)
-- Name: _hyper_4_169_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_169_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_169_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6780 (class 1259 OID 14138722)
-- Name: _hyper_4_200_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_200_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_200_chunk USING btree (bucket DESC);


--
-- TOC entry 6781 (class 1259 OID 14138723)
-- Name: _hyper_4_200_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_200_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_200_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6782 (class 1259 OID 14138724)
-- Name: _hyper_4_200_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_200_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_200_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6852 (class 1259 OID 21597736)
-- Name: _hyper_4_232_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_232_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_232_chunk USING btree (bucket DESC);


--
-- TOC entry 6853 (class 1259 OID 21597737)
-- Name: _hyper_4_232_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_232_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_232_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6854 (class 1259 OID 21597738)
-- Name: _hyper_4_232_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_232_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_232_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6922 (class 1259 OID 35495214)
-- Name: _hyper_4_264_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_264_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_264_chunk USING btree (bucket DESC);


--
-- TOC entry 6923 (class 1259 OID 35495215)
-- Name: _hyper_4_264_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_264_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_264_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6924 (class 1259 OID 35495216)
-- Name: _hyper_4_264_chunk__materialized_hypertable_4_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_264_chunk__materialized_hypertable_4_routing_key_bucke ON _timescaledb_internal._hyper_4_264_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6409 (class 1259 OID 67225)
-- Name: _hyper_4_29_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_29_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_29_chunk USING btree (bucket DESC);


--
-- TOC entry 6410 (class 1259 OID 67226)
-- Name: _hyper_4_29_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_29_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_29_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6411 (class 1259 OID 67227)
-- Name: _hyper_4_29_chunk__materialized_hypertable_4_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_29_chunk__materialized_hypertable_4_routing_key_bucket ON _timescaledb_internal._hyper_4_29_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6345 (class 1259 OID 24926)
-- Name: _hyper_4_4_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_4_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_4_chunk USING btree (bucket DESC);


--
-- TOC entry 6346 (class 1259 OID 24927)
-- Name: _hyper_4_4_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_4_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_4_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6347 (class 1259 OID 24928)
-- Name: _hyper_4_4_chunk__materialized_hypertable_4_routing_key_bucket_; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_4_chunk__materialized_hypertable_4_routing_key_bucket_ ON _timescaledb_internal._hyper_4_4_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6477 (class 1259 OID 137443)
-- Name: _hyper_4_51_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_51_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_51_chunk USING btree (bucket DESC);


--
-- TOC entry 6478 (class 1259 OID 137444)
-- Name: _hyper_4_51_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_51_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_51_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6479 (class 1259 OID 137445)
-- Name: _hyper_4_51_chunk__materialized_hypertable_4_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_51_chunk__materialized_hypertable_4_routing_key_bucket ON _timescaledb_internal._hyper_4_51_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6351 (class 1259 OID 25115)
-- Name: _hyper_4_6_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_6_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_6_chunk USING btree (bucket DESC);


--
-- TOC entry 6352 (class 1259 OID 25116)
-- Name: _hyper_4_6_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_6_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_6_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6353 (class 1259 OID 25117)
-- Name: _hyper_4_6_chunk__materialized_hypertable_4_routing_key_bucket_; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_6_chunk__materialized_hypertable_4_routing_key_bucket_ ON _timescaledb_internal._hyper_4_6_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6561 (class 1259 OID 6212407)
-- Name: _hyper_4_95_chunk__materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_95_chunk__materialized_hypertable_4_bucket_idx ON _timescaledb_internal._hyper_4_95_chunk USING btree (bucket DESC);


--
-- TOC entry 6562 (class 1259 OID 6212408)
-- Name: _hyper_4_95_chunk__materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_95_chunk__materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._hyper_4_95_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6563 (class 1259 OID 6212409)
-- Name: _hyper_4_95_chunk__materialized_hypertable_4_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_4_95_chunk__materialized_hypertable_4_routing_key_bucket ON _timescaledb_internal._hyper_4_95_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6714 (class 1259 OID 9269642)
-- Name: _hyper_5_170_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_170_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_170_chunk USING btree (bucket DESC);


--
-- TOC entry 6715 (class 1259 OID 9269643)
-- Name: _hyper_5_170_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_170_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_170_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6716 (class 1259 OID 9269644)
-- Name: _hyper_5_170_chunk__materialized_hypertable_5_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_170_chunk__materialized_hypertable_5_routing_key_bucke ON _timescaledb_internal._hyper_5_170_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6783 (class 1259 OID 14139331)
-- Name: _hyper_5_201_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_201_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_201_chunk USING btree (bucket DESC);


--
-- TOC entry 6784 (class 1259 OID 14139332)
-- Name: _hyper_5_201_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_201_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_201_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6785 (class 1259 OID 14139333)
-- Name: _hyper_5_201_chunk__materialized_hypertable_5_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_201_chunk__materialized_hypertable_5_routing_key_bucke ON _timescaledb_internal._hyper_5_201_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6855 (class 1259 OID 21599806)
-- Name: _hyper_5_233_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_233_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_233_chunk USING btree (bucket DESC);


--
-- TOC entry 6856 (class 1259 OID 21599807)
-- Name: _hyper_5_233_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_233_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_233_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6857 (class 1259 OID 21599808)
-- Name: _hyper_5_233_chunk__materialized_hypertable_5_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_233_chunk__materialized_hypertable_5_routing_key_bucke ON _timescaledb_internal._hyper_5_233_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6925 (class 1259 OID 35495903)
-- Name: _hyper_5_265_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_265_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_265_chunk USING btree (bucket DESC);


--
-- TOC entry 6926 (class 1259 OID 35495904)
-- Name: _hyper_5_265_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_265_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_265_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6927 (class 1259 OID 35495905)
-- Name: _hyper_5_265_chunk__materialized_hypertable_5_routing_key_bucke; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_265_chunk__materialized_hypertable_5_routing_key_bucke ON _timescaledb_internal._hyper_5_265_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6412 (class 1259 OID 67345)
-- Name: _hyper_5_30_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_30_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_30_chunk USING btree (bucket DESC);


--
-- TOC entry 6413 (class 1259 OID 67346)
-- Name: _hyper_5_30_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_30_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_30_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6414 (class 1259 OID 67347)
-- Name: _hyper_5_30_chunk__materialized_hypertable_5_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_30_chunk__materialized_hypertable_5_routing_key_bucket ON _timescaledb_internal._hyper_5_30_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6342 (class 1259 OID 24916)
-- Name: _hyper_5_3_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_3_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_3_chunk USING btree (bucket DESC);


--
-- TOC entry 6343 (class 1259 OID 24917)
-- Name: _hyper_5_3_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_3_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_3_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6344 (class 1259 OID 24918)
-- Name: _hyper_5_3_chunk__materialized_hypertable_5_routing_key_bucket_; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_3_chunk__materialized_hypertable_5_routing_key_bucket_ ON _timescaledb_internal._hyper_5_3_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6480 (class 1259 OID 137682)
-- Name: _hyper_5_52_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_52_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_52_chunk USING btree (bucket DESC);


--
-- TOC entry 6481 (class 1259 OID 137683)
-- Name: _hyper_5_52_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_52_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_52_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6482 (class 1259 OID 137684)
-- Name: _hyper_5_52_chunk__materialized_hypertable_5_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_52_chunk__materialized_hypertable_5_routing_key_bucket ON _timescaledb_internal._hyper_5_52_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6356 (class 1259 OID 25330)
-- Name: _hyper_5_8_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_8_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_8_chunk USING btree (bucket DESC);


--
-- TOC entry 6357 (class 1259 OID 25331)
-- Name: _hyper_5_8_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_8_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_8_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6358 (class 1259 OID 25332)
-- Name: _hyper_5_8_chunk__materialized_hypertable_5_routing_key_bucket_; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_8_chunk__materialized_hypertable_5_routing_key_bucket_ ON _timescaledb_internal._hyper_5_8_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6564 (class 1259 OID 6212571)
-- Name: _hyper_5_96_chunk__materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_96_chunk__materialized_hypertable_5_bucket_idx ON _timescaledb_internal._hyper_5_96_chunk USING btree (bucket DESC);


--
-- TOC entry 6565 (class 1259 OID 6212572)
-- Name: _hyper_5_96_chunk__materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_96_chunk__materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._hyper_5_96_chunk USING btree (mmsi, bucket DESC);


--
-- TOC entry 6566 (class 1259 OID 6212573)
-- Name: _hyper_5_96_chunk__materialized_hypertable_5_routing_key_bucket; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _hyper_5_96_chunk__materialized_hypertable_5_routing_key_bucket ON _timescaledb_internal._hyper_5_96_chunk USING btree (routing_key, bucket DESC);


--
-- TOC entry 6336 (class 1259 OID 24861)
-- Name: _materialized_hypertable_4_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_4_bucket_idx ON _timescaledb_internal._materialized_hypertable_4 USING btree (bucket DESC);


--
-- TOC entry 6337 (class 1259 OID 24862)
-- Name: _materialized_hypertable_4_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_4_mmsi_bucket_idx ON _timescaledb_internal._materialized_hypertable_4 USING btree (mmsi, bucket DESC);


--
-- TOC entry 6338 (class 1259 OID 24863)
-- Name: _materialized_hypertable_4_routing_key_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_4_routing_key_bucket_idx ON _timescaledb_internal._materialized_hypertable_4 USING btree (routing_key, bucket DESC);


--
-- TOC entry 6339 (class 1259 OID 24889)
-- Name: _materialized_hypertable_5_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_5_bucket_idx ON _timescaledb_internal._materialized_hypertable_5 USING btree (bucket DESC);


--
-- TOC entry 6340 (class 1259 OID 24890)
-- Name: _materialized_hypertable_5_mmsi_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_5_mmsi_bucket_idx ON _timescaledb_internal._materialized_hypertable_5 USING btree (mmsi, bucket DESC);


--
-- TOC entry 6341 (class 1259 OID 24891)
-- Name: _materialized_hypertable_5_routing_key_bucket_idx; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX _materialized_hypertable_5_routing_key_bucket_idx ON _timescaledb_internal._materialized_hypertable_5 USING btree (routing_key, bucket DESC);


--
-- TOC entry 6578 (class 1259 OID 6522667)
-- Name: compress_hyper_6_102_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_102_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_102_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6674 (class 1259 OID 6823634)
-- Name: compress_hyper_6_150_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_150_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_150_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6680 (class 1259 OID 7150920)
-- Name: compress_hyper_6_153_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_153_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_153_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6686 (class 1259 OID 7481166)
-- Name: compress_hyper_6_156_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_156_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_156_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6692 (class 1259 OID 7841792)
-- Name: compress_hyper_6_159_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_159_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_159_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6693 (class 1259 OID 8180524)
-- Name: compress_hyper_6_160_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_160_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_160_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6699 (class 1259 OID 8549007)
-- Name: compress_hyper_6_163_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_163_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_163_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6705 (class 1259 OID 8982933)
-- Name: compress_hyper_6_166_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_166_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_166_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6717 (class 1259 OID 9270060)
-- Name: compress_hyper_6_171_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_171_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_171_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6723 (class 1259 OID 9738851)
-- Name: compress_hyper_6_174_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_174_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_174_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6729 (class 1259 OID 10230448)
-- Name: compress_hyper_6_177_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_177_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_177_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6735 (class 1259 OID 10734118)
-- Name: compress_hyper_6_180_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_180_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_180_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6741 (class 1259 OID 11237760)
-- Name: compress_hyper_6_183_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_183_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_183_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6747 (class 1259 OID 11760510)
-- Name: compress_hyper_6_186_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_186_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_186_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6753 (class 1259 OID 12287754)
-- Name: compress_hyper_6_189_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_189_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_189_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6764 (class 1259 OID 12500956)
-- Name: compress_hyper_6_194_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_194_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_194_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6770 (class 1259 OID 13044356)
-- Name: compress_hyper_6_197_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_197_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_197_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6786 (class 1259 OID 14140538)
-- Name: compress_hyper_6_202_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_202_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_202_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6792 (class 1259 OID 14697492)
-- Name: compress_hyper_6_205_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_205_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_205_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6798 (class 1259 OID 15274324)
-- Name: compress_hyper_6_208_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_208_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_208_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6804 (class 1259 OID 15851243)
-- Name: compress_hyper_6_211_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_211_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_211_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6810 (class 1259 OID 16433199)
-- Name: compress_hyper_6_214_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_214_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_214_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6817 (class 1259 OID 16999735)
-- Name: compress_hyper_6_217_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_217_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_217_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6826 (class 1259 OID 17556898)
-- Name: compress_hyper_6_220_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_220_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_220_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6832 (class 1259 OID 18085338)
-- Name: compress_hyper_6_223_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_223_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_223_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6840 (class 1259 OID 18803847)
-- Name: compress_hyper_6_226_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_226_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_226_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6846 (class 1259 OID 20179776)
-- Name: compress_hyper_6_229_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_229_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_229_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6858 (class 1259 OID 21600317)
-- Name: compress_hyper_6_234_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_234_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_234_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6868 (class 1259 OID 23019373)
-- Name: compress_hyper_6_237_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_237_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_237_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6869 (class 1259 OID 24387300)
-- Name: compress_hyper_6_238_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_238_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_238_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6875 (class 1259 OID 25841329)
-- Name: compress_hyper_6_241_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_241_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_241_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6881 (class 1259 OID 27187371)
-- Name: compress_hyper_6_244_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_244_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_244_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6887 (class 1259 OID 28552153)
-- Name: compress_hyper_6_247_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_247_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_247_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6893 (class 1259 OID 29883731)
-- Name: compress_hyper_6_250_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_250_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_250_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6899 (class 1259 OID 31358976)
-- Name: compress_hyper_6_253_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_253_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_253_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6905 (class 1259 OID 32695058)
-- Name: compress_hyper_6_256_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_256_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_256_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6911 (class 1259 OID 34062779)
-- Name: compress_hyper_6_259_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_259_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_259_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6928 (class 1259 OID 35497652)
-- Name: compress_hyper_6_266_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_266_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_266_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6934 (class 1259 OID 36948699)
-- Name: compress_hyper_6_269_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_269_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_269_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6940 (class 1259 OID 38437781)
-- Name: compress_hyper_6_272_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_272_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_272_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6946 (class 1259 OID 40054068)
-- Name: compress_hyper_6_275_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_275_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_275_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6952 (class 1259 OID 41386479)
-- Name: compress_hyper_6_278_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_278_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_278_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6953 (class 1259 OID 42803142)
-- Name: compress_hyper_6_279_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_279_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_279_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6959 (class 1259 OID 44249046)
-- Name: compress_hyper_6_282_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_282_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_282_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6965 (class 1259 OID 45699895)
-- Name: compress_hyper_6_285_chunk__compressed_hypertable_6_mmsi__ts_me; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_285_chunk__compressed_hypertable_6_mmsi__ts_me ON _timescaledb_internal.compress_hyper_6_285_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6521 (class 1259 OID 180195)
-- Name: compress_hyper_6_67_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_67_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_67_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6522 (class 1259 OID 180208)
-- Name: compress_hyper_6_68_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_68_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_68_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6523 (class 1259 OID 180223)
-- Name: compress_hyper_6_69_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_69_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_69_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6524 (class 1259 OID 325401)
-- Name: compress_hyper_6_70_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_70_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_70_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6525 (class 1259 OID 714992)
-- Name: compress_hyper_6_71_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_71_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_71_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6526 (class 1259 OID 1088743)
-- Name: compress_hyper_6_72_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_72_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_72_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6527 (class 1259 OID 1443756)
-- Name: compress_hyper_6_73_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_73_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_73_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6528 (class 1259 OID 1783765)
-- Name: compress_hyper_6_74_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_74_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_74_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6529 (class 1259 OID 2108322)
-- Name: compress_hyper_6_75_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_75_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_75_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6530 (class 1259 OID 2443238)
-- Name: compress_hyper_6_76_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_76_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_76_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6531 (class 1259 OID 2749788)
-- Name: compress_hyper_6_77_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_77_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_77_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6532 (class 1259 OID 3072550)
-- Name: compress_hyper_6_78_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_78_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_78_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6533 (class 1259 OID 3370652)
-- Name: compress_hyper_6_79_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_79_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_79_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6534 (class 1259 OID 3668235)
-- Name: compress_hyper_6_80_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_80_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_80_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6535 (class 1259 OID 3959400)
-- Name: compress_hyper_6_81_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_81_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_81_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6536 (class 1259 OID 4240229)
-- Name: compress_hyper_6_82_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_82_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_82_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6537 (class 1259 OID 4513610)
-- Name: compress_hyper_6_83_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_83_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_83_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6538 (class 1259 OID 4789178)
-- Name: compress_hyper_6_84_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_84_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_84_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6539 (class 1259 OID 5070224)
-- Name: compress_hyper_6_85_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_85_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_85_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6540 (class 1259 OID 5337847)
-- Name: compress_hyper_6_86_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_86_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_86_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6546 (class 1259 OID 5630304)
-- Name: compress_hyper_6_89_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_89_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_89_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6555 (class 1259 OID 5917078)
-- Name: compress_hyper_6_92_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_92_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_92_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6572 (class 1259 OID 6218800)
-- Name: compress_hyper_6_99_chunk__compressed_hypertable_6_mmsi__ts_met; Type: INDEX; Schema: _timescaledb_internal; Owner: vliz
--

CREATE INDEX compress_hyper_6_99_chunk__compressed_hypertable_6_mmsi__ts_met ON _timescaledb_internal.compress_hyper_6_99_chunk USING btree (mmsi, _ts_meta_sequence_num);


--
-- TOC entry 6463 (class 1259 OID 129996)
-- Name: latest_voy_reports_mmsi_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX latest_voy_reports_mmsi_idx ON ais.latest_voy_reports USING btree (mmsi);


--
-- TOC entry 6302 (class 1259 OID 17955)
-- Name: pos_reports_event_time_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX pos_reports_event_time_idx ON ais.pos_reports USING btree (event_time DESC);


--
-- TOC entry 6303 (class 1259 OID 17956)
-- Name: pos_reports_mmsi_event_time_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX pos_reports_mmsi_event_time_idx ON ais.pos_reports USING btree (mmsi, event_time DESC);


--
-- TOC entry 6304 (class 1259 OID 17957)
-- Name: pos_reports_position_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX pos_reports_position_idx ON ais.pos_reports USING gist ("position");


--
-- TOC entry 6461 (class 1259 OID 137533)
-- Name: trajectories_first_time_mmsi_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX trajectories_first_time_mmsi_idx ON ais.trajectories USING btree (first_time DESC, mmsi);


--
-- TOC entry 6462 (class 1259 OID 130010)
-- Name: trajectories_mmsi_first_time_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX trajectories_mmsi_first_time_idx ON ais.trajectories USING btree (mmsi, first_time DESC);


--
-- TOC entry 6819 (class 1259 OID 17554835)
-- Name: vessel_density_agg_event_date_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX vessel_density_agg_event_date_idx ON ais.vessel_density_agg USING btree (event_date);


--
-- TOC entry 6820 (class 1259 OID 18794036)
-- Name: vessel_density_agg_gid_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX vessel_density_agg_gid_idx ON ais.vessel_density_agg USING btree (gid);


--
-- TOC entry 6305 (class 1259 OID 17965)
-- Name: voy_reports_event_time_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX voy_reports_event_time_idx ON ais.voy_reports USING btree (event_time DESC);


--
-- TOC entry 6306 (class 1259 OID 17966)
-- Name: voy_reports_mmsi_event_time_idx; Type: INDEX; Schema: ais; Owner: vliz
--

CREATE INDEX voy_reports_mmsi_event_time_idx ON ais.voy_reports USING btree (mmsi, event_time DESC);


--
-- TOC entry 6420 (class 1259 OID 71238)
-- Name: admin_0_countries_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX admin_0_countries_geom_idx ON geo.admin_0_countries USING gist (geom);


--
-- TOC entry 6313 (class 1259 OID 19047)
-- Name: eez_12nm_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX eez_12nm_geom_idx ON geo.eez_12nm USING gist (geom);


--
-- TOC entry 6310 (class 1259 OID 18776)
-- Name: eez_24nm_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX eez_24nm_geom_idx ON geo.eez_24nm USING gist (geom);


--
-- TOC entry 6319 (class 1259 OID 19293)
-- Name: eez_archipelagic_waters_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX eez_archipelagic_waters_geom_idx ON geo.eez_archipelagic_waters USING gist (geom);


--
-- TOC entry 6316 (class 1259 OID 19233)
-- Name: eez_internal_waters_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX eez_internal_waters_geom_idx ON geo.eez_internal_waters USING gist (geom);


--
-- TOC entry 6423 (class 1259 OID 73199)
-- Name: levels_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX levels_geom_idx ON geo.levels USING gist (geom);


--
-- TOC entry 6811 (class 1259 OID 16990942)
-- Name: maritime_boundaries_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX maritime_boundaries_geom_idx ON geo.maritime_boundaries USING gist (geom);


--
-- TOC entry 6818 (class 1259 OID 17550730)
-- Name: north_sea_hex_grid_1km2_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX north_sea_hex_grid_1km2_geom_idx ON geo.north_sea_hex_grid_1km2 USING gist (geom);


--
-- TOC entry 6322 (class 1259 OID 19307)
-- Name: oceans_world_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX oceans_world_geom_idx ON geo.oceans_world USING gist (geom);


--
-- TOC entry 6328 (class 1259 OID 19764)
-- Name: sampaz_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX sampaz_geom_idx ON geo.sampaz USING gist (geom);


--
-- TOC entry 6307 (class 1259 OID 18508)
-- Name: world_eez_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX world_eez_geom_idx ON geo.world_eez USING gist (geom);


--
-- TOC entry 6325 (class 1259 OID 16990947)
-- Name: world_port_index_geom_idx; Type: INDEX; Schema: geo; Owner: vliz
--

CREATE INDEX world_port_index_geom_idx ON geo.world_port_index USING gist (geom);


--
-- TOC entry 6833 (class 1259 OID 18795659)
-- Name: vessel_density_geom_idx; Type: INDEX; Schema: geoserver; Owner: vliz
--

CREATE INDEX vessel_density_geom_idx ON geoserver.vessel_density USING gist (geom);


--
-- TOC entry 6834 (class 1259 OID 18795662)
-- Name: vessel_density_vars_idx; Type: INDEX; Schema: geoserver; Owner: vliz
--

CREATE INDEX vessel_density_vars_idx ON geoserver.vessel_density USING btree (month, type, year);


--
-- TOC entry 6552 (class 1259 OID 5913607)
-- Name: ais_agg_ver2_event_date_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX ais_agg_ver2_event_date_idx ON rory.ais_agg_ver2 USING btree (event_date);


--
-- TOC entry 6553 (class 1259 OID 5913608)
-- Name: ais_agg_ver2_gid_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX ais_agg_ver2_gid_idx ON rory.ais_agg_ver2 USING btree (gid);


--
-- TOC entry 6554 (class 1259 OID 5913609)
-- Name: ais_agg_ver2_type_and_cargo_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX ais_agg_ver2_type_and_cargo_idx ON rory.ais_agg_ver2 USING btree (type_and_cargo);


--
-- TOC entry 6471 (class 1259 OID 133312)
-- Name: aoi_hex_grid_1km2_geom_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX aoi_hex_grid_1km2_geom_idx ON rory.aoi_hex_grid_1km2 USING gist (geom);


--
-- TOC entry 6450 (class 1259 OID 126562)
-- Name: belgium_hex_grid_100m2_geom_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX belgium_hex_grid_100m2_geom_idx ON rory.belgium_hex_grid_100m2 USING gist (geom);


--
-- TOC entry 6488 (class 1259 OID 142167)
-- Name: complex_ais_agg_event_date_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX complex_ais_agg_event_date_idx ON rory.complex_ais_agg USING btree (event_date);


--
-- TOC entry 6489 (class 1259 OID 142166)
-- Name: complex_ais_agg_geom_idx; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX complex_ais_agg_geom_idx ON rory.complex_ais_agg USING gist (geom);


--
-- TOC entry 6439 (class 1259 OID 123906)
-- Name: ix_aoi_hex_grid_100m2; Type: INDEX; Schema: rory; Owner: vliz
--

CREATE INDEX ix_aoi_hex_grid_100m2 ON rory.aoi_hex_grid_100m2 USING gist (geom);


--
-- TOC entry 6864 (class 1259 OID 23019344)
-- Name: demo_traj_geom_idx; Type: INDEX; Schema: schelde; Owner: vliz
--

CREATE INDEX demo_traj_geom_idx ON schelde.demo_traj USING gist (geom);


--
-- TOC entry 6865 (class 1259 OID 23019343)
-- Name: gebiedindeling_emse_geom_idx; Type: INDEX; Schema: schelde; Owner: vliz
--

CREATE INDEX gebiedindeling_emse_geom_idx ON schelde.gebiedindeling_emse USING gist (geom);


--
-- TOC entry 7073 (class 2620 OID 6521422)
-- Name: _hyper_1_100_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_100_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7076 (class 2620 OID 6819875)
-- Name: _hyper_1_118_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_118_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7077 (class 2620 OID 6819886)
-- Name: _hyper_1_119_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_119_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6982 (class 2620 OID 25880)
-- Name: _hyper_1_11_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_11_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7078 (class 2620 OID 6819897)
-- Name: _hyper_1_120_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_120_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7079 (class 2620 OID 6819908)
-- Name: _hyper_1_121_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_121_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7080 (class 2620 OID 6819919)
-- Name: _hyper_1_122_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_122_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7081 (class 2620 OID 6819930)
-- Name: _hyper_1_123_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_123_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7082 (class 2620 OID 6819941)
-- Name: _hyper_1_124_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_124_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7083 (class 2620 OID 6819952)
-- Name: _hyper_1_125_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_125_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7084 (class 2620 OID 6819963)
-- Name: _hyper_1_126_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_126_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7085 (class 2620 OID 6819974)
-- Name: _hyper_1_127_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_127_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7086 (class 2620 OID 6819985)
-- Name: _hyper_1_128_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_128_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7087 (class 2620 OID 6819996)
-- Name: _hyper_1_129_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_129_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7088 (class 2620 OID 6820007)
-- Name: _hyper_1_130_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_130_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7089 (class 2620 OID 6820018)
-- Name: _hyper_1_131_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_131_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7090 (class 2620 OID 6820029)
-- Name: _hyper_1_132_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_132_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7091 (class 2620 OID 6820040)
-- Name: _hyper_1_133_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_133_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7092 (class 2620 OID 6820051)
-- Name: _hyper_1_134_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_134_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7093 (class 2620 OID 6820062)
-- Name: _hyper_1_135_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_135_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7094 (class 2620 OID 6820073)
-- Name: _hyper_1_136_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_136_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7095 (class 2620 OID 6820084)
-- Name: _hyper_1_137_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_137_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7096 (class 2620 OID 6820095)
-- Name: _hyper_1_138_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_138_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7097 (class 2620 OID 6820106)
-- Name: _hyper_1_139_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_139_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6985 (class 2620 OID 36434)
-- Name: _hyper_1_13_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_13_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7098 (class 2620 OID 6820117)
-- Name: _hyper_1_140_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_140_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7099 (class 2620 OID 6820128)
-- Name: _hyper_1_141_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_141_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7100 (class 2620 OID 6820139)
-- Name: _hyper_1_142_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_142_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7101 (class 2620 OID 6820150)
-- Name: _hyper_1_143_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_143_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7102 (class 2620 OID 6820161)
-- Name: _hyper_1_144_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_144_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7103 (class 2620 OID 6820172)
-- Name: _hyper_1_145_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_145_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7104 (class 2620 OID 6822278)
-- Name: _hyper_1_148_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_148_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7107 (class 2620 OID 7148772)
-- Name: _hyper_1_151_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_151_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7110 (class 2620 OID 7479148)
-- Name: _hyper_1_154_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_154_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7113 (class 2620 OID 7839722)
-- Name: _hyper_1_157_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_157_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6988 (class 2620 OID 36815)
-- Name: _hyper_1_15_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_15_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7118 (class 2620 OID 8547907)
-- Name: _hyper_1_162_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_162_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7119 (class 2620 OID 8980674)
-- Name: _hyper_1_164_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_164_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7122 (class 2620 OID 9267745)
-- Name: _hyper_1_167_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_167_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7125 (class 2620 OID 9736632)
-- Name: _hyper_1_172_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_172_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7128 (class 2620 OID 10228146)
-- Name: _hyper_1_175_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_175_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7131 (class 2620 OID 10732084)
-- Name: _hyper_1_178_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_178_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6991 (class 2620 OID 37190)
-- Name: _hyper_1_17_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_17_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7134 (class 2620 OID 11235464)
-- Name: _hyper_1_181_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_181_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7137 (class 2620 OID 11758317)
-- Name: _hyper_1_184_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_184_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7140 (class 2620 OID 12285409)
-- Name: _hyper_1_187_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_187_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7143 (class 2620 OID 12492985)
-- Name: _hyper_1_190_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_190_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7146 (class 2620 OID 12498853)
-- Name: _hyper_1_192_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_192_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7149 (class 2620 OID 13022944)
-- Name: _hyper_1_195_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_195_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7152 (class 2620 OID 14137177)
-- Name: _hyper_1_198_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_198_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6994 (class 2620 OID 52090)
-- Name: _hyper_1_19_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_19_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6971 (class 2620 OID 24880)
-- Name: _hyper_1_1_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_1_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7155 (class 2620 OID 14694315)
-- Name: _hyper_1_203_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_203_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7158 (class 2620 OID 15271005)
-- Name: _hyper_1_206_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_206_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7161 (class 2620 OID 15848143)
-- Name: _hyper_1_209_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_209_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7164 (class 2620 OID 16429905)
-- Name: _hyper_1_212_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_212_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7169 (class 2620 OID 16996378)
-- Name: _hyper_1_216_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_216_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7170 (class 2620 OID 17552493)
-- Name: _hyper_1_218_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_218_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6997 (class 2620 OID 52553)
-- Name: _hyper_1_21_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_21_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7173 (class 2620 OID 18081992)
-- Name: _hyper_1_221_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_221_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7176 (class 2620 OID 18797343)
-- Name: _hyper_1_224_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_224_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7179 (class 2620 OID 20176728)
-- Name: _hyper_1_227_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_227_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7182 (class 2620 OID 21597022)
-- Name: _hyper_1_230_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_230_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7185 (class 2620 OID 23006081)
-- Name: _hyper_1_235_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_235_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7188 (class 2620 OID 25832595)
-- Name: _hyper_1_239_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_239_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7000 (class 2620 OID 52925)
-- Name: _hyper_1_23_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_23_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7191 (class 2620 OID 27178897)
-- Name: _hyper_1_242_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_242_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7194 (class 2620 OID 28545444)
-- Name: _hyper_1_245_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_245_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7197 (class 2620 OID 29876898)
-- Name: _hyper_1_248_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_248_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7200 (class 2620 OID 31351417)
-- Name: _hyper_1_251_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_251_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7205 (class 2620 OID 32687039)
-- Name: _hyper_1_255_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_255_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7206 (class 2620 OID 34051005)
-- Name: _hyper_1_257_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_257_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7003 (class 2620 OID 66589)
-- Name: _hyper_1_25_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_25_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7209 (class 2620 OID 35482476)
-- Name: _hyper_1_260_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_260_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7212 (class 2620 OID 35494466)
-- Name: _hyper_1_262_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_262_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7215 (class 2620 OID 36945277)
-- Name: _hyper_1_267_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_267_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7218 (class 2620 OID 38434298)
-- Name: _hyper_1_270_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_270_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7221 (class 2620 OID 40050747)
-- Name: _hyper_1_273_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_273_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7224 (class 2620 OID 41383283)
-- Name: _hyper_1_276_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_276_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7006 (class 2620 OID 67010)
-- Name: _hyper_1_27_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_27_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7227 (class 2620 OID 44240096)
-- Name: _hyper_1_280_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_280_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7230 (class 2620 OID 45689982)
-- Name: _hyper_1_283_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_283_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7009 (class 2620 OID 67587)
-- Name: _hyper_1_31_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_31_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7012 (class 2620 OID 76858)
-- Name: _hyper_1_33_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_33_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7015 (class 2620 OID 123158)
-- Name: _hyper_1_35_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_35_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7018 (class 2620 OID 123532)
-- Name: _hyper_1_37_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_37_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7021 (class 2620 OID 123918)
-- Name: _hyper_1_39_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_39_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7024 (class 2620 OID 126260)
-- Name: _hyper_1_41_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_41_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7027 (class 2620 OID 126663)
-- Name: _hyper_1_43_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_43_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7030 (class 2620 OID 127034)
-- Name: _hyper_1_45_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_45_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7033 (class 2620 OID 133022)
-- Name: _hyper_1_47_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_47_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7036 (class 2620 OID 137238)
-- Name: _hyper_1_49_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_49_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7039 (class 2620 OID 141191)
-- Name: _hyper_1_53_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_53_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7042 (class 2620 OID 145610)
-- Name: _hyper_1_55_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_55_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7045 (class 2620 OID 150390)
-- Name: _hyper_1_57_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_57_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7048 (class 2620 OID 156238)
-- Name: _hyper_1_59_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_59_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6976 (class 2620 OID 24965)
-- Name: _hyper_1_5_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_5_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7051 (class 2620 OID 162850)
-- Name: _hyper_1_61_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_61_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7054 (class 2620 OID 170236)
-- Name: _hyper_1_63_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_63_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7057 (class 2620 OID 176691)
-- Name: _hyper_1_65_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_65_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7061 (class 2620 OID 5625473)
-- Name: _hyper_1_87_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_87_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7064 (class 2620 OID 5912407)
-- Name: _hyper_1_90_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_90_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7069 (class 2620 OID 6212218)
-- Name: _hyper_1_94_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_94_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7070 (class 2620 OID 6216977)
-- Name: _hyper_1_97_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_97_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6979 (class 2620 OID 25488)
-- Name: _hyper_1_9_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_1_9_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 7075 (class 2620 OID 6521433)
-- Name: _hyper_2_101_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_101_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6981 (class 2620 OID 25615)
-- Name: _hyper_2_10_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_10_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6984 (class 2620 OID 25891)
-- Name: _hyper_2_12_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_12_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7105 (class 2620 OID 6822289)
-- Name: _hyper_2_149_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_149_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6987 (class 2620 OID 36445)
-- Name: _hyper_2_14_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_14_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7108 (class 2620 OID 7148783)
-- Name: _hyper_2_152_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_152_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7111 (class 2620 OID 7479159)
-- Name: _hyper_2_155_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_155_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7114 (class 2620 OID 7839733)
-- Name: _hyper_2_158_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_158_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7116 (class 2620 OID 8547896)
-- Name: _hyper_2_161_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_161_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7120 (class 2620 OID 8980685)
-- Name: _hyper_2_165_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_165_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7123 (class 2620 OID 9267756)
-- Name: _hyper_2_168_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_168_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6990 (class 2620 OID 36826)
-- Name: _hyper_2_16_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_16_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7126 (class 2620 OID 9736643)
-- Name: _hyper_2_173_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_173_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7129 (class 2620 OID 10228157)
-- Name: _hyper_2_176_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_176_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7132 (class 2620 OID 10732095)
-- Name: _hyper_2_179_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_179_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7135 (class 2620 OID 11235475)
-- Name: _hyper_2_182_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_182_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7138 (class 2620 OID 11758328)
-- Name: _hyper_2_185_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_185_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7141 (class 2620 OID 12285420)
-- Name: _hyper_2_188_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_188_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6993 (class 2620 OID 37201)
-- Name: _hyper_2_18_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_18_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7144 (class 2620 OID 12492996)
-- Name: _hyper_2_191_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_191_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7147 (class 2620 OID 12498864)
-- Name: _hyper_2_193_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_193_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7150 (class 2620 OID 13022955)
-- Name: _hyper_2_196_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_196_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7153 (class 2620 OID 14137188)
-- Name: _hyper_2_199_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_199_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7156 (class 2620 OID 14694326)
-- Name: _hyper_2_204_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_204_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7159 (class 2620 OID 15271016)
-- Name: _hyper_2_207_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_207_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6996 (class 2620 OID 52101)
-- Name: _hyper_2_20_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_20_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7162 (class 2620 OID 15848154)
-- Name: _hyper_2_210_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_210_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7165 (class 2620 OID 16429916)
-- Name: _hyper_2_213_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_213_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7167 (class 2620 OID 16996367)
-- Name: _hyper_2_215_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_215_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7171 (class 2620 OID 17552504)
-- Name: _hyper_2_219_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_219_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7174 (class 2620 OID 18082003)
-- Name: _hyper_2_222_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_222_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7177 (class 2620 OID 18797354)
-- Name: _hyper_2_225_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_225_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7180 (class 2620 OID 20176739)
-- Name: _hyper_2_228_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_228_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6999 (class 2620 OID 52564)
-- Name: _hyper_2_22_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_22_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7183 (class 2620 OID 21597033)
-- Name: _hyper_2_231_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_231_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7186 (class 2620 OID 23006092)
-- Name: _hyper_2_236_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_236_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7189 (class 2620 OID 25832606)
-- Name: _hyper_2_240_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_240_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7192 (class 2620 OID 27178908)
-- Name: _hyper_2_243_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_243_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7195 (class 2620 OID 28545455)
-- Name: _hyper_2_246_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_246_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7198 (class 2620 OID 29876909)
-- Name: _hyper_2_249_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_249_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7002 (class 2620 OID 52936)
-- Name: _hyper_2_24_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_24_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7201 (class 2620 OID 31351428)
-- Name: _hyper_2_252_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_252_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7203 (class 2620 OID 32687028)
-- Name: _hyper_2_254_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_254_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7207 (class 2620 OID 34051016)
-- Name: _hyper_2_258_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_258_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7210 (class 2620 OID 35482487)
-- Name: _hyper_2_261_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_261_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7213 (class 2620 OID 35494477)
-- Name: _hyper_2_263_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_263_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7216 (class 2620 OID 36945288)
-- Name: _hyper_2_268_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_268_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7005 (class 2620 OID 66600)
-- Name: _hyper_2_26_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_26_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7219 (class 2620 OID 38434309)
-- Name: _hyper_2_271_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_271_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7222 (class 2620 OID 40050758)
-- Name: _hyper_2_274_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_274_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7225 (class 2620 OID 41383294)
-- Name: _hyper_2_277_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_277_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7228 (class 2620 OID 44240107)
-- Name: _hyper_2_281_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_281_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7231 (class 2620 OID 45689993)
-- Name: _hyper_2_284_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_284_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7008 (class 2620 OID 67021)
-- Name: _hyper_2_28_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_28_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6973 (class 2620 OID 24908)
-- Name: _hyper_2_2_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_2_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7011 (class 2620 OID 67598)
-- Name: _hyper_2_32_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_32_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7014 (class 2620 OID 76869)
-- Name: _hyper_2_34_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_34_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7017 (class 2620 OID 123169)
-- Name: _hyper_2_36_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_36_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7020 (class 2620 OID 123543)
-- Name: _hyper_2_38_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_38_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7023 (class 2620 OID 123929)
-- Name: _hyper_2_40_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_40_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7026 (class 2620 OID 126271)
-- Name: _hyper_2_42_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_42_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7029 (class 2620 OID 126674)
-- Name: _hyper_2_44_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_44_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7032 (class 2620 OID 127045)
-- Name: _hyper_2_46_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_46_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7035 (class 2620 OID 133033)
-- Name: _hyper_2_48_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_48_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7038 (class 2620 OID 137249)
-- Name: _hyper_2_50_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_50_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7041 (class 2620 OID 141202)
-- Name: _hyper_2_54_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_54_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7044 (class 2620 OID 145621)
-- Name: _hyper_2_56_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_56_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7047 (class 2620 OID 150401)
-- Name: _hyper_2_58_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_58_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7050 (class 2620 OID 156249)
-- Name: _hyper_2_60_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_60_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7053 (class 2620 OID 162861)
-- Name: _hyper_2_62_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_62_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7056 (class 2620 OID 170247)
-- Name: _hyper_2_64_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_64_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7059 (class 2620 OID 176702)
-- Name: _hyper_2_66_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_66_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6978 (class 2620 OID 25293)
-- Name: _hyper_2_7_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_7_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7063 (class 2620 OID 5625484)
-- Name: _hyper_2_88_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_88_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7066 (class 2620 OID 5912418)
-- Name: _hyper_2_91_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_91_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7068 (class 2620 OID 6212207)
-- Name: _hyper_2_93_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_93_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7072 (class 2620 OID 6216988)
-- Name: _hyper_2_98_chunk ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON _timescaledb_internal._hyper_2_98_chunk FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 7060 (class 2620 OID 180187)
-- Name: _compressed_hypertable_6 ts_insert_blocker; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON _timescaledb_internal._compressed_hypertable_6 FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();


--
-- TOC entry 6974 (class 2620 OID 24860)
-- Name: _materialized_hypertable_4 ts_insert_blocker; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON _timescaledb_internal._materialized_hypertable_4 FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();


--
-- TOC entry 6975 (class 2620 OID 24888)
-- Name: _materialized_hypertable_5 ts_insert_blocker; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON _timescaledb_internal._materialized_hypertable_5 FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();


--
-- TOC entry 7074 (class 2620 OID 6521434)
-- Name: _hyper_2_101_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_101_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6980 (class 2620 OID 129973)
-- Name: _hyper_2_10_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_10_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6983 (class 2620 OID 129974)
-- Name: _hyper_2_12_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_12_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7106 (class 2620 OID 6822290)
-- Name: _hyper_2_149_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_149_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6986 (class 2620 OID 129975)
-- Name: _hyper_2_14_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_14_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7109 (class 2620 OID 7148784)
-- Name: _hyper_2_152_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_152_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7112 (class 2620 OID 7479160)
-- Name: _hyper_2_155_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_155_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7115 (class 2620 OID 7839734)
-- Name: _hyper_2_158_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_158_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7117 (class 2620 OID 8547897)
-- Name: _hyper_2_161_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_161_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7121 (class 2620 OID 8980686)
-- Name: _hyper_2_165_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_165_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7124 (class 2620 OID 9267757)
-- Name: _hyper_2_168_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_168_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6989 (class 2620 OID 129976)
-- Name: _hyper_2_16_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_16_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7127 (class 2620 OID 9736644)
-- Name: _hyper_2_173_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_173_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7130 (class 2620 OID 10228158)
-- Name: _hyper_2_176_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_176_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7133 (class 2620 OID 10732096)
-- Name: _hyper_2_179_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_179_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7136 (class 2620 OID 11235476)
-- Name: _hyper_2_182_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_182_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7139 (class 2620 OID 11758329)
-- Name: _hyper_2_185_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_185_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7142 (class 2620 OID 12285421)
-- Name: _hyper_2_188_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_188_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6992 (class 2620 OID 129977)
-- Name: _hyper_2_18_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_18_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7145 (class 2620 OID 12492997)
-- Name: _hyper_2_191_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_191_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7148 (class 2620 OID 12498865)
-- Name: _hyper_2_193_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_193_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7151 (class 2620 OID 13022956)
-- Name: _hyper_2_196_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_196_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7154 (class 2620 OID 14137189)
-- Name: _hyper_2_199_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_199_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7157 (class 2620 OID 14694327)
-- Name: _hyper_2_204_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_204_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7160 (class 2620 OID 15271017)
-- Name: _hyper_2_207_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_207_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6995 (class 2620 OID 129978)
-- Name: _hyper_2_20_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_20_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7163 (class 2620 OID 15848155)
-- Name: _hyper_2_210_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_210_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7166 (class 2620 OID 16429917)
-- Name: _hyper_2_213_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_213_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7168 (class 2620 OID 16996368)
-- Name: _hyper_2_215_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_215_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7172 (class 2620 OID 17552505)
-- Name: _hyper_2_219_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_219_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7175 (class 2620 OID 18082004)
-- Name: _hyper_2_222_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_222_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7178 (class 2620 OID 18797355)
-- Name: _hyper_2_225_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_225_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7181 (class 2620 OID 20176740)
-- Name: _hyper_2_228_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_228_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6998 (class 2620 OID 129979)
-- Name: _hyper_2_22_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_22_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7184 (class 2620 OID 21597034)
-- Name: _hyper_2_231_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_231_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7187 (class 2620 OID 23006093)
-- Name: _hyper_2_236_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_236_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7190 (class 2620 OID 25832607)
-- Name: _hyper_2_240_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_240_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7193 (class 2620 OID 27178909)
-- Name: _hyper_2_243_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_243_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7196 (class 2620 OID 28545456)
-- Name: _hyper_2_246_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_246_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7199 (class 2620 OID 29876910)
-- Name: _hyper_2_249_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_249_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7001 (class 2620 OID 129980)
-- Name: _hyper_2_24_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_24_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7202 (class 2620 OID 31351429)
-- Name: _hyper_2_252_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_252_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7204 (class 2620 OID 32687029)
-- Name: _hyper_2_254_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_254_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7208 (class 2620 OID 34051017)
-- Name: _hyper_2_258_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_258_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7211 (class 2620 OID 35482488)
-- Name: _hyper_2_261_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_261_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7214 (class 2620 OID 35494478)
-- Name: _hyper_2_263_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_263_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7217 (class 2620 OID 36945289)
-- Name: _hyper_2_268_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_268_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7004 (class 2620 OID 129981)
-- Name: _hyper_2_26_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_26_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7220 (class 2620 OID 38434310)
-- Name: _hyper_2_271_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_271_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7223 (class 2620 OID 40050759)
-- Name: _hyper_2_274_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_274_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7226 (class 2620 OID 41383295)
-- Name: _hyper_2_277_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_277_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7229 (class 2620 OID 44240108)
-- Name: _hyper_2_281_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_281_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7232 (class 2620 OID 45689994)
-- Name: _hyper_2_284_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_284_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7007 (class 2620 OID 129982)
-- Name: _hyper_2_28_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_28_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6972 (class 2620 OID 129971)
-- Name: _hyper_2_2_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_2_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7010 (class 2620 OID 129983)
-- Name: _hyper_2_32_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_32_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7013 (class 2620 OID 129984)
-- Name: _hyper_2_34_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_34_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7016 (class 2620 OID 129985)
-- Name: _hyper_2_36_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_36_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7019 (class 2620 OID 129986)
-- Name: _hyper_2_38_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_38_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7022 (class 2620 OID 129987)
-- Name: _hyper_2_40_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_40_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7025 (class 2620 OID 129988)
-- Name: _hyper_2_42_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_42_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7028 (class 2620 OID 129989)
-- Name: _hyper_2_44_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_44_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7031 (class 2620 OID 129990)
-- Name: _hyper_2_46_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_46_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7034 (class 2620 OID 133034)
-- Name: _hyper_2_48_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_48_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7037 (class 2620 OID 137250)
-- Name: _hyper_2_50_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_50_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7040 (class 2620 OID 141203)
-- Name: _hyper_2_54_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_54_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7043 (class 2620 OID 145622)
-- Name: _hyper_2_56_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_56_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7046 (class 2620 OID 150402)
-- Name: _hyper_2_58_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_58_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7049 (class 2620 OID 156250)
-- Name: _hyper_2_60_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_60_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7052 (class 2620 OID 162862)
-- Name: _hyper_2_62_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_62_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7055 (class 2620 OID 170248)
-- Name: _hyper_2_64_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_64_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7058 (class 2620 OID 176703)
-- Name: _hyper_2_66_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_66_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6977 (class 2620 OID 129972)
-- Name: _hyper_2_7_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_7_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7062 (class 2620 OID 5625485)
-- Name: _hyper_2_88_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_88_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7065 (class 2620 OID 5912419)
-- Name: _hyper_2_91_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_91_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7067 (class 2620 OID 6212208)
-- Name: _hyper_2_93_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_93_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7071 (class 2620 OID 6216989)
-- Name: _hyper_2_98_chunk vessel_details_upsert; Type: TRIGGER; Schema: _timescaledb_internal; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON _timescaledb_internal._hyper_2_98_chunk FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 6966 (class 2620 OID 24879)
-- Name: pos_reports ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: ais; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');


--
-- TOC entry 6969 (class 2620 OID 24907)
-- Name: voy_reports ts_cagg_invalidation_trigger; Type: TRIGGER; Schema: ais; Owner: vliz
--

CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');


--
-- TOC entry 6967 (class 2620 OID 17954)
-- Name: pos_reports ts_insert_blocker; Type: TRIGGER; Schema: ais; Owner: vliz
--

CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();


--
-- TOC entry 6970 (class 2620 OID 17964)
-- Name: voy_reports ts_insert_blocker; Type: TRIGGER; Schema: ais; Owner: vliz
--

CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();


--
-- TOC entry 6968 (class 2620 OID 129970)
-- Name: voy_reports vessel_details_upsert; Type: TRIGGER; Schema: ais; Owner: vliz
--

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();


--
-- TOC entry 7423 (class 0 OID 0)
-- Dependencies: 7422
-- Name: DATABASE vessels; Type: ACL; Schema: -; Owner: vliz
--

GRANT CONNECT ON DATABASE vessels TO vliz_grafana;
GRANT CONNECT ON DATABASE vessels TO readaccess;
GRANT CONNECT ON DATABASE vessels TO geoserver;
GRANT CONNECT ON DATABASE vessels TO inserter;


--
-- TOC entry 7424 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA public TO readaccess;


--
-- TOC entry 7426 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA ais; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA ais TO vliz_grafana;
GRANT USAGE ON SCHEMA ais TO readaccess;
GRANT USAGE ON SCHEMA ais TO inserter;


--
-- TOC entry 7427 (class 0 OID 0)
-- Dependencies: 21
-- Name: SCHEMA geo; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA geo TO readaccess;


--
-- TOC entry 7429 (class 0 OID 0)
-- Dependencies: 19
-- Name: SCHEMA geoserver; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA geoserver TO read_user;
GRANT USAGE ON SCHEMA geoserver TO geoserver;


--
-- TOC entry 7430 (class 0 OID 0)
-- Dependencies: 17
-- Name: SCHEMA postgisftw; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA postgisftw TO readaccess;


--
-- TOC entry 7432 (class 0 OID 0)
-- Dependencies: 20
-- Name: SCHEMA rory; Type: ACL; Schema: -; Owner: vliz
--

GRANT USAGE ON SCHEMA rory TO readaccess;


--
-- TOC entry 7445 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE pos_reports; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.pos_reports TO vliz_grafana;
GRANT SELECT ON TABLE ais.pos_reports TO readaccess;
GRANT INSERT ON TABLE ais.pos_reports TO inserter;


--
-- TOC entry 7446 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE voy_reports; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.voy_reports TO vliz_grafana;
GRANT SELECT ON TABLE ais.voy_reports TO readaccess;
GRANT INSERT ON TABLE ais.voy_reports TO inserter;


--
-- TOC entry 7447 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE _hyper_1_100_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_100_chunk TO vliz_grafana;


--
-- TOC entry 7448 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE _hyper_1_118_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_118_chunk TO vliz_grafana;


--
-- TOC entry 7449 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE _hyper_1_119_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_119_chunk TO vliz_grafana;


--
-- TOC entry 7450 (class 0 OID 0)
-- Dependencies: 303
-- Name: TABLE _hyper_1_11_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_11_chunk TO vliz_grafana;


--
-- TOC entry 7451 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE _hyper_1_120_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_120_chunk TO vliz_grafana;


--
-- TOC entry 7452 (class 0 OID 0)
-- Dependencies: 424
-- Name: TABLE _hyper_1_121_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_121_chunk TO vliz_grafana;


--
-- TOC entry 7453 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE _hyper_1_122_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_122_chunk TO vliz_grafana;


--
-- TOC entry 7454 (class 0 OID 0)
-- Dependencies: 426
-- Name: TABLE _hyper_1_123_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_123_chunk TO vliz_grafana;


--
-- TOC entry 7455 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE _hyper_1_124_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_124_chunk TO vliz_grafana;


--
-- TOC entry 7456 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE _hyper_1_125_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_125_chunk TO vliz_grafana;


--
-- TOC entry 7457 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE _hyper_1_126_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_126_chunk TO vliz_grafana;


--
-- TOC entry 7458 (class 0 OID 0)
-- Dependencies: 430
-- Name: TABLE _hyper_1_127_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_127_chunk TO vliz_grafana;


--
-- TOC entry 7459 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE _hyper_1_128_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_128_chunk TO vliz_grafana;


--
-- TOC entry 7460 (class 0 OID 0)
-- Dependencies: 432
-- Name: TABLE _hyper_1_129_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_129_chunk TO vliz_grafana;


--
-- TOC entry 7461 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE _hyper_1_130_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_130_chunk TO vliz_grafana;


--
-- TOC entry 7462 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE _hyper_1_131_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_131_chunk TO vliz_grafana;


--
-- TOC entry 7463 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE _hyper_1_132_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_132_chunk TO vliz_grafana;


--
-- TOC entry 7464 (class 0 OID 0)
-- Dependencies: 436
-- Name: TABLE _hyper_1_133_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_133_chunk TO vliz_grafana;


--
-- TOC entry 7465 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE _hyper_1_134_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_134_chunk TO vliz_grafana;


--
-- TOC entry 7466 (class 0 OID 0)
-- Dependencies: 438
-- Name: TABLE _hyper_1_135_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_135_chunk TO vliz_grafana;


--
-- TOC entry 7467 (class 0 OID 0)
-- Dependencies: 439
-- Name: TABLE _hyper_1_136_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_136_chunk TO vliz_grafana;


--
-- TOC entry 7468 (class 0 OID 0)
-- Dependencies: 440
-- Name: TABLE _hyper_1_137_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_137_chunk TO vliz_grafana;


--
-- TOC entry 7469 (class 0 OID 0)
-- Dependencies: 441
-- Name: TABLE _hyper_1_138_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_138_chunk TO vliz_grafana;


--
-- TOC entry 7470 (class 0 OID 0)
-- Dependencies: 442
-- Name: TABLE _hyper_1_139_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_139_chunk TO vliz_grafana;


--
-- TOC entry 7471 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE _hyper_1_13_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_13_chunk TO vliz_grafana;


--
-- TOC entry 7472 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE _hyper_1_140_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_140_chunk TO vliz_grafana;


--
-- TOC entry 7473 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE _hyper_1_141_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_141_chunk TO vliz_grafana;


--
-- TOC entry 7474 (class 0 OID 0)
-- Dependencies: 445
-- Name: TABLE _hyper_1_142_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_142_chunk TO vliz_grafana;


--
-- TOC entry 7475 (class 0 OID 0)
-- Dependencies: 446
-- Name: TABLE _hyper_1_143_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_143_chunk TO vliz_grafana;


--
-- TOC entry 7476 (class 0 OID 0)
-- Dependencies: 447
-- Name: TABLE _hyper_1_144_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_144_chunk TO vliz_grafana;


--
-- TOC entry 7477 (class 0 OID 0)
-- Dependencies: 448
-- Name: TABLE _hyper_1_145_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_145_chunk TO vliz_grafana;


--
-- TOC entry 7478 (class 0 OID 0)
-- Dependencies: 451
-- Name: TABLE _hyper_1_148_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_148_chunk TO vliz_grafana;


--
-- TOC entry 7479 (class 0 OID 0)
-- Dependencies: 454
-- Name: TABLE _hyper_1_151_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_151_chunk TO vliz_grafana;


--
-- TOC entry 7480 (class 0 OID 0)
-- Dependencies: 457
-- Name: TABLE _hyper_1_154_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_154_chunk TO vliz_grafana;


--
-- TOC entry 7481 (class 0 OID 0)
-- Dependencies: 460
-- Name: TABLE _hyper_1_157_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_157_chunk TO vliz_grafana;


--
-- TOC entry 7482 (class 0 OID 0)
-- Dependencies: 307
-- Name: TABLE _hyper_1_15_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_15_chunk TO vliz_grafana;


--
-- TOC entry 7483 (class 0 OID 0)
-- Dependencies: 465
-- Name: TABLE _hyper_1_162_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_162_chunk TO vliz_grafana;


--
-- TOC entry 7484 (class 0 OID 0)
-- Dependencies: 467
-- Name: TABLE _hyper_1_164_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_164_chunk TO vliz_grafana;


--
-- TOC entry 7485 (class 0 OID 0)
-- Dependencies: 470
-- Name: TABLE _hyper_1_167_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_167_chunk TO vliz_grafana;


--
-- TOC entry 7486 (class 0 OID 0)
-- Dependencies: 475
-- Name: TABLE _hyper_1_172_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_172_chunk TO vliz_grafana;


--
-- TOC entry 7487 (class 0 OID 0)
-- Dependencies: 478
-- Name: TABLE _hyper_1_175_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_175_chunk TO vliz_grafana;


--
-- TOC entry 7488 (class 0 OID 0)
-- Dependencies: 481
-- Name: TABLE _hyper_1_178_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_178_chunk TO vliz_grafana;


--
-- TOC entry 7489 (class 0 OID 0)
-- Dependencies: 309
-- Name: TABLE _hyper_1_17_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_17_chunk TO vliz_grafana;


--
-- TOC entry 7490 (class 0 OID 0)
-- Dependencies: 484
-- Name: TABLE _hyper_1_181_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_181_chunk TO vliz_grafana;


--
-- TOC entry 7491 (class 0 OID 0)
-- Dependencies: 487
-- Name: TABLE _hyper_1_184_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_184_chunk TO vliz_grafana;


--
-- TOC entry 7492 (class 0 OID 0)
-- Dependencies: 490
-- Name: TABLE _hyper_1_187_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_187_chunk TO vliz_grafana;


--
-- TOC entry 7493 (class 0 OID 0)
-- Dependencies: 493
-- Name: TABLE _hyper_1_190_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_190_chunk TO vliz_grafana;


--
-- TOC entry 7494 (class 0 OID 0)
-- Dependencies: 495
-- Name: TABLE _hyper_1_192_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_192_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_192_chunk TO readaccess;


--
-- TOC entry 7495 (class 0 OID 0)
-- Dependencies: 498
-- Name: TABLE _hyper_1_195_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_195_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_195_chunk TO readaccess;


--
-- TOC entry 7496 (class 0 OID 0)
-- Dependencies: 511
-- Name: TABLE _hyper_1_198_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_198_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_198_chunk TO readaccess;


--
-- TOC entry 7497 (class 0 OID 0)
-- Dependencies: 314
-- Name: TABLE _hyper_1_19_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_19_chunk TO vliz_grafana;


--
-- TOC entry 7498 (class 0 OID 0)
-- Dependencies: 516
-- Name: TABLE _hyper_1_203_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_203_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_203_chunk TO readaccess;


--
-- TOC entry 7499 (class 0 OID 0)
-- Dependencies: 519
-- Name: TABLE _hyper_1_206_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_206_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_206_chunk TO readaccess;


--
-- TOC entry 7500 (class 0 OID 0)
-- Dependencies: 522
-- Name: TABLE _hyper_1_209_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_209_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_209_chunk TO readaccess;


--
-- TOC entry 7501 (class 0 OID 0)
-- Dependencies: 526
-- Name: TABLE _hyper_1_212_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_212_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_212_chunk TO readaccess;


--
-- TOC entry 7502 (class 0 OID 0)
-- Dependencies: 532
-- Name: TABLE _hyper_1_216_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_216_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_216_chunk TO readaccess;


--
-- TOC entry 7503 (class 0 OID 0)
-- Dependencies: 538
-- Name: TABLE _hyper_1_218_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_218_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_218_chunk TO readaccess;


--
-- TOC entry 7504 (class 0 OID 0)
-- Dependencies: 317
-- Name: TABLE _hyper_1_21_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_21_chunk TO vliz_grafana;


--
-- TOC entry 7505 (class 0 OID 0)
-- Dependencies: 541
-- Name: TABLE _hyper_1_221_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_221_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_221_chunk TO readaccess;


--
-- TOC entry 7506 (class 0 OID 0)
-- Dependencies: 545
-- Name: TABLE _hyper_1_224_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_224_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_224_chunk TO readaccess;


--
-- TOC entry 7507 (class 0 OID 0)
-- Dependencies: 548
-- Name: TABLE _hyper_1_227_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_227_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_227_chunk TO readaccess;


--
-- TOC entry 7508 (class 0 OID 0)
-- Dependencies: 551
-- Name: TABLE _hyper_1_230_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_230_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_230_chunk TO readaccess;


--
-- TOC entry 7509 (class 0 OID 0)
-- Dependencies: 556
-- Name: TABLE _hyper_1_235_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_235_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_235_chunk TO readaccess;


--
-- TOC entry 7510 (class 0 OID 0)
-- Dependencies: 564
-- Name: TABLE _hyper_1_239_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_239_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_239_chunk TO readaccess;


--
-- TOC entry 7511 (class 0 OID 0)
-- Dependencies: 319
-- Name: TABLE _hyper_1_23_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_23_chunk TO vliz_grafana;


--
-- TOC entry 7512 (class 0 OID 0)
-- Dependencies: 567
-- Name: TABLE _hyper_1_242_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_242_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_242_chunk TO readaccess;


--
-- TOC entry 7513 (class 0 OID 0)
-- Dependencies: 570
-- Name: TABLE _hyper_1_245_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_245_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_245_chunk TO readaccess;


--
-- TOC entry 7514 (class 0 OID 0)
-- Dependencies: 573
-- Name: TABLE _hyper_1_248_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_248_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_248_chunk TO readaccess;


--
-- TOC entry 7515 (class 0 OID 0)
-- Dependencies: 576
-- Name: TABLE _hyper_1_251_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_251_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_251_chunk TO readaccess;


--
-- TOC entry 7516 (class 0 OID 0)
-- Dependencies: 580
-- Name: TABLE _hyper_1_255_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_255_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_255_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_255_chunk TO inserter;


--
-- TOC entry 7517 (class 0 OID 0)
-- Dependencies: 582
-- Name: TABLE _hyper_1_257_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_257_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_257_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_257_chunk TO inserter;


--
-- TOC entry 7518 (class 0 OID 0)
-- Dependencies: 321
-- Name: TABLE _hyper_1_25_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_25_chunk TO vliz_grafana;


--
-- TOC entry 7519 (class 0 OID 0)
-- Dependencies: 585
-- Name: TABLE _hyper_1_260_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_260_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_260_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_260_chunk TO inserter;


--
-- TOC entry 7520 (class 0 OID 0)
-- Dependencies: 587
-- Name: TABLE _hyper_1_262_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_262_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_262_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_262_chunk TO inserter;


--
-- TOC entry 7521 (class 0 OID 0)
-- Dependencies: 592
-- Name: TABLE _hyper_1_267_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_267_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_267_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_267_chunk TO inserter;


--
-- TOC entry 7522 (class 0 OID 0)
-- Dependencies: 595
-- Name: TABLE _hyper_1_270_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_270_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_270_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_270_chunk TO inserter;


--
-- TOC entry 7523 (class 0 OID 0)
-- Dependencies: 598
-- Name: TABLE _hyper_1_273_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_273_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_273_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_273_chunk TO inserter;


--
-- TOC entry 7524 (class 0 OID 0)
-- Dependencies: 601
-- Name: TABLE _hyper_1_276_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_276_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_276_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_276_chunk TO inserter;


--
-- TOC entry 7525 (class 0 OID 0)
-- Dependencies: 323
-- Name: TABLE _hyper_1_27_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_27_chunk TO vliz_grafana;


--
-- TOC entry 7526 (class 0 OID 0)
-- Dependencies: 605
-- Name: TABLE _hyper_1_280_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_280_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_280_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_280_chunk TO inserter;


--
-- TOC entry 7527 (class 0 OID 0)
-- Dependencies: 608
-- Name: TABLE _hyper_1_283_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_283_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_283_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_1_283_chunk TO inserter;


--
-- TOC entry 7528 (class 0 OID 0)
-- Dependencies: 327
-- Name: TABLE _hyper_1_31_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_31_chunk TO vliz_grafana;


--
-- TOC entry 7529 (class 0 OID 0)
-- Dependencies: 334
-- Name: TABLE _hyper_1_33_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_33_chunk TO vliz_grafana;


--
-- TOC entry 7530 (class 0 OID 0)
-- Dependencies: 337
-- Name: TABLE _hyper_1_35_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_35_chunk TO vliz_grafana;


--
-- TOC entry 7531 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE _hyper_1_37_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_37_chunk TO vliz_grafana;


--
-- TOC entry 7532 (class 0 OID 0)
-- Dependencies: 342
-- Name: TABLE _hyper_1_39_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_39_chunk TO vliz_grafana;


--
-- TOC entry 7533 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE _hyper_1_41_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_41_chunk TO vliz_grafana;


--
-- TOC entry 7534 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE _hyper_1_43_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_43_chunk TO vliz_grafana;


--
-- TOC entry 7535 (class 0 OID 0)
-- Dependencies: 349
-- Name: TABLE _hyper_1_45_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_45_chunk TO vliz_grafana;


--
-- TOC entry 7536 (class 0 OID 0)
-- Dependencies: 354
-- Name: TABLE _hyper_1_47_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_47_chunk TO vliz_grafana;


--
-- TOC entry 7537 (class 0 OID 0)
-- Dependencies: 357
-- Name: TABLE _hyper_1_49_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_49_chunk TO vliz_grafana;


--
-- TOC entry 7538 (class 0 OID 0)
-- Dependencies: 361
-- Name: TABLE _hyper_1_53_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_53_chunk TO vliz_grafana;


--
-- TOC entry 7539 (class 0 OID 0)
-- Dependencies: 366
-- Name: TABLE _hyper_1_55_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_55_chunk TO vliz_grafana;


--
-- TOC entry 7540 (class 0 OID 0)
-- Dependencies: 368
-- Name: TABLE _hyper_1_57_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_57_chunk TO vliz_grafana;


--
-- TOC entry 7541 (class 0 OID 0)
-- Dependencies: 370
-- Name: TABLE _hyper_1_59_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_59_chunk TO vliz_grafana;


--
-- TOC entry 7542 (class 0 OID 0)
-- Dependencies: 372
-- Name: TABLE _hyper_1_61_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_61_chunk TO vliz_grafana;


--
-- TOC entry 7543 (class 0 OID 0)
-- Dependencies: 374
-- Name: TABLE _hyper_1_63_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_63_chunk TO vliz_grafana;


--
-- TOC entry 7544 (class 0 OID 0)
-- Dependencies: 377
-- Name: TABLE _hyper_1_65_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_65_chunk TO vliz_grafana;


--
-- TOC entry 7545 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE _hyper_1_87_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_87_chunk TO vliz_grafana;


--
-- TOC entry 7546 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE _hyper_1_90_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_90_chunk TO vliz_grafana;


--
-- TOC entry 7547 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE _hyper_1_94_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_94_chunk TO vliz_grafana;


--
-- TOC entry 7548 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE _hyper_1_97_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_97_chunk TO vliz_grafana;


--
-- TOC entry 7549 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE _hyper_1_9_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_1_9_chunk TO vliz_grafana;


--
-- TOC entry 7550 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE _hyper_2_101_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_101_chunk TO vliz_grafana;


--
-- TOC entry 7551 (class 0 OID 0)
-- Dependencies: 302
-- Name: TABLE _hyper_2_10_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_10_chunk TO vliz_grafana;


--
-- TOC entry 7552 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE _hyper_2_12_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_12_chunk TO vliz_grafana;


--
-- TOC entry 7553 (class 0 OID 0)
-- Dependencies: 452
-- Name: TABLE _hyper_2_149_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_149_chunk TO vliz_grafana;


--
-- TOC entry 7554 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE _hyper_2_14_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_14_chunk TO vliz_grafana;


--
-- TOC entry 7555 (class 0 OID 0)
-- Dependencies: 455
-- Name: TABLE _hyper_2_152_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_152_chunk TO vliz_grafana;


--
-- TOC entry 7556 (class 0 OID 0)
-- Dependencies: 458
-- Name: TABLE _hyper_2_155_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_155_chunk TO vliz_grafana;


--
-- TOC entry 7557 (class 0 OID 0)
-- Dependencies: 461
-- Name: TABLE _hyper_2_158_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_158_chunk TO vliz_grafana;


--
-- TOC entry 7558 (class 0 OID 0)
-- Dependencies: 464
-- Name: TABLE _hyper_2_161_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_161_chunk TO vliz_grafana;


--
-- TOC entry 7559 (class 0 OID 0)
-- Dependencies: 468
-- Name: TABLE _hyper_2_165_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_165_chunk TO vliz_grafana;


--
-- TOC entry 7560 (class 0 OID 0)
-- Dependencies: 471
-- Name: TABLE _hyper_2_168_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_168_chunk TO vliz_grafana;


--
-- TOC entry 7561 (class 0 OID 0)
-- Dependencies: 308
-- Name: TABLE _hyper_2_16_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_16_chunk TO vliz_grafana;


--
-- TOC entry 7562 (class 0 OID 0)
-- Dependencies: 476
-- Name: TABLE _hyper_2_173_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_173_chunk TO vliz_grafana;


--
-- TOC entry 7563 (class 0 OID 0)
-- Dependencies: 479
-- Name: TABLE _hyper_2_176_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_176_chunk TO vliz_grafana;


--
-- TOC entry 7564 (class 0 OID 0)
-- Dependencies: 482
-- Name: TABLE _hyper_2_179_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_179_chunk TO vliz_grafana;


--
-- TOC entry 7565 (class 0 OID 0)
-- Dependencies: 485
-- Name: TABLE _hyper_2_182_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_182_chunk TO vliz_grafana;


--
-- TOC entry 7566 (class 0 OID 0)
-- Dependencies: 488
-- Name: TABLE _hyper_2_185_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_185_chunk TO vliz_grafana;


--
-- TOC entry 7567 (class 0 OID 0)
-- Dependencies: 491
-- Name: TABLE _hyper_2_188_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_188_chunk TO vliz_grafana;


--
-- TOC entry 7568 (class 0 OID 0)
-- Dependencies: 310
-- Name: TABLE _hyper_2_18_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_18_chunk TO vliz_grafana;


--
-- TOC entry 7569 (class 0 OID 0)
-- Dependencies: 494
-- Name: TABLE _hyper_2_191_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_191_chunk TO vliz_grafana;


--
-- TOC entry 7570 (class 0 OID 0)
-- Dependencies: 496
-- Name: TABLE _hyper_2_193_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_193_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_193_chunk TO readaccess;


--
-- TOC entry 7571 (class 0 OID 0)
-- Dependencies: 499
-- Name: TABLE _hyper_2_196_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_196_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_196_chunk TO readaccess;


--
-- TOC entry 7572 (class 0 OID 0)
-- Dependencies: 512
-- Name: TABLE _hyper_2_199_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_199_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_199_chunk TO readaccess;


--
-- TOC entry 7573 (class 0 OID 0)
-- Dependencies: 517
-- Name: TABLE _hyper_2_204_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_204_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_204_chunk TO readaccess;


--
-- TOC entry 7574 (class 0 OID 0)
-- Dependencies: 520
-- Name: TABLE _hyper_2_207_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_207_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_207_chunk TO readaccess;


--
-- TOC entry 7575 (class 0 OID 0)
-- Dependencies: 315
-- Name: TABLE _hyper_2_20_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_20_chunk TO vliz_grafana;


--
-- TOC entry 7576 (class 0 OID 0)
-- Dependencies: 523
-- Name: TABLE _hyper_2_210_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_210_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_210_chunk TO readaccess;


--
-- TOC entry 7577 (class 0 OID 0)
-- Dependencies: 527
-- Name: TABLE _hyper_2_213_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_213_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_213_chunk TO readaccess;


--
-- TOC entry 7578 (class 0 OID 0)
-- Dependencies: 531
-- Name: TABLE _hyper_2_215_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_215_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_215_chunk TO readaccess;


--
-- TOC entry 7579 (class 0 OID 0)
-- Dependencies: 539
-- Name: TABLE _hyper_2_219_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_219_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_219_chunk TO readaccess;


--
-- TOC entry 7580 (class 0 OID 0)
-- Dependencies: 542
-- Name: TABLE _hyper_2_222_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_222_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_222_chunk TO readaccess;


--
-- TOC entry 7581 (class 0 OID 0)
-- Dependencies: 546
-- Name: TABLE _hyper_2_225_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_225_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_225_chunk TO readaccess;


--
-- TOC entry 7582 (class 0 OID 0)
-- Dependencies: 549
-- Name: TABLE _hyper_2_228_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_228_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_228_chunk TO readaccess;


--
-- TOC entry 7583 (class 0 OID 0)
-- Dependencies: 318
-- Name: TABLE _hyper_2_22_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_22_chunk TO vliz_grafana;


--
-- TOC entry 7584 (class 0 OID 0)
-- Dependencies: 552
-- Name: TABLE _hyper_2_231_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_231_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_231_chunk TO readaccess;


--
-- TOC entry 7585 (class 0 OID 0)
-- Dependencies: 557
-- Name: TABLE _hyper_2_236_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_236_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_236_chunk TO readaccess;


--
-- TOC entry 7586 (class 0 OID 0)
-- Dependencies: 565
-- Name: TABLE _hyper_2_240_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_240_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_240_chunk TO readaccess;


--
-- TOC entry 7587 (class 0 OID 0)
-- Dependencies: 568
-- Name: TABLE _hyper_2_243_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_243_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_243_chunk TO readaccess;


--
-- TOC entry 7588 (class 0 OID 0)
-- Dependencies: 571
-- Name: TABLE _hyper_2_246_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_246_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_246_chunk TO readaccess;


--
-- TOC entry 7589 (class 0 OID 0)
-- Dependencies: 574
-- Name: TABLE _hyper_2_249_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_249_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_249_chunk TO readaccess;


--
-- TOC entry 7590 (class 0 OID 0)
-- Dependencies: 320
-- Name: TABLE _hyper_2_24_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_24_chunk TO vliz_grafana;


--
-- TOC entry 7591 (class 0 OID 0)
-- Dependencies: 577
-- Name: TABLE _hyper_2_252_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_252_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_252_chunk TO readaccess;


--
-- TOC entry 7592 (class 0 OID 0)
-- Dependencies: 579
-- Name: TABLE _hyper_2_254_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_254_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_254_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_254_chunk TO inserter;


--
-- TOC entry 7593 (class 0 OID 0)
-- Dependencies: 583
-- Name: TABLE _hyper_2_258_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_258_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_258_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_258_chunk TO inserter;


--
-- TOC entry 7594 (class 0 OID 0)
-- Dependencies: 586
-- Name: TABLE _hyper_2_261_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_261_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_261_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_261_chunk TO inserter;


--
-- TOC entry 7595 (class 0 OID 0)
-- Dependencies: 588
-- Name: TABLE _hyper_2_263_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_263_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_263_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_263_chunk TO inserter;


--
-- TOC entry 7596 (class 0 OID 0)
-- Dependencies: 593
-- Name: TABLE _hyper_2_268_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_268_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_268_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_268_chunk TO inserter;


--
-- TOC entry 7597 (class 0 OID 0)
-- Dependencies: 322
-- Name: TABLE _hyper_2_26_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_26_chunk TO vliz_grafana;


--
-- TOC entry 7598 (class 0 OID 0)
-- Dependencies: 596
-- Name: TABLE _hyper_2_271_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_271_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_271_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_271_chunk TO inserter;


--
-- TOC entry 7599 (class 0 OID 0)
-- Dependencies: 599
-- Name: TABLE _hyper_2_274_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_274_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_274_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_274_chunk TO inserter;


--
-- TOC entry 7600 (class 0 OID 0)
-- Dependencies: 602
-- Name: TABLE _hyper_2_277_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_277_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_277_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_277_chunk TO inserter;


--
-- TOC entry 7601 (class 0 OID 0)
-- Dependencies: 606
-- Name: TABLE _hyper_2_281_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_281_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_281_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_281_chunk TO inserter;


--
-- TOC entry 7602 (class 0 OID 0)
-- Dependencies: 609
-- Name: TABLE _hyper_2_284_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_284_chunk TO vliz_grafana;
GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_284_chunk TO readaccess;
GRANT INSERT ON TABLE _timescaledb_internal._hyper_2_284_chunk TO inserter;


--
-- TOC entry 7603 (class 0 OID 0)
-- Dependencies: 324
-- Name: TABLE _hyper_2_28_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_28_chunk TO vliz_grafana;


--
-- TOC entry 7604 (class 0 OID 0)
-- Dependencies: 328
-- Name: TABLE _hyper_2_32_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_32_chunk TO vliz_grafana;


--
-- TOC entry 7605 (class 0 OID 0)
-- Dependencies: 335
-- Name: TABLE _hyper_2_34_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_34_chunk TO vliz_grafana;


--
-- TOC entry 7606 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE _hyper_2_36_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_36_chunk TO vliz_grafana;


--
-- TOC entry 7607 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE _hyper_2_38_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_38_chunk TO vliz_grafana;


--
-- TOC entry 7608 (class 0 OID 0)
-- Dependencies: 343
-- Name: TABLE _hyper_2_40_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_40_chunk TO vliz_grafana;


--
-- TOC entry 7609 (class 0 OID 0)
-- Dependencies: 345
-- Name: TABLE _hyper_2_42_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_42_chunk TO vliz_grafana;


--
-- TOC entry 7610 (class 0 OID 0)
-- Dependencies: 348
-- Name: TABLE _hyper_2_44_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_44_chunk TO vliz_grafana;


--
-- TOC entry 7611 (class 0 OID 0)
-- Dependencies: 350
-- Name: TABLE _hyper_2_46_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_46_chunk TO vliz_grafana;


--
-- TOC entry 7612 (class 0 OID 0)
-- Dependencies: 355
-- Name: TABLE _hyper_2_48_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_48_chunk TO vliz_grafana;


--
-- TOC entry 7613 (class 0 OID 0)
-- Dependencies: 358
-- Name: TABLE _hyper_2_50_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_50_chunk TO vliz_grafana;


--
-- TOC entry 7614 (class 0 OID 0)
-- Dependencies: 362
-- Name: TABLE _hyper_2_54_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_54_chunk TO vliz_grafana;


--
-- TOC entry 7615 (class 0 OID 0)
-- Dependencies: 367
-- Name: TABLE _hyper_2_56_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_56_chunk TO vliz_grafana;


--
-- TOC entry 7616 (class 0 OID 0)
-- Dependencies: 369
-- Name: TABLE _hyper_2_58_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_58_chunk TO vliz_grafana;


--
-- TOC entry 7617 (class 0 OID 0)
-- Dependencies: 371
-- Name: TABLE _hyper_2_60_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_60_chunk TO vliz_grafana;


--
-- TOC entry 7618 (class 0 OID 0)
-- Dependencies: 373
-- Name: TABLE _hyper_2_62_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_62_chunk TO vliz_grafana;


--
-- TOC entry 7619 (class 0 OID 0)
-- Dependencies: 375
-- Name: TABLE _hyper_2_64_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_64_chunk TO vliz_grafana;


--
-- TOC entry 7620 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE _hyper_2_66_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_66_chunk TO vliz_grafana;


--
-- TOC entry 7621 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE _hyper_2_88_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_88_chunk TO vliz_grafana;


--
-- TOC entry 7622 (class 0 OID 0)
-- Dependencies: 404
-- Name: TABLE _hyper_2_91_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_91_chunk TO vliz_grafana;


--
-- TOC entry 7623 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE _hyper_2_93_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_93_chunk TO vliz_grafana;


--
-- TOC entry 7624 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE _hyper_2_98_chunk; Type: ACL; Schema: _timescaledb_internal; Owner: vliz
--

GRANT SELECT ON TABLE _timescaledb_internal._hyper_2_98_chunk TO vliz_grafana;


--
-- TOC entry 7625 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE ais_num_to_type; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.ais_num_to_type TO vliz_grafana;
GRANT SELECT ON TABLE ais.ais_num_to_type TO readaccess;
GRANT INSERT ON TABLE ais.ais_num_to_type TO inserter;


--
-- TOC entry 7626 (class 0 OID 0)
-- Dependencies: 316
-- Name: TABLE aishub_primer_vessels; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.aishub_primer_vessels TO readaccess;
GRANT INSERT ON TABLE ais.aishub_primer_vessels TO inserter;


--
-- TOC entry 7627 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE ferry_cluster; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.ferry_cluster TO vliz_grafana;
GRANT SELECT ON TABLE ais.ferry_cluster TO readaccess;
GRANT INSERT ON TABLE ais.ferry_cluster TO inserter;


--
-- TOC entry 7628 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE mid_to_country; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.mid_to_country TO vliz_grafana;
GRANT SELECT ON TABLE ais.mid_to_country TO readaccess;
GRANT INSERT ON TABLE ais.mid_to_country TO inserter;


--
-- TOC entry 7629 (class 0 OID 0)
-- Dependencies: 311
-- Name: TABLE latest_vessel_details; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.latest_vessel_details TO readaccess;
GRANT INSERT ON TABLE ais.latest_vessel_details TO inserter;


--
-- TOC entry 7630 (class 0 OID 0)
-- Dependencies: 353
-- Name: TABLE latest_voy_reports; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.latest_voy_reports TO readaccess;
GRANT INSERT ON TABLE ais.latest_voy_reports TO inserter;


--
-- TOC entry 7631 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE nav_status; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.nav_status TO vliz_grafana;
GRANT SELECT ON TABLE ais.nav_status TO readaccess;
GRANT INSERT ON TABLE ais.nav_status TO inserter;


--
-- TOC entry 7632 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE pos_reports_1h_cagg; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.pos_reports_1h_cagg TO vliz_grafana;
GRANT SELECT ON TABLE ais.pos_reports_1h_cagg TO readaccess;
GRANT INSERT ON TABLE ais.pos_reports_1h_cagg TO inserter;


--
-- TOC entry 7633 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE oostend_traffic; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.oostend_traffic TO vliz_grafana;
GRANT SELECT ON TABLE ais.oostend_traffic TO readaccess;
GRANT INSERT ON TABLE ais.oostend_traffic TO inserter;


--
-- TOC entry 7635 (class 0 OID 0)
-- Dependencies: 351
-- Name: TABLE trajectories; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.trajectories TO readaccess;
GRANT INSERT ON TABLE ais.trajectories TO inserter;


--
-- TOC entry 7636 (class 0 OID 0)
-- Dependencies: 536
-- Name: TABLE vessel_density_agg; Type: ACL; Schema: ais; Owner: vliz
--

GRANT INSERT ON TABLE ais.vessel_density_agg TO inserter;


--
-- TOC entry 7637 (class 0 OID 0)
-- Dependencies: 312
-- Name: TABLE vessel_details; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.vessel_details TO readaccess;
GRANT INSERT ON TABLE ais.vessel_details TO inserter;


--
-- TOC entry 7639 (class 0 OID 0)
-- Dependencies: 530
-- Name: TABLE vessel_trajectories; Type: ACL; Schema: ais; Owner: vliz
--

GRANT INSERT ON TABLE ais.vessel_trajectories TO inserter;


--
-- TOC entry 7640 (class 0 OID 0)
-- Dependencies: 290
-- Name: TABLE voy_reports_6h_cagg; Type: ACL; Schema: ais; Owner: vliz
--

GRANT SELECT ON TABLE ais.voy_reports_6h_cagg TO vliz_grafana;
GRANT SELECT ON TABLE ais.voy_reports_6h_cagg TO readaccess;
GRANT INSERT ON TABLE ais.voy_reports_6h_cagg TO inserter;


--
-- TOC entry 7641 (class 0 OID 0)
-- Dependencies: 330
-- Name: TABLE admin_0_countries; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.admin_0_countries TO readaccess;


--
-- TOC entry 7643 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE eez_12nm; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.eez_12nm TO readaccess;


--
-- TOC entry 7645 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE eez_24nm; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.eez_24nm TO readaccess;


--
-- TOC entry 7647 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE eez_archipelagic_waters; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.eez_archipelagic_waters TO readaccess;


--
-- TOC entry 7649 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE eez_internal_waters; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.eez_internal_waters TO readaccess;


--
-- TOC entry 7651 (class 0 OID 0)
-- Dependencies: 352
-- Name: TABLE fishing_clusters; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.fishing_clusters TO readaccess;


--
-- TOC entry 7652 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE oceans_world; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.oceans_world TO readaccess;


--
-- TOC entry 7653 (class 0 OID 0)
-- Dependencies: 268
-- Name: TABLE world_eez; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.world_eez TO readaccess;


--
-- TOC entry 7654 (class 0 OID 0)
-- Dependencies: 331
-- Name: TABLE levels; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.levels TO readaccess;


--
-- TOC entry 7656 (class 0 OID 0)
-- Dependencies: 529
-- Name: TABLE maritime_boundaries; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.maritime_boundaries TO readaccess;


--
-- TOC entry 7657 (class 0 OID 0)
-- Dependencies: 535
-- Name: TABLE north_sea_hex_grid_1km2; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.north_sea_hex_grid_1km2 TO readaccess;


--
-- TOC entry 7659 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE sampaz; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.sampaz TO readaccess;


--
-- TOC entry 7663 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE world_port_index; Type: ACL; Schema: geo; Owner: vliz
--

GRANT SELECT ON TABLE geo.world_port_index TO readaccess;


--
-- TOC entry 7665 (class 0 OID 0)
-- Dependencies: 544
-- Name: TABLE vessel_density; Type: ACL; Schema: geoserver; Owner: vliz
--

GRANT SELECT ON TABLE geoserver.vessel_density TO read_user;
GRANT SELECT ON TABLE geoserver.vessel_density TO geoserver;


--
-- TOC entry 7666 (class 0 OID 0)
-- Dependencies: 356
-- Name: TABLE aoi_hex_grid_1km2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.aoi_hex_grid_1km2 TO readaccess;


--
-- TOC entry 7667 (class 0 OID 0)
-- Dependencies: 364
-- Name: TABLE agg_test_2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.agg_test_2 TO readaccess;


--
-- TOC entry 7668 (class 0 OID 0)
-- Dependencies: 365
-- Name: TABLE agg_test_3; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.agg_test_3 TO readaccess;


--
-- TOC entry 7669 (class 0 OID 0)
-- Dependencies: 376
-- Name: TABLE agg_test_4; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.agg_test_4 TO readaccess;


--
-- TOC entry 7670 (class 0 OID 0)
-- Dependencies: 405
-- Name: TABLE ais_agg_ver2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.ais_agg_ver2 TO readaccess;


--
-- TOC entry 7671 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE anchorage; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.anchorage TO readaccess;


--
-- TOC entry 7672 (class 0 OID 0)
-- Dependencies: 341
-- Name: TABLE aoi_hex_grid_100m2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.aoi_hex_grid_100m2 TO readaccess;


--
-- TOC entry 7673 (class 0 OID 0)
-- Dependencies: 333
-- Name: TABLE belgium_eez_bounding_box; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.belgium_eez_bounding_box TO readaccess;


--
-- TOC entry 7674 (class 0 OID 0)
-- Dependencies: 332
-- Name: TABLE belgium_hex_grid_001deg; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.belgium_hex_grid_001deg TO readaccess;


--
-- TOC entry 7675 (class 0 OID 0)
-- Dependencies: 346
-- Name: TABLE belgium_hex_grid_100m2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.belgium_hex_grid_100m2 TO readaccess;


--
-- TOC entry 7676 (class 0 OID 0)
-- Dependencies: 313
-- Name: TABLE belgium_hex_grid_1km2; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.belgium_hex_grid_1km2 TO readaccess;


--
-- TOC entry 7677 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE mt_pos; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.mt_pos TO readaccess;


--
-- TOC entry 7678 (class 0 OID 0)
-- Dependencies: 420
-- Name: TABLE clea; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.clea TO readaccess;


--
-- TOC entry 7679 (class 0 OID 0)
-- Dependencies: 363
-- Name: TABLE complex_ais_agg; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.complex_ais_agg TO readaccess;


--
-- TOC entry 7680 (class 0 OID 0)
-- Dependencies: 336
-- Name: TABLE daily_vessel_trajectory_w_breaks; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.daily_vessel_trajectory_w_breaks TO readaccess;


--
-- TOC entry 7681 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE mt_static3; Type: ACL; Schema: rory; Owner: vliz
--

GRANT SELECT ON TABLE rory.mt_static3 TO readaccess;


--
-- TOC entry 4839 (class 826 OID 17550756)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: geoserver; Owner: vliz
--

ALTER DEFAULT PRIVILEGES FOR ROLE vliz IN SCHEMA geoserver GRANT SELECT ON TABLES  TO read_user;
ALTER DEFAULT PRIVILEGES FOR ROLE vliz IN SCHEMA geoserver GRANT SELECT ON TABLES  TO geoserver;


-- Completed on 2023-03-21 11:36:24 EDT

--
-- PostgreSQL database dump complete
--

