--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3 (Debian 13.3-1.pgdg100+1)
-- Dumped by pg_dump version 16.2 (Ubuntu 16.2-1.pgdg22.04+1)

-- Position Reports table hold all AIS position reports
-- and extend it with TSDB "hypertable"
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
COMMENT ON TABLE ais.pos_reports IS 'Hypertable to store AIS position reports for Class A and B TRx.';
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
COMMENT ON TABLE ais.voy_reports IS 'Hypertable to store AIS voyage reports for Class A and B TRx.';

--
-- Name: ais_num_to_type; Type: TABLE; Schema: ais; Owner: vliz
--

-- CREATE TABLE ais.ais_num_to_type (
--     ais_num character varying(3) NOT NULL,
--     description text,
--     type text,
--     sub_type text,
--     abrv character varying(3) NOT NULL
-- );
-- COMMENT ON TABLE ais.ais_num_to_type IS 'Lookup table to store AIS Type and Cargo definitions for 2 digit AIS number code.';

-- --
-- -- Name: mid_to_country; Type: TABLE; Schema: ais; Owner: vliz
-- --

-- CREATE TABLE ais.mid_to_country (
--     country text NOT NULL,
--     country_abrv0 text,
--     country_abrv1 text,
--     country_abrv2 text,
--     mid character varying(3) NOT NULL,
--     flag_link text
-- );
-- COMMENT ON TABLE ais.mid_to_country IS 'Lookup table to store MID Country Code, from first 3 digits of MMSI.';
-- --
-- -- Name: latest_voy_reports; Type: TABLE; Schema: ais; Owner: vliz
-- --

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
    routing_key text,
    CONSTRAINT mmsi_rkey UNIQUE (mmsi, routing_key));
COMMENT ON TABLE ais.latest_voy_reports IS 'Summary table for the latest voyage report, per mmsi, per routing key.';

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
COMMENT ON TABLE ais.trajectories IS 'Derived trajectories for vessels. AIS points are grouped by MMSI but split by gaps in time (greater than 1 hour), jumps in distance, or gaps in distance (greater than 0.1 deg), or where calculated speed is too great (from duplicate MMSI''s). Calculated using stored procedure is ais.build_trajectories(integer, jsonb)';

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
COMMENT ON TABLE ais.vessel_density_agg IS 'Derived vessel density aggregate';