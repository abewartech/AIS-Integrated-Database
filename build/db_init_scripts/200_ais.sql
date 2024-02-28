--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3 (Debian 13.3-1.pgdg100+1)
-- Dumped by pg_dump version 16.2 (Ubuntu 16.2-1.pgdg22.04+1)

-- Position Reports table hold all AIS position reports
-- and extend it with TSDB "hypertable"
CREATE TABLE ais.pos_reports (
    mmsi text NOT NULL,
    navigation_status text,
    rot smallint,
    sog numeric(4,1),
    longitude double precision NOT NULL,
    latitude double precision NOT NULL,
    --  public.geometry,
    "position" geometry(Point, 4326),
    cog numeric(4,1),
    hdg numeric(4,1),
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    msg_type text,
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
    type_and_cargo text,
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
    msg_type text,
    routing_key text
);

SELECT create_hypertable('ais.voy_reports', 'event_time');
COMMENT ON TABLE ais.voy_reports IS 'Hypertable to store AIS voyage reports for Class A and B TRx.';

CREATE TABLE ais.latest_voy_reports (
    mmsi text,
    imo text,
    callsign text,
    name text,
    type_and_cargo text,
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
    msg_type text,
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
    type_and_cargo text,
    cardinal_seg numeric,
    sog_bin numeric,
    track_count bigint,
    avg_time_delta double precision,
    cum_time_in_grid double precision
);
COMMENT ON TABLE ais.vessel_density_agg IS 'Derived vessel density aggregate';
