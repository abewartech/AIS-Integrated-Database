-----------------------------------------------------------------------
-- The user and DB is handled by the docker environment variables
--BEGIN;
--CREATE USER oceanmapper with encrypted password 'ocean_pw';
--COMMIT;


-----------------------------------------------------------------------

BEGIN;
--RAISE NOTICE 'Creating PostGIS Extenstion';
CREATE EXTENSION postgis;

-- geo schema will hold spatial data like eez, mpa etc
-- that gets loaded from shapefiles from the .sh script that gets called
-- after this one.
CREATE SCHEMA geo;
-- ais schema holds ais data in the same format as previously
CREATE SCHEMA ais;

-- Create trigger to auto-partition the table's
CREATE FUNCTION ais.create_partition_and_insert()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF 
AS $BODY$
    DECLARE
      partition_date TEXT;
      partition TEXT;
    BEGIN
      partition_date := to_char(NEW.event_time,'YYYY_MM');
      partition := TG_RELNAME || '_' || partition_date;
      IF NOT EXISTS(SELECT relname FROM pg_class WHERE relname=partition) THEN
        RAISE NOTICE 'A new partition is being created %',partition;
        EXECUTE 'CREATE TABLE ' || partition || ' (check (EXTRACT(MONTH FROM event_time) = EXTRACT(MONTH FROM TIMESTAMP ''' || NEW.event_time || ''')), 
        check (EXTRACT(YEAR FROM event_time) = EXTRACT(YEAR FROM TIMESTAMP ''' || NEW.event_time || '''))) INHERITS (' || TG_RELNAME || ');';
      END IF;
      EXECUTE 'INSERT INTO ' || partition || ' SELECT(' || TG_RELNAME || ' ' || quote_literal(NEW) || ').* RETURNING id;';
      RETURN NULL;
    END;
$BODY$;

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
    routing_key text COLLATE pg_catalog."default",
    id serial PRIMARY KEY
);
CREATE INDEX ais_ves_pos
    ON ais.pos_reports USING gist
    (position);
CREATE INDEX pos_reports_event_time
    ON ais.pos_reports USING btree
    (event_time);
CREATE INDEX pos_report_mmsi_idx
    ON ais.pos_reports USING btree
    (mmsi COLLATE pg_catalog."default");

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
    routing_key text COLLATE pg_catalog."default",
    id serial PRIMARY KEY
);
CREATE INDEX voyage_report_event_time_idx
    ON ais.voy_reports USING btree
    (event_time);
 
CREATE INDEX voyage_report_mmsi_idx
    ON ais.voy_reports USING btree
    (mmsi COLLATE pg_catalog."default");
    
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

-- CREATE TABLE geo.world_10km_grid AS
-- SELECT *
-- FROM ST_CreateFishnet(3600, 1800, 0.01, 0.01,-180,-90) AS cells;

COMMIT;

-----------------------------------------------------------------------
-- Need to index that grid so I don't cry later.
--RAISE NOTICE 'Building Index on grid';


--CREATE INDEX grid_10km_index_geom
--    ON geo.world_10km_grid USING gist
--    (geom);


