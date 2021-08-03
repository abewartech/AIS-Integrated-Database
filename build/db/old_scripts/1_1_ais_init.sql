-----------------------------------------------------------------------
-- The user and DB is handled by the docker environment variables
--BEGIN;
--CREATE USER oceanmapper with encrypted password 'ocean_pw';
--COMMIT;


-----------------------------------------------------------------------

BEGIN;

-- ais schema holds ais data in the same format as previously
CREATE SCHEMA ais;

--RAISE NOTICE 'Creating PostGIS Extenstion';
CREATE EXTENSION IF NOT EXISTS postgis;

--RAISE NOTICE 'Creating TimescaleDB Extenstion';
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- pos_reports holds AIS position reports
CREATE TABLE ais.pos_reports
(
    mmsi text COLLATE pg_catalog."default" NOT NULL,
    navigation_status character varying(3) COLLATE pg_catalog."default",
    rot smallint,
    sog numeric(4, 1),
    longitude double precision NOT NULL,
    latitude double precision NOT NULL,
    "position" geometry,
    cog numeric(4, 1),
    hdg numeric(4, 1),
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    msg_type character varying(3) COLLATE pg_catalog."default", 
    routing_key text COLLATE pg_catalog."default"
    -- id serial PRIMARY KEY -- For some reason TimescaleDB doesn't like having primary keys in the hypertable. Luckily we don't really use it anyway...
);

SELECT create_hypertable('ais.pos_reports', 'event_time');

-- How to index a hypertable 
-- https://docs.timescale.com/latest/using-timescaledb/schema-management#indexing

CREATE INDEX ON ais.pos_reports (mmsi, event_time desc);

CREATE INDEX ON ais.pos_reports USING GIST(position);

-----------------------------------------------------------------------------------
-- voy_reports holds AIS position reports
CREATE TABLE ais.voy_reports
(
    mmsi text COLLATE pg_catalog."default" NOT NULL,
    imo text COLLATE pg_catalog."default",
    callsign text COLLATE pg_catalog."default",
    name text COLLATE pg_catalog."default", 
    type_and_cargo character varying(3) COLLATE pg_catalog."default",
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
    draught numeric(4, 1),
    destination text COLLATE pg_catalog."default",
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    msg_type character varying(3) COLLATE pg_catalog."default", 
    routing_key text COLLATE pg_catalog."default"
    -- id serial PRIMARY KEY
);

SELECT create_hypertable('ais.voy_reports', 'event_time');

CREATE INDEX ON ais.voy_reports (mmsi, event_time desc);

COMMIT;
-----------------------------------------------------------------------
-- Load some AIS helper tables from CSV's
BEGIN;
CREATE TABLE ais.ais_num_to_type
(
    ais_num character varying(3) COLLATE pg_catalog."default" NOT NULL,
    description text COLLATE pg_catalog."default",
    type text COLLATE pg_catalog."default",
    sub_type text COLLATE pg_catalog."default",
    abrv character varying(3) COLLATE pg_catalog."default" NOT NULL
);

COPY ais.ais_num_to_type (ais_num, description, type, sub_type, abrv)
FROM '/tmp/ais_nums.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE ais.nav_status
(
    nav_status text COLLATE pg_catalog."default",
    description text COLLATE pg_catalog."default"
);
COPY ais.nav_status (nav_status, description)
FROM '/tmp/nav_status.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE ais.mid_to_country
(
    country text COLLATE pg_catalog."default" NOT NULL,
    country_abrv0 text COLLATE pg_catalog."default",
    country_abrv1 text COLLATE pg_catalog."default",
    country_abrv2 text COLLATE pg_catalog."default",
    mid character varying(3) COLLATE pg_catalog."default" NOT NULL,
    flag_link text COLLATE pg_catalog."default"    
);
COPY ais.mid_to_country (mid, country_abrv0, country_abrv1, country_abrv2, country, flag_link)
FROM '/tmp/mids.csv' DELIMITER ',' CSV HEADER;

--mid,country_abrv0,country_abrv1,country_abrv2,country,flag_link
--201,AL,ALB,,Albania,

COMMIT;
 




