--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5
-- Dumped by pg_dump version 12.2

-- Started on 2021-08-03 10:38:33 UTC

-- SET statement_timeout = 0;
-- SET lock_timeout = 0;
-- SET idle_in_transaction_session_timeout = 0;
-- SET client_encoding = 'UTF8';
-- SET standard_conforming_strings = on;
-- -- SELECT pg_catalog.set_config('search_path', '', false);
-- SET check_function_bodies = false;
-- SET xmloption = content;
-- SET client_min_messages = warning;
-- SET row_security = off;

--
-- TOC entry 14 (class 2615 OID 16386)
-- Name: ais; Type: SCHEMA; Schema: -; Owner: rory
--

CREATE SCHEMA ais;

--RAISE NOTICE 'Creating PostGIS Extenstion';
CREATE EXTENSION IF NOT EXISTS postgis;

--RAISE NOTICE 'Creating TimescaleDB Extenstion';
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ALTER SCHEMA ais OWNER TO rory;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 256 (class 1259 OID 18500)
-- Name: pos_reports; Type: TABLE; Schema: ais; Owner: rory
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
);

SELECT create_hypertable('ais.pos_reports', 'event_time');


-- ALTER TABLE ais.pos_reports OWNER TO rory;

--
-- TOC entry 257 (class 1259 OID 18510)
-- Name: voy_reports; Type: TABLE; Schema: ais; Owner: rory
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

SELECT create_hypertable('ais.voy_reports', 'event_time');


-- ALTER TABLE ais.voy_reports OWNER TO rory;

--
-- TOC entry 258 (class 1259 OID 18519)
-- Name: ais_num_to_type; Type: TABLE; Schema: ais; Owner: rory
--

CREATE TABLE ais.ais_num_to_type (
    ais_num character varying(3) NOT NULL,
    description text,
    type text,
    sub_type text,
    abrv character varying(3) NOT NULL
);


-- ALTER TABLE ais.ais_num_to_type OWNER TO rory;

--
-- TOC entry 271 (class 1259 OID 19795)
-- Name: hourly_pos_cagg; Type: VIEW; Schema: ais; Owner: rory
--

DROP MATERIALIZED VIEW IF EXISTS ais.vessel_details_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.vessel_details_cagg WITH
(timescaledb.continuous )
AS
SELECT 
	mmsi,
	time_bucket('1d', event_time) as bucket,
	last(imo, event_time) as imo,
	last(callsign, event_time) as callsign,
	last(name, event_time) as name,
	last(type_and_cargo, event_time) as type_and_cargo,
	last(to_bow, event_time) as to_bow,
	last(to_stern, event_time) as to_stern,
	last(to_port, event_time) as to_port,
	last(to_starboard, event_time) as to_starboard,
	last(fix_type, event_time) as fix_type,
	last(eta_month, event_time) as eta_month,
	last(eta_day, event_time) as eta_day,
	last(eta_hour, event_time) as eta_hour,
	last(eta_minute, event_time) as eta_minute,
	last(eta, event_time) as eta,
	last(draught, event_time) as draught,
	last(destination, event_time) as destination,
	last(event_time, event_time) as event_time,
	last(msg_type, event_time) as msg_type,
	last(routing_key, event_time) as routing_key
FROM ais.voy_reports
GROUP BY mmsi, bucket, routing_key WITH NO DATA;

SELECT add_continuous_aggregate_policy('ais.vessel_details_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 h',
    schedule_interval => INTERVAL '1 h');

DROP MATERIALIZED VIEW IF EXISTS ais.hourly_pos_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.hourly_pos_cagg WITH
(timescaledb.continuous )
AS
 SELECT pos_reports.mmsi,
    time_bucket('00:30:00'::interval, pos_reports.event_time) AS bucket,
    last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    last(pos_reports."position", pos_reports.event_time) AS "position",
    last(pos_reports.cog, pos_reports.event_time) AS cog,
    last(pos_reports.sog, pos_reports.event_time) AS sog,
    last(pos_reports.navigation_status, pos_reports.event_time) AS nav_status,    
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, bucket WITH NO DATA;

SELECT add_continuous_aggregate_policy('ais.hourly_pos_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '30 minutes',
    schedule_interval => INTERVAL '30 minutes');

DROP MATERIALIZED VIEW IF EXISTS ais.daily_pos_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.daily_pos_cagg WITH
(timescaledb.continuous )
AS
   SELECT pos_reports.mmsi,
    time_bucket('12h'::interval, pos_reports.event_time) AS bucket,
    last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    last(pos_reports."position", pos_reports.event_time) AS "position",
    last(pos_reports.cog, pos_reports.event_time) AS cog,
    last(pos_reports.sog, pos_reports.event_time) AS sog,
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, bucket WITH NO DATA;

SELECT add_continuous_aggregate_policy('ais.daily_pos_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '30 minutes',
    schedule_interval => INTERVAL '30 minutes');
 

CREATE TABLE ais.mid_to_country (
    country text NOT NULL,
    country_abrv0 text,
    country_abrv1 text,
    country_abrv2 text,
    mid character varying(3) NOT NULL,
    flag_link text
);
 

CREATE MATERIALIZED VIEW ais.ship_details_agg AS
 SELECT DISTINCT ON (ais_ship_details_locf_ts.mmsi, ais_ship_details_locf_ts.imo, ais_ship_details_locf_ts.name, ais_ship_details_locf_ts.callsign) ais_ship_details_locf_ts.mmsi,
    ais_ship_details_locf_ts.imo,
    ais_ship_details_locf_ts.name,
    ais_ship_details_locf_ts.callsign,
    ais_ship_details_locf_ts.to_bow,
    ais_ship_details_locf_ts.to_stern,
    ais_ship_details_locf_ts.to_port,
    ais_ship_details_locf_ts.to_starboard,
    ais_ship_details_locf_ts.type_and_cargo,
    num.description AS type_and_cargo_text,
    mid.country AS flag_state,
    ais_ship_details_locf_ts.routing_key,
    ais_ship_details_locf_ts.event_time
   FROM ((ais.vessel_details_cagg ais_ship_details_locf_ts
     LEFT JOIN ais.ais_num_to_type num ON (((num.ais_num)::text = (ais_ship_details_locf_ts.type_and_cargo)::text)))
     LEFT JOIN ais.mid_to_country mid ON (("left"(ais_ship_details_locf_ts.mmsi, 3) = (mid.mid)::text)))
  ORDER BY ais_ship_details_locf_ts.mmsi, ais_ship_details_locf_ts.imo, ais_ship_details_locf_ts.name, ais_ship_details_locf_ts.callsign, ais_ship_details_locf_ts.event_time DESC
  WITH NO DATA;


-- ALTER TABLE ais.ship_details_agg OWNER TO rory;

--
-- TOC entry 575 (class 1259 OID 273246)
-- Name: vessel_traj_4h_gaps_2020; Type: MATERIALIZED VIEW; Schema: ais; Owner: rory
--

CREATE MATERIALIZED VIEW ais.vessel_traj_4h_gaps_2020 AS
 WITH ais_data AS (
         SELECT aa.mmsi,
            aa.event_time,
            aa.longitude,
            aa.latitude,
            (lag(aa.event_time) OVER (PARTITION BY aa.mmsi ORDER BY aa.event_time) <= (aa.event_time - '04:00:00'::interval)) AS step
           FROM ais.hourly_pos_cagg aa
          WHERE ((aa.bucket >= '2020-01-01 00:00:00+00'::timestamp with time zone) AND (aa.bucket <= '2021-01-01 00:00:00+00'::timestamp with time zone))
        ), time_groups AS (
         SELECT bb.mmsi,
            bb.event_time,
            bb.longitude,
            bb.latitude,
            count(*) FILTER (WHERE bb.step) OVER (PARTITION BY bb.mmsi ORDER BY bb.event_time) AS time_group
           FROM ais_data bb
        )
 SELECT cc.mmsi,
    cc.time_group,
    date(cc.event_time) AS date,
    public.st_makeline(public.st_makepointm(cc.longitude, cc.latitude, date_part('epoch'::text, cc.event_time)) ORDER BY cc.event_time) AS traj,
    public.first(cc.event_time, cc.event_time) AS traj_start,
    public.last(cc.event_time, cc.event_time) AS traj_end
   FROM time_groups cc
  GROUP BY cc.mmsi, cc.time_group, (date(cc.event_time))
  WITH NO DATA;

  

CREATE TABLE ais.nav_status (
    nav_status text,
    description text
);


-- ALTER TABLE ais.nav_status OWNER TO rory;

--
-- TOC entry 306 (class 1259 OID 21804)
-- Name: port_history; Type: VIEW; Schema: ais; Owner: rory
--

-- CREATE VIEW ais.port_history AS
--  SELECT port.port_name,
--     ais.mmsi,
--     ais.sog,
--     ais.event_time
--    FROM (geo.world_port_index port
--      JOIN ais.daily_pos_cagg ais ON ((public.st_dwithin(public.st_setsrid(port.geom, 4326), ais."position", (0.2)::double precision) AND (ais.sog < (5)::numeric))))
--   ORDER BY ais.event_time;

     
-- CREATE INDEX pos_reports_event_time_idx ON ais.pos_reports USING btree (event_time DESC);

 

CREATE INDEX pos_reports_mmsi_event_time_idx ON ais.pos_reports USING btree (mmsi, event_time DESC);

 

CREATE INDEX pos_reports_position_idx ON ais.pos_reports USING gist ("position");

 
CREATE INDEX ship_details_agg_mmsi_ix ON ais.ship_details_agg USING btree (mmsi, name);

 

COMMENT ON INDEX ais.ship_details_agg_mmsi_ix IS 'MMSI index';
 

CREATE INDEX vessel_traj_4h_gaps_2020_mmsi_date_idx ON ais.vessel_traj_4h_gaps_2020 USING btree (mmsi, date DESC);
 

CREATE INDEX vessel_traj_4h_gaps_2020_traj_idx ON ais.vessel_traj_4h_gaps_2020 USING gist (traj);

 

-- CREATE INDEX voy_reports_event_time_idx ON ais.voy_reports USING btree (event_time DESC);
 

CREATE INDEX voy_reports_mmsi_event_time_idx ON ais.voy_reports USING btree (mmsi, event_time DESC);
 

-- CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');

 

-- CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');

 

-- CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();
 

-- CREATE TRIGGER ts_insert 

CREATE ROLE api_user nologin;
-- CREATE ROLE ocims WITH encrypted password 'ocims';
CREATE ROLE inserter WITH encrypted password 'mypassword';

GRANT USAGE ON SCHEMA ais TO api_user;
GRANT USAGE ON SCHEMA ais TO postgisftw;
GRANT USAGE ON SCHEMA ais TO inserter;


--
-- TOC entry 6754 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE pos_reports; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.pos_reports TO api_user;
GRANT SELECT ON TABLE ais.pos_reports TO postgisftw;
GRANT INSERT ON TABLE ais.pos_reports TO inserter;


--
-- TOC entry 6755 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE voy_reports; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.voy_reports TO api_user;
GRANT SELECT ON TABLE ais.voy_reports TO postgisftw;
GRANT INSERT ON TABLE ais.voy_reports TO inserter;


--
-- TOC entry 6756 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE ais_num_to_type; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.ais_num_to_type TO api_user;
GRANT SELECT ON TABLE ais.ais_num_to_type TO postgisftw;


--
-- TOC entry 6757 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE hourly_pos_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.hourly_pos_cagg TO api_user;
GRANT SELECT ON TABLE ais.hourly_pos_cagg TO postgisftw;


--
-- TOC entry 6758 (class 0 OID 0)
-- Dependencies: 549
-- Name: TABLE ais_traj_2020; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.ais_traj_2020 TO api_user;
GRANT SELECT ON TABLE ais.ais_traj_2020 TO postgisftw;


--
-- TOC entry 6759 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE daily_pos_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.daily_pos_cagg TO api_user;
GRANT SELECT ON TABLE ais.daily_pos_cagg TO postgisftw;


--
-- TOC entry 6760 (class 0 OID 0)
-- Dependencies: 314
-- Name: TABLE data_sources_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.data_sources_cagg TO api_user;
GRANT SELECT ON TABLE ais.data_sources_cagg TO postgisftw;


--
-- TOC entry 6761 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE mid_to_country; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.mid_to_country TO api_user;
GRANT SELECT ON TABLE ais.mid_to_country TO postgisftw;


--
-- TOC entry 6762 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE vessel_details_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.vessel_details_cagg TO api_user;
GRANT SELECT ON TABLE ais.vessel_details_cagg TO postgisftw;


--
-- TOC entry 6763 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE ship_details_agg; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.ship_details_agg TO api_user;
GRANT SELECT ON TABLE ais.ship_details_agg TO postgisftw;


--
-- TOC entry 6764 (class 0 OID 0)
-- Dependencies: 575
-- Name: TABLE vessel_traj_4h_gaps_2020; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.vessel_traj_4h_gaps_2020 TO api_user;
GRANT SELECT ON TABLE ais.vessel_traj_4h_gaps_2020 TO postgisftw;


--
-- TOC entry 6765 (class 0 OID 0)
-- Dependencies: 576
-- Name: TABLE martin_query; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.martin_query TO api_user;


--
-- TOC entry 6766 (class 0 OID 0)
-- Dependencies: 577
-- Name: TABLE martin_query_sizes; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.martin_query_sizes TO api_user;


--
-- TOC entry 6767 (class 0 OID 0)
-- Dependencies: 578
-- Name: TABLE martin_query_sizes_class; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.martin_query_sizes_class TO api_user;


--
-- TOC entry 6768 (class 0 OID 0)
-- Dependencies: 628
-- Name: TABLE martin_query_sizes_class_flag_100nm; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.martin_query_sizes_class_flag_100nm TO api_user;


--
-- TOC entry 6769 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE nav_status; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.nav_status TO api_user;
GRANT SELECT ON TABLE ais.nav_status TO postgisftw;


--
-- TOC entry 6770 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE port_history; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.port_history TO api_user;
GRANT SELECT ON TABLE ais.port_history TO postgisftw;


--
-- TOC entry 6771 (class 0 OID 0)
-- Dependencies: 562
-- Name: TABLE pos_reports_30min_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.pos_reports_30min_cagg TO api_user;
GRANT SELECT ON TABLE ais.pos_reports_30min_cagg TO postgisftw;


--
-- TOC entry 6772 (class 0 OID 0)
-- Dependencies: 657
-- Name: TABLE pos_reports_30min_dist_cagg; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.pos_reports_30min_dist_cagg TO api_user;


--
-- TOC entry 6773 (class 0 OID 0)
-- Dependencies: 622
-- Name: TABLE pos_reports_source_counter; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.pos_reports_source_counter TO api_user;


--
-- TOC entry 6774 (class 0 OID 0)
-- Dependencies: 644
-- Name: TABLE storm_trajectory; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.storm_trajectory TO api_user;


--
-- TOC entry 6775 (class 0 OID 0)
-- Dependencies: 565
-- Name: TABLE traj_testing; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.traj_testing TO api_user;
GRANT SELECT ON TABLE ais.traj_testing TO postgisftw;


--
-- TOC entry 6776 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE vessel_trajectory; Type: ACL; Schema: ais; Owner: rory
--

GRANT ALL ON TABLE ais.vessel_trajectory TO api_user;
GRANT SELECT ON TABLE ais.vessel_trajectory TO postgisftw;


--
-- TOC entry 6777 (class 0 OID 0)
-- Dependencies: 643
-- Name: TABLE vessel_trajectory_2021_06_28; Type: ACL; Schema: ais; Owner: rory
--

GRANT SELECT ON TABLE ais.vessel_trajectory_2021_06_28 TO api_user;


--
-- TOC entry 5327 (class 826 OID 138530)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ais; Owner: rory
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE rory IN SCHEMA ais REVOKE ALL ON TABLES  FROM rory;
-- ALTER DEFAULT PRIVILEGES FOR ROLE rory IN SCHEMA ais GRANT SELECT ON TABLES  TO api_user;


-- Completed on 2021-08-03 10:38:33 UTC

--
-- PostgreSQL database dump complete
--

