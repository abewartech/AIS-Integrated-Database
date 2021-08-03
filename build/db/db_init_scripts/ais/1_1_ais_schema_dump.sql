PGDMP     #         
            y            vessels    12.5    12.2 F    ^           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            _           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            `           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            a           1262    16384    vessels    DATABASE     w   CREATE DATABASE vessels WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8';
    DROP DATABASE vessels;
                rory    false            b           0    0    DATABASE vessels    ACL     `   GRANT CONNECT ON DATABASE vessels TO api_user;
GRANT CONNECT ON DATABASE vessels TO postgisftw;
                   rory    false    6753                        2615    16386    ais    SCHEMA        CREATE SCHEMA ais;
    DROP SCHEMA ais;
                rory    false            c           0    0 
   SCHEMA ais    ACL     w   GRANT USAGE ON SCHEMA ais TO api_user;
GRANT USAGE ON SCHEMA ais TO postgisftw;
GRANT USAGE ON SCHEMA ais TO inserter;
                   rory    false    14                        1259    18500    pos_reports    TABLE     �  CREATE TABLE ais.pos_reports (
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
    DROP TABLE ais.pos_reports;
       ais         heap    rory    false    14            d           0    0    TABLE pos_reports    ACL     �   GRANT ALL ON TABLE ais.pos_reports TO api_user;
GRANT SELECT ON TABLE ais.pos_reports TO postgisftw;
GRANT INSERT ON TABLE ais.pos_reports TO inserter;
          ais          rory    false    256                       1259    18510    voy_reports    TABLE     T  CREATE TABLE ais.voy_reports (
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
    DROP TABLE ais.voy_reports;
       ais         heap    rory    false    14            e           0    0    TABLE voy_reports    ACL     �   GRANT ALL ON TABLE ais.voy_reports TO api_user;
GRANT SELECT ON TABLE ais.voy_reports TO postgisftw;
GRANT INSERT ON TABLE ais.voy_reports TO inserter;
          ais          rory    false    257                       1259    18519    ais_num_to_type    TABLE     �   CREATE TABLE ais.ais_num_to_type (
    ais_num character varying(3) NOT NULL,
    description text,
    type text,
    sub_type text,
    abrv character varying(3) NOT NULL
);
     DROP TABLE ais.ais_num_to_type;
       ais         heap    rory    false    14            f           0    0    TABLE ais_num_to_type    ACL     m   GRANT ALL ON TABLE ais.ais_num_to_type TO api_user;
GRANT SELECT ON TABLE ais.ais_num_to_type TO postgisftw;
          ais          rory    false    258                       1259    19795    hourly_pos_cagg    VIEW     �  CREATE VIEW ais.hourly_pos_cagg AS
 SELECT _materialized_hypertable_4.mmsi,
    _materialized_hypertable_4.bucket,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_3_3, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_4_4, NULL::double precision) AS longitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_5_5, NULL::double precision) AS latitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_6_6, NULL::public.geometry) AS "position",
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_7_7, NULL::numeric) AS cog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_8_8, NULL::numeric) AS sog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_4.agg_9_9, NULL::character varying) AS nav_status,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_10_10, NULL::numeric) AS avg_cog,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_11_11, NULL::numeric) AS avg_sog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_12_12, NULL::numeric) AS max_cog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_13_13, NULL::numeric) AS max_sog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_14_14, NULL::numeric) AS min_cog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_4.agg_15_15, NULL::numeric) AS min_sog
   FROM _timescaledb_internal._materialized_hypertable_4
  WHERE (_materialized_hypertable_4.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(4)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_4.mmsi, _materialized_hypertable_4.bucket
UNION ALL
 SELECT pos_reports.mmsi,
    public.time_bucket('00:30:00'::interval, pos_reports.event_time) AS bucket,
    public.last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    public.last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    public.last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    public.last(pos_reports."position", pos_reports.event_time) AS "position",
    public.last(pos_reports.cog, pos_reports.event_time) AS cog,
    public.last(pos_reports.sog, pos_reports.event_time) AS sog,
    public.last(pos_reports.navigation_status, pos_reports.event_time) AS nav_status,
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  WHERE (pos_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(4)), '-infinity'::timestamp with time zone))
  GROUP BY pos_reports.mmsi, (public.time_bucket('00:30:00'::interval, pos_reports.event_time));
    DROP VIEW ais.hourly_pos_cagg;
       ais          rory    false    256    256    256    256    256    256    256    256    14            g           0    0    TABLE hourly_pos_cagg    ACL     m   GRANT ALL ON TABLE ais.hourly_pos_cagg TO api_user;
GRANT SELECT ON TABLE ais.hourly_pos_cagg TO postgisftw;
          ais          rory    false    271            %           1259    146451    ais_traj_2020    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.ais_traj_2020 AS
 SELECT hourly_pos_cagg.mmsi,
    public.st_makeline(hourly_pos_cagg."position" ORDER BY hourly_pos_cagg.bucket) AS st_makeline
   FROM ais.hourly_pos_cagg
  WHERE (((hourly_pos_cagg.bucket >= '2020-01-01 00:00:00+00'::timestamp with time zone) AND (hourly_pos_cagg.bucket <= '2020-02-01 00:00:00+00'::timestamp with time zone)) AND (hourly_pos_cagg.mmsi <> '0'::text))
  GROUP BY hourly_pos_cagg.mmsi
  WITH NO DATA;
 *   DROP MATERIALIZED VIEW ais.ais_traj_2020;
       ais         heap    rory    false    271    271    271    14            h           0    0    TABLE ais_traj_2020    ACL     l   GRANT SELECT ON TABLE ais.ais_traj_2020 TO api_user;
GRANT SELECT ON TABLE ais.ais_traj_2020 TO postgisftw;
          ais          rory    false    549                       1259    19820    daily_pos_cagg    VIEW     I  CREATE VIEW ais.daily_pos_cagg AS
 SELECT _materialized_hypertable_5.mmsi,
    _materialized_hypertable_5.day,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_3_3, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_4_4, NULL::double precision) AS longitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_5_5, NULL::double precision) AS latitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_6_6, NULL::public.geometry) AS "position",
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_7_7, NULL::numeric) AS cog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_5.agg_8_8, NULL::numeric) AS sog,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_9_9, NULL::numeric) AS avg_cog,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_10_10, NULL::numeric) AS avg_sog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_11_11, NULL::numeric) AS max_cog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_12_12, NULL::numeric) AS max_sog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_13_13, NULL::numeric) AS min_cog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], _materialized_hypertable_5.agg_14_14, NULL::numeric) AS min_sog
   FROM _timescaledb_internal._materialized_hypertable_5
  WHERE (_materialized_hypertable_5.day < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(5)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_5.mmsi, _materialized_hypertable_5.day
UNION ALL
 SELECT pos_reports.mmsi,
    public.time_bucket('12:00:00'::interval, pos_reports.event_time) AS day,
    public.last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    public.last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    public.last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    public.last(pos_reports."position", pos_reports.event_time) AS "position",
    public.last(pos_reports.cog, pos_reports.event_time) AS cog,
    public.last(pos_reports.sog, pos_reports.event_time) AS sog,
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  WHERE (pos_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(5)), '-infinity'::timestamp with time zone))
  GROUP BY pos_reports.mmsi, (public.time_bucket('12:00:00'::interval, pos_reports.event_time));
    DROP VIEW ais.daily_pos_cagg;
       ais          rory    false    256    256    256    256    256    256    256    14            i           0    0    TABLE daily_pos_cagg    ACL     k   GRANT ALL ON TABLE ais.daily_pos_cagg TO api_user;
GRANT SELECT ON TABLE ais.daily_pos_cagg TO postgisftw;
          ais          rory    false    275            :           1259    21856    data_sources_cagg    VIEW     c  CREATE VIEW ais.data_sources_cagg AS
 SELECT _materialized_hypertable_7.routing_key,
    _materialized_hypertable_7.hour_bucket
   FROM _timescaledb_internal._materialized_hypertable_7
  WHERE (_materialized_hypertable_7.hour_bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(7)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_7.routing_key, _materialized_hypertable_7.hour_bucket
UNION ALL
 SELECT pos_reports.routing_key,
    public.time_bucket('01:00:00'::interval, pos_reports.event_time) AS hour_bucket
   FROM ais.pos_reports
  WHERE (pos_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(7)), '-infinity'::timestamp with time zone))
  GROUP BY pos_reports.routing_key, (public.time_bucket('01:00:00'::interval, pos_reports.event_time));
 !   DROP VIEW ais.data_sources_cagg;
       ais          rory    false    256    256    14            j           0    0    TABLE data_sources_cagg    ACL     q   GRANT ALL ON TABLE ais.data_sources_cagg TO api_user;
GRANT SELECT ON TABLE ais.data_sources_cagg TO postgisftw;
          ais          rory    false    314                       1259    18531    mid_to_country    TABLE     �   CREATE TABLE ais.mid_to_country (
    country text NOT NULL,
    country_abrv0 text,
    country_abrv1 text,
    country_abrv2 text,
    mid character varying(3) NOT NULL,
    flag_link text
);
    DROP TABLE ais.mid_to_country;
       ais         heap    rory    false    14            k           0    0    TABLE mid_to_country    ACL     k   GRANT ALL ON TABLE ais.mid_to_country TO api_user;
GRANT SELECT ON TABLE ais.mid_to_country TO postgisftw;
          ais          rory    false    260                       1259    19770    vessel_details_cagg    VIEW     �  CREATE VIEW ais.vessel_details_cagg AS
 SELECT _materialized_hypertable_3.mmsi,
    _materialized_hypertable_3.day,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_3_3, NULL::text) AS imo,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_4_4, NULL::text) AS callsign,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_5_5, NULL::text) AS name,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_6_6, NULL::character varying) AS type_and_cargo,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_7_7, NULL::smallint) AS to_bow,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_8_8, NULL::smallint) AS to_stern,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_9_9, NULL::smallint) AS to_port,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_10_10, NULL::smallint) AS to_starboard,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_11_11, NULL::smallint) AS fix_type,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_12_12, NULL::smallint) AS eta_month,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_13_13, NULL::smallint) AS eta_day,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_14_14, NULL::smallint) AS eta_hour,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_15_15, NULL::smallint) AS eta_minute,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_16_16, NULL::timestamp with time zone) AS eta,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_17_17, NULL::numeric) AS draught,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_18_18, NULL::text) AS destination,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_19_19, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_20_20, NULL::character varying) AS msg_type,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], _materialized_hypertable_3.agg_21_21, NULL::text) AS routing_key
   FROM _timescaledb_internal._materialized_hypertable_3
  WHERE (_materialized_hypertable_3.day < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(3)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_3.mmsi, _materialized_hypertable_3.day, _materialized_hypertable_3.grp_22_22
UNION ALL
 SELECT voy_reports.mmsi,
    public.time_bucket('1 day'::interval, voy_reports.event_time) AS day,
    public.last(voy_reports.imo, voy_reports.event_time) AS imo,
    public.last(voy_reports.callsign, voy_reports.event_time) AS callsign,
    public.last(voy_reports.name, voy_reports.event_time) AS name,
    public.last(voy_reports.type_and_cargo, voy_reports.event_time) AS type_and_cargo,
    public.last(voy_reports.to_bow, voy_reports.event_time) AS to_bow,
    public.last(voy_reports.to_stern, voy_reports.event_time) AS to_stern,
    public.last(voy_reports.to_port, voy_reports.event_time) AS to_port,
    public.last(voy_reports.to_starboard, voy_reports.event_time) AS to_starboard,
    public.last(voy_reports.fix_type, voy_reports.event_time) AS fix_type,
    public.last(voy_reports.eta_month, voy_reports.event_time) AS eta_month,
    public.last(voy_reports.eta_day, voy_reports.event_time) AS eta_day,
    public.last(voy_reports.eta_hour, voy_reports.event_time) AS eta_hour,
    public.last(voy_reports.eta_minute, voy_reports.event_time) AS eta_minute,
    public.last(voy_reports.eta, voy_reports.event_time) AS eta,
    public.last(voy_reports.draught, voy_reports.event_time) AS draught,
    public.last(voy_reports.destination, voy_reports.event_time) AS destination,
    public.last(voy_reports.event_time, voy_reports.event_time) AS event_time,
    public.last(voy_reports.msg_type, voy_reports.event_time) AS msg_type,
    public.last(voy_reports.routing_key, voy_reports.event_time) AS routing_key
   FROM ais.voy_reports
  WHERE (voy_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(3)), '-infinity'::timestamp with time zone))
  GROUP BY voy_reports.mmsi, (public.time_bucket('1 day'::interval, voy_reports.event_time)), voy_reports.routing_key;
 #   DROP VIEW ais.vessel_details_cagg;
       ais          rory    false    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    257    14            l           0    0    TABLE vessel_details_cagg    ACL     u   GRANT ALL ON TABLE ais.vessel_details_cagg TO api_user;
GRANT SELECT ON TABLE ais.vessel_details_cagg TO postgisftw;
          ais          rory    false    267            �           1259    95381    ship_details_agg    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.ship_details_agg AS
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
 -   DROP MATERIALIZED VIEW ais.ship_details_agg;
       ais         heap    rory    false    267    267    267    267    267    267    267    267    267    267    267    258    260    260    258    14            m           0    0    TABLE ship_details_agg    ACL     o   GRANT ALL ON TABLE ais.ship_details_agg TO api_user;
GRANT SELECT ON TABLE ais.ship_details_agg TO postgisftw;
          ais          rory    false    434            ?           1259    273246    vessel_traj_4h_gaps_2020    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.vessel_traj_4h_gaps_2020 AS
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
 5   DROP MATERIALIZED VIEW ais.vessel_traj_4h_gaps_2020;
       ais         heap    rory    false    271    271    271    271    271    14            n           0    0    TABLE vessel_traj_4h_gaps_2020    ACL     �   GRANT SELECT ON TABLE ais.vessel_traj_4h_gaps_2020 TO api_user;
GRANT SELECT ON TABLE ais.vessel_traj_4h_gaps_2020 TO postgisftw;
          ais          rory    false    575            @           1259    273585    martin_query    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.martin_query AS
 SELECT bb.type_and_cargo_text,
    cc.pol_type,
    count(aa.traj) AS count,
    aa.date
   FROM ((ais.vessel_traj_4h_gaps_2020 aa
     LEFT JOIN ais.ship_details_agg bb ON ((aa.mmsi = bb.mmsi)))
     JOIN geo.ocean_geom cc ON (public.st_intersects(public.st_setsrid(aa.traj, 4326), public.st_makevalid(cc.geom))))
  WHERE (((aa.date >= '2020-01-01'::date) AND (aa.date <= '2020-02-01'::date)) AND (cc.iso_ter = 'ZAF'::text) AND public.st_within(public.st_setsrid(aa.traj, 4326), public.st_makeenvelope((8)::double precision, ('-15'::integer)::double precision, (42)::double precision, ('-45'::integer)::double precision, 4326)))
  GROUP BY bb.type_and_cargo_text, aa.date, cc.pol_type
  WITH NO DATA;
 )   DROP MATERIALIZED VIEW ais.martin_query;
       ais         heap    rory    false    575    434    575    575    434    14            o           0    0    TABLE martin_query    ACL     4   GRANT SELECT ON TABLE ais.martin_query TO api_user;
          ais          rory    false    576            A           1259    273593    martin_query_sizes    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.martin_query_sizes AS
 SELECT bb.type_and_cargo_text,
    cc.pol_type,
    count(aa.traj) AS count,
    aa.date,
    width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45) AS width_div_10
   FROM ((ais.vessel_traj_4h_gaps_2020 aa
     LEFT JOIN ais.ship_details_agg bb ON ((aa.mmsi = bb.mmsi)))
     JOIN geo.ocean_geom cc ON (public.st_intersects(public.st_setsrid(aa.traj, 4326), public.st_makevalid(cc.geom))))
  WHERE (((aa.date >= '2020-01-01'::date) AND (aa.date <= '2020-02-01'::date)) AND (cc.iso_ter = 'ZAF'::text) AND public.st_within(public.st_setsrid(aa.traj, 4326), public.st_makeenvelope((8)::double precision, ('-15'::integer)::double precision, (42)::double precision, ('-45'::integer)::double precision, 4326)))
  GROUP BY bb.type_and_cargo_text, aa.date, cc.pol_type, (width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45))
  WITH NO DATA;
 /   DROP MATERIALIZED VIEW ais.martin_query_sizes;
       ais         heap    rory    false    434    434    434    434    575    575    575    14            p           0    0    TABLE martin_query_sizes    ACL     :   GRANT SELECT ON TABLE ais.martin_query_sizes TO api_user;
          ais          rory    false    577            B           1259    273601    martin_query_sizes_class    MATERIALIZED VIEW     j  CREATE MATERIALIZED VIEW ais.martin_query_sizes_class AS
 SELECT "left"((bb.type_and_cargo)::text, 1) AS cargo_super_class,
    cc.pol_type,
    count(aa.traj) AS count,
    aa.date,
    width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45) AS width_div_10
   FROM ((ais.vessel_traj_4h_gaps_2020 aa
     LEFT JOIN ais.ship_details_agg bb ON ((aa.mmsi = bb.mmsi)))
     JOIN geo.ocean_geom cc ON (public.st_intersects(public.st_setsrid(aa.traj, 4326), public.st_makevalid(cc.geom))))
  WHERE (((aa.date >= '2020-01-01'::date) AND (aa.date <= '2020-02-01'::date)) AND (cc.iso_ter = 'ZAF'::text) AND public.st_within(public.st_setsrid(aa.traj, 4326), public.st_makeenvelope((8)::double precision, ('-15'::integer)::double precision, (42)::double precision, ('-45'::integer)::double precision, 4326)) AND ((bb.type_and_cargo)::text = ANY ((ARRAY['30'::character varying, '70'::character varying, '71'::character varying, '72'::character varying, '73'::character varying, '74'::character varying, '75'::character varying, '76'::character varying, '77'::character varying, '78'::character varying, '79'::character varying, '80'::character varying, '81'::character varying, '82'::character varying, '83'::character varying, '84'::character varying, '85'::character varying, '86'::character varying, '87'::character varying, '88'::character varying, '89'::character varying])::text[])))
  GROUP BY ("left"((bb.type_and_cargo)::text, 1)), aa.date, cc.pol_type, (width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45))
  WITH NO DATA;
 5   DROP MATERIALIZED VIEW ais.martin_query_sizes_class;
       ais         heap    rory    false    575    575    575    434    434    434    434    14            q           0    0    TABLE martin_query_sizes_class    ACL     @   GRANT SELECT ON TABLE ais.martin_query_sizes_class TO api_user;
          ais          rory    false    578            t           1259    308762 #   martin_query_sizes_class_flag_100nm    MATERIALIZED VIEW     �  CREATE MATERIALIZED VIEW ais.martin_query_sizes_class_flag_100nm AS
 WITH all_geom AS (
         SELECT cc_1.pol_type,
            cc_1.geom
           FROM geo.ocean_geom cc_1
          WHERE (cc_1.iso_ter = 'ZAF'::text)
        UNION ALL
         SELECT '100 nm'::text AS pol_type,
            rsa_100nm.geom
           FROM geo.rsa_100nm
        )
 SELECT "left"((bb.type_and_cargo)::text, 1) AS cargo_super_class,
    cc.pol_type,
    count(aa.traj) FILTER (WHERE ("left"(aa.mmsi, 3) = '601'::text)) AS zaf_count,
    count(aa.traj) FILTER (WHERE ("left"(aa.mmsi, 3) <> '601'::text)) AS foreign_count,
    aa.date,
    width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45) AS width_div_10
   FROM ((ais.vessel_traj_4h_gaps_2020 aa
     LEFT JOIN ais.ship_details_agg bb ON ((aa.mmsi = bb.mmsi)))
     JOIN all_geom cc ON (public.st_intersects(public.st_setsrid(aa.traj, 4326), public.st_makevalid(cc.geom))))
  WHERE ((aa.date >= '2020-01-01'::date) AND (aa.date <= '2020-02-01'::date) AND public.st_within(public.st_setsrid(aa.traj, 4326), public.st_makeenvelope((8)::double precision, ('-15'::integer)::double precision, (42)::double precision, ('-45'::integer)::double precision, 4326)) AND ((bb.type_and_cargo)::text = ANY (ARRAY[('30'::character varying)::text, ('70'::character varying)::text, ('71'::character varying)::text, ('72'::character varying)::text, ('73'::character varying)::text, ('74'::character varying)::text, ('75'::character varying)::text, ('76'::character varying)::text, ('77'::character varying)::text, ('78'::character varying)::text, ('79'::character varying)::text, ('80'::character varying)::text, ('81'::character varying)::text, ('82'::character varying)::text, ('83'::character varying)::text, ('84'::character varying)::text, ('85'::character varying)::text, ('86'::character varying)::text, ('87'::character varying)::text, ('88'::character varying)::text, ('89'::character varying)::text])))
  GROUP BY ("left"((bb.type_and_cargo)::text, 1)), aa.date, cc.pol_type, (width_bucket(((bb.to_bow + bb.to_stern))::double precision, (10)::double precision, (450)::double precision, 45))
  WITH NO DATA;
 @   DROP MATERIALIZED VIEW ais.martin_query_sizes_class_flag_100nm;
       ais         heap    rory    false    575    575    575    434    434    434    434    14            r           0    0 )   TABLE martin_query_sizes_class_flag_100nm    ACL     K   GRANT SELECT ON TABLE ais.martin_query_sizes_class_flag_100nm TO api_user;
          ais          rory    false    628                       1259    18525 
   nav_status    TABLE     K   CREATE TABLE ais.nav_status (
    nav_status text,
    description text
);
    DROP TABLE ais.nav_status;
       ais         heap    rory    false    14            s           0    0    TABLE nav_status    ACL     c   GRANT ALL ON TABLE ais.nav_status TO api_user;
GRANT SELECT ON TABLE ais.nav_status TO postgisftw;
          ais          rory    false    259            2           1259    21804    port_history    VIEW     I  CREATE VIEW ais.port_history AS
 SELECT port.port_name,
    ais.mmsi,
    ais.sog,
    ais.event_time
   FROM (geo.world_port_index port
     JOIN ais.daily_pos_cagg ais ON ((public.st_dwithin(public.st_setsrid(port.geom, 4326), ais."position", (0.2)::double precision) AND (ais.sog < (5)::numeric))))
  ORDER BY ais.event_time;
    DROP VIEW ais.port_history;
       ais          rory    false    275    275    275    275    14            t           0    0    TABLE port_history    ACL     g   GRANT ALL ON TABLE ais.port_history TO api_user;
GRANT SELECT ON TABLE ais.port_history TO postgisftw;
          ais          rory    false    306            2           1259    163334    pos_reports_30min_cagg    VIEW     �  CREATE VIEW ais.pos_reports_30min_cagg AS
 SELECT aa.mmsi,
    aa.bucket,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], aa.agg_3_3, NULL::character varying) AS navigation_status,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], aa.agg_4_4, NULL::smallint) AS rot,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], aa.agg_5_5, NULL::numeric) AS sog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], aa.agg_6_6, NULL::double precision) AS longitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], aa.agg_7_7, NULL::double precision) AS latitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], aa.agg_8_8, NULL::public.geometry) AS "position",
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], aa.agg_9_9, NULL::numeric) AS cog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], aa.agg_10_10, NULL::numeric) AS hdg,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], aa.agg_11_11, NULL::timestamp with time zone) AS event_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], aa.agg_12_12, NULL::timestamp with time zone) AS server_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], aa.agg_13_13, NULL::character varying) AS msg_type,
    aa.routing_key,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_15_15, NULL::numeric) AS avg_cog,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_16_16, NULL::numeric) AS avg_hdg,
    _timescaledb_internal.finalize_agg('avg(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_17_17, NULL::numeric) AS avg_sog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_18_18, NULL::numeric) AS max_cog,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_19_19, NULL::numeric) AS max_hdg,
    _timescaledb_internal.finalize_agg('max(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_20_20, NULL::numeric) AS max_sog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_21_21, NULL::numeric) AS min_cog,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_22_22, NULL::numeric) AS min_hdg,
    _timescaledb_internal.finalize_agg('min(numeric)'::text, NULL::name, NULL::name, '{{pg_catalog,numeric}}'::name[], aa.agg_23_23, NULL::numeric) AS min_sog
   FROM _timescaledb_internal._materialized_hypertable_8 aa
  WHERE (aa.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(8)), '-infinity'::timestamp with time zone))
  GROUP BY aa.mmsi, aa.routing_key, aa.bucket
UNION ALL
 SELECT aa.mmsi,
    public.time_bucket('00:30:00'::interval, aa.event_time) AS bucket,
    public.last(aa.navigation_status, aa.event_time) AS navigation_status,
    public.last(aa.rot, aa.event_time) AS rot,
    public.last(aa.sog, aa.event_time) AS sog,
    public.last(aa.longitude, aa.event_time) AS longitude,
    public.last(aa.latitude, aa.event_time) AS latitude,
    public.last(aa."position", aa.event_time) AS "position",
    public.last(aa.cog, aa.event_time) AS cog,
    public.last(aa.hdg, aa.event_time) AS hdg,
    public.last(aa.event_time, aa.event_time) AS event_time,
    public.last(aa.server_time, aa.event_time) AS server_time,
    public.last(aa.msg_type, aa.event_time) AS msg_type,
    aa.routing_key,
    avg(aa.cog) AS avg_cog,
    avg(aa.hdg) AS avg_hdg,
    avg(aa.sog) AS avg_sog,
    max(aa.cog) AS max_cog,
    max(aa.hdg) AS max_hdg,
    max(aa.sog) AS max_sog,
    min(aa.cog) AS min_cog,
    min(aa.hdg) AS min_hdg,
    min(aa.sog) AS min_sog
   FROM ais.pos_reports aa
  WHERE (aa.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(8)), '-infinity'::timestamp with time zone))
  GROUP BY aa.mmsi, aa.routing_key, (public.time_bucket('00:30:00'::interval, aa.event_time));
 &   DROP VIEW ais.pos_reports_30min_cagg;
       ais          rory    false    256    256    256    256    256    256    256    256    256    256    256    256    256    14            u           0    0    TABLE pos_reports_30min_cagg    ACL     ~   GRANT SELECT ON TABLE ais.pos_reports_30min_cagg TO api_user;
GRANT SELECT ON TABLE ais.pos_reports_30min_cagg TO postgisftw;
          ais          rory    false    562            �           1259    328878    pos_reports_30min_dist_cagg    VIEW     )  CREATE VIEW ais.pos_reports_30min_dist_cagg AS
 SELECT ais.mmsi,
    ais.bucket,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], ais.agg_3_3, NULL::character varying) AS last_navigation_status,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], ais.agg_4_4, NULL::smallint) AS last_rot,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_5_5, NULL::numeric) AS last_sog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], ais.agg_6_6, NULL::double precision) AS last_longitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], ais.agg_7_7, NULL::double precision) AS last_latitude,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], ais.agg_8_8, NULL::public.geometry) AS last_position,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_9_9, NULL::numeric) AS last_cog,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_10_10, NULL::numeric) AS last_hdg,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], ais.agg_11_11, NULL::timestamp with time zone) AS last_event_time,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], ais.agg_12_12, NULL::character varying) AS last_msg_type,
    _timescaledb_internal.finalize_agg('last(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], ais.agg_13_13, NULL::text) AS last_routing_key,
    (_timescaledb_internal.finalize_agg('avg(double precision)'::text, NULL::name, NULL::name, '{{pg_catalog,float8}}'::name[], ais.agg_14_14, NULL::double precision) * (0.514444)::double precision) AS avg_y_disturbance,
    (_timescaledb_internal.finalize_agg('avg(double precision)'::text, NULL::name, NULL::name, '{{pg_catalog,float8}}'::name[], ais.agg_15_15, NULL::double precision) * (0.514444)::double precision) AS avg_x_disturbance,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], ais.agg_16_16, NULL::character varying) AS first_navigation_status,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,int2},{pg_catalog,timestamptz}}'::name[], ais.agg_17_17, NULL::smallint) AS first_rot,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_18_18, NULL::numeric) AS first_sog,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], ais.agg_19_19, NULL::double precision) AS first_longitude,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,float8},{pg_catalog,timestamptz}}'::name[], ais.agg_20_20, NULL::double precision) AS first_latitude,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{public,geometry},{pg_catalog,timestamptz}}'::name[], ais.agg_21_21, NULL::public.geometry) AS first_position,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_22_22, NULL::numeric) AS first_cog,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,numeric},{pg_catalog,timestamptz}}'::name[], ais.agg_23_23, NULL::numeric) AS first_hdg,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, NULL::name, NULL::name, '{{pg_catalog,timestamptz},{pg_catalog,timestamptz}}'::name[], ais.agg_24_24, NULL::timestamp with time zone) AS first_event_time,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,varchar},{pg_catalog,timestamptz}}'::name[], ais.agg_25_25, NULL::character varying) AS first_msg_type,
    _timescaledb_internal.finalize_agg('first(anyelement,"any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text},{pg_catalog,timestamptz}}'::name[], ais.agg_26_26, NULL::text) AS first_routing_key
   FROM _timescaledb_internal._materialized_hypertable_14 ais
  WHERE (ais.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(14)), '-infinity'::timestamp with time zone))
  GROUP BY ais.mmsi, ais.bucket
UNION ALL
 SELECT ais.mmsi,
    public.time_bucket('00:30:00'::interval, ais.event_time) AS bucket,
    public.last(ais.navigation_status, ais.event_time) AS last_navigation_status,
    public.last(ais.rot, ais.event_time) AS last_rot,
    public.last(ais.sog, ais.event_time) AS last_sog,
    public.last(ais.longitude, ais.event_time) AS last_longitude,
    public.last(ais.latitude, ais.event_time) AS last_latitude,
    public.last(ais."position", ais.event_time) AS last_position,
    public.last(ais.cog, ais.event_time) AS last_cog,
    public.last(ais.hdg, ais.event_time) AS last_hdg,
    public.last(ais.event_time, ais.event_time) AS last_event_time,
    public.last(ais.msg_type, ais.event_time) AS last_msg_type,
    public.last(ais.routing_key, ais.event_time) AS last_routing_key,
    (avg((((NULLIF(ais.sog, 102.3))::double precision * sin(radians((NULLIF(ais.cog, 360.0))::double precision))) - ((NULLIF(ais.sog, 102.3))::double precision * sin(radians((NULLIF(ais.hdg, 511.0))::double precision))))) * (0.514444)::double precision) AS avg_y_disturbance,
    (avg((((NULLIF(ais.sog, 102.3))::double precision * cos(radians((NULLIF(ais.cog, 360.0))::double precision))) - ((NULLIF(ais.sog, 102.3))::double precision * cos(radians((NULLIF(ais.hdg, 511.0))::double precision))))) * (0.514444)::double precision) AS avg_x_disturbance,
    public.first(ais.navigation_status, ais.event_time) AS first_navigation_status,
    public.first(ais.rot, ais.event_time) AS first_rot,
    public.first(ais.sog, ais.event_time) AS first_sog,
    public.first(ais.longitude, ais.event_time) AS first_longitude,
    public.first(ais.latitude, ais.event_time) AS first_latitude,
    public.first(ais."position", ais.event_time) AS first_position,
    public.first(ais.cog, ais.event_time) AS first_cog,
    public.first(ais.hdg, ais.event_time) AS first_hdg,
    public.first(ais.event_time, ais.event_time) AS first_event_time,
    public.first(ais.msg_type, ais.event_time) AS first_msg_type,
    public.first(ais.routing_key, ais.event_time) AS first_routing_key
   FROM ais.pos_reports ais
  WHERE (ais.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(14)), '-infinity'::timestamp with time zone))
  GROUP BY ais.mmsi, (public.time_bucket('00:30:00'::interval, ais.event_time));
 +   DROP VIEW ais.pos_reports_30min_dist_cagg;
       ais          rory    false    256    256    256    256    256    256    256    256    256    256    256    256    14            v           0    0 !   TABLE pos_reports_30min_dist_cagg    ACL     C   GRANT SELECT ON TABLE ais.pos_reports_30min_dist_cagg TO api_user;
          ais          rory    false    657            n           1259    306047    pos_reports_source_counter    VIEW     K  CREATE VIEW ais.pos_reports_source_counter AS
 SELECT _materialized_hypertable_10.routing_key,
    _materialized_hypertable_10.bucket,
    _timescaledb_internal.finalize_agg('count("any")'::text, 'pg_catalog'::name, 'default'::name, '{{pg_catalog,text}}'::name[], _materialized_hypertable_10.agg_3_3, NULL::bigint) AS count
   FROM _timescaledb_internal._materialized_hypertable_10
  WHERE (_materialized_hypertable_10.bucket < COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(10)), '-infinity'::timestamp with time zone))
  GROUP BY _materialized_hypertable_10.routing_key, _materialized_hypertable_10.bucket
UNION ALL
 SELECT pos_reports.routing_key,
    public.time_bucket('00:30:00'::interval, pos_reports.event_time) AS bucket,
    count(pos_reports.routing_key) AS count
   FROM ais.pos_reports
  WHERE (pos_reports.event_time >= COALESCE(_timescaledb_internal.to_timestamp(_timescaledb_internal.cagg_watermark(10)), '-infinity'::timestamp with time zone))
  GROUP BY pos_reports.routing_key, (public.time_bucket('00:30:00'::interval, pos_reports.event_time));
 *   DROP VIEW ais.pos_reports_source_counter;
       ais          rory    false    256    256    14            w           0    0     TABLE pos_reports_source_counter    ACL     B   GRANT SELECT ON TABLE ais.pos_reports_source_counter TO api_user;
          ais          rory    false    622            �           1259    325805    storm_trajectory    VIEW     �  CREATE VIEW ais.storm_trajectory AS
 SELECT gps.mmsi,
    public.st_setsrid(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326) AS traj,
    public.st_astext(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_text,
    public.st_isvalidtrajectory(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_valid,
    public.first(gps.event_time, gps.event_time) AS first_time,
    public.last(gps.event_time, gps.event_time) AS last_time
   FROM ais.hourly_pos_cagg gps
  WHERE ((gps.event_time >= '2020-01-10 00:00:00+00'::timestamp with time zone) AND (gps.event_time <= '2020-01-30 00:00:00+00'::timestamp with time zone) AND public.st_within(gps."position", public.st_makeenvelope(('-9'::integer)::double precision, (39)::double precision, ('-25'::integer)::double precision, (45)::double precision, 4326)))
  GROUP BY gps.mmsi;
     DROP VIEW ais.storm_trajectory;
       ais          rory    false    271    271    271    14            x           0    0    TABLE storm_trajectory    ACL     8   GRANT SELECT ON TABLE ais.storm_trajectory TO api_user;
          ais          rory    false    644            5           1259    190269    traj_testing    MATERIALIZED VIEW     1  CREATE MATERIALIZED VIEW ais.traj_testing AS
 WITH ais_data AS (
         SELECT aa_1.mmsi,
            aa_1.event_time,
            aa_1.longitude,
            aa_1.latitude,
            (lag(aa_1.event_time) OVER (PARTITION BY aa_1.mmsi ORDER BY aa_1.event_time) <= (aa_1.event_time - '03:00:00'::interval)) AS step
           FROM ais.hourly_pos_cagg aa_1
          WHERE ((aa_1.bucket >= '2020-03-01 00:00:00+00'::timestamp with time zone) AND (aa_1.bucket <= '2020-04-01 00:00:00+00'::timestamp with time zone))
        ), time_groups AS (
         SELECT bb_1.mmsi,
            bb_1.event_time,
            bb_1.longitude,
            bb_1.latitude,
            count(*) FILTER (WHERE bb_1.step) OVER (PARTITION BY bb_1.mmsi ORDER BY bb_1.event_time) AS time_group
           FROM ais_data bb_1
        ), time_trajs AS (
         SELECT cc.mmsi,
            cc.time_group,
            public.st_makeline(public.st_makepointm(cc.longitude, cc.latitude, date_part('epoch'::text, cc.event_time)) ORDER BY cc.event_time) AS traj,
            public.first(cc.event_time, cc.event_time) AS traj_start,
            public.last(cc.event_time, cc.event_time) AS traj_end
           FROM time_groups cc
          GROUP BY cc.mmsi, cc.time_group
        )
 SELECT public.st_npoints(aa.traj) AS vetex_count,
    public.st_asewkt(aa.traj) AS wwkt,
    bb.mmsi,
    bb.imo,
    bb.name,
    bb.callsign,
    bb.to_bow,
    bb.to_stern,
    bb.to_port,
    bb.to_starboard,
    bb.type_and_cargo,
    bb.type_and_cargo_text,
    bb.flag_state,
    bb.routing_key,
    bb.event_time,
    aa.time_group,
    aa.traj,
    aa.traj_start,
    aa.traj_end
   FROM (time_trajs aa
     JOIN ais.ship_details_agg bb ON ((aa.mmsi = bb.mmsi)))
  WHERE ((public.st_npoints(aa.traj) > 2) AND (public.st_length(aa.traj) < (20)::double precision))
  WITH NO DATA;
 )   DROP MATERIALIZED VIEW ais.traj_testing;
       ais         heap    rory    false    434    434    434    434    271    271    271    271    271    434    434    434    434    434    434    434    434    434    14            y           0    0    TABLE traj_testing    ACL     j   GRANT SELECT ON TABLE ais.traj_testing TO api_user;
GRANT SELECT ON TABLE ais.traj_testing TO postgisftw;
          ais          rory    false    565            1           1259    21799    vessel_trajectory    VIEW     �  CREATE VIEW ais.vessel_trajectory AS
 SELECT gps.mmsi,
    public.st_setsrid(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326) AS traj,
    public.st_astext(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_text,
    public.st_isvalidtrajectory(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_valid,
    public.first(gps.event_time, gps.event_time) AS first_time,
    public.last(gps.event_time, gps.event_time) AS last_time
   FROM ais.hourly_pos_cagg gps
  WHERE ((gps.event_time >= '2020-01-01 00:00:00+00'::timestamp with time zone) AND (gps.event_time <= '2020-03-01 00:00:00+00'::timestamp with time zone))
  GROUP BY gps.mmsi;
 !   DROP VIEW ais.vessel_trajectory;
       ais          rory    false    271    271    271    14            z           0    0    TABLE vessel_trajectory    ACL     q   GRANT ALL ON TABLE ais.vessel_trajectory TO api_user;
GRANT SELECT ON TABLE ais.vessel_trajectory TO postgisftw;
          ais          rory    false    305            �           1259    325617    vessel_trajectory_2021_06_28    VIEW     �  CREATE VIEW ais.vessel_trajectory_2021_06_28 AS
 SELECT gps.mmsi,
    public.st_setsrid(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time), 4326) AS traj,
    public.st_astext(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_text,
    public.st_isvalidtrajectory(public.st_makeline(public.st_makepoint(public.st_x(gps."position"), public.st_y(gps."position"), date_part('epoch'::text, gps.event_time)) ORDER BY gps.event_time)) AS traj_valid,
    public.first(gps.event_time, gps.event_time) AS first_time,
    public.last(gps.event_time, gps.event_time) AS last_time
   FROM ais.hourly_pos_cagg gps
  WHERE ((gps.event_time >= '2021-06-25 00:00:00+00'::timestamp with time zone) AND (gps.event_time <= '2021-06-29 00:00:00+00'::timestamp with time zone))
  GROUP BY gps.mmsi;
 ,   DROP VIEW ais.vessel_trajectory_2021_06_28;
       ais          rory    false    271    271    271    14            {           0    0 "   TABLE vessel_trajectory_2021_06_28    ACL     D   GRANT SELECT ON TABLE ais.vessel_trajectory_2021_06_28 TO api_user;
          ais          rory    false    643            d           1259    273237    ais_traj_2020_st_makeline_idx    INDEX     Z   CREATE INDEX ais_traj_2020_st_makeline_idx ON ais.ais_traj_2020 USING gist (st_makeline);
 .   DROP INDEX ais.ais_traj_2020_st_makeline_idx;
       ais            rory    false    549            ^           1259    18507    pos_reports_event_time_idx    INDEX     Z   CREATE INDEX pos_reports_event_time_idx ON ais.pos_reports USING btree (event_time DESC);
 +   DROP INDEX ais.pos_reports_event_time_idx;
       ais            rory    false    256            _           1259    18508    pos_reports_mmsi_event_time_idx    INDEX     e   CREATE INDEX pos_reports_mmsi_event_time_idx ON ais.pos_reports USING btree (mmsi, event_time DESC);
 0   DROP INDEX ais.pos_reports_mmsi_event_time_idx;
       ais            rory    false    256    256            `           1259    18509    pos_reports_position_idx    INDEX     R   CREATE INDEX pos_reports_position_idx ON ais.pos_reports USING gist ("position");
 )   DROP INDEX ais.pos_reports_position_idx;
       ais            rory    false    256            c           1259    273551    ship_details_agg_mmsi_ix    INDEX     X   CREATE INDEX ship_details_agg_mmsi_ix ON ais.ship_details_agg USING btree (mmsi, name);
 )   DROP INDEX ais.ship_details_agg_mmsi_ix;
       ais            rory    false    434    434            |           0    0    INDEX ship_details_agg_mmsi_ix    COMMENT     ?   COMMENT ON INDEX ais.ship_details_agg_mmsi_ix IS 'MMSI index';
          ais          rory    false    6499            e           1259    273532 &   vessel_traj_4h_gaps_2020_mmsi_date_idx    INDEX     s   CREATE INDEX vessel_traj_4h_gaps_2020_mmsi_date_idx ON ais.vessel_traj_4h_gaps_2020 USING btree (mmsi, date DESC);
 7   DROP INDEX ais.vessel_traj_4h_gaps_2020_mmsi_date_idx;
       ais            rory    false    575    575            f           1259    273531 !   vessel_traj_4h_gaps_2020_traj_idx    INDEX     b   CREATE INDEX vessel_traj_4h_gaps_2020_traj_idx ON ais.vessel_traj_4h_gaps_2020 USING gist (traj);
 2   DROP INDEX ais.vessel_traj_4h_gaps_2020_traj_idx;
       ais            rory    false    575            a           1259    18517    voy_reports_event_time_idx    INDEX     Z   CREATE INDEX voy_reports_event_time_idx ON ais.voy_reports USING btree (event_time DESC);
 +   DROP INDEX ais.voy_reports_event_time_idx;
       ais            rory    false    257            b           1259    18518    voy_reports_mmsi_event_time_idx    INDEX     e   CREATE INDEX voy_reports_mmsi_event_time_idx ON ais.voy_reports USING btree (mmsi, event_time DESC);
 0   DROP INDEX ais.voy_reports_mmsi_event_time_idx;
       ais            rory    false    257    257            g           2620    19810 (   pos_reports ts_cagg_invalidation_trigger    TRIGGER     �   CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('1');
 >   DROP TRIGGER ts_cagg_invalidation_trigger ON ais.pos_reports;
       ais          rory    false    256            i           2620    19785 (   voy_reports ts_cagg_invalidation_trigger    TRIGGER     �   CREATE TRIGGER ts_cagg_invalidation_trigger AFTER INSERT OR DELETE OR UPDATE ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.continuous_agg_invalidation_trigger('2');
 >   DROP TRIGGER ts_cagg_invalidation_trigger ON ais.voy_reports;
       ais          rory    false    257            h           2620    18506    pos_reports ts_insert_blocker    TRIGGER     �   CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON ais.pos_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();
 3   DROP TRIGGER ts_insert_blocker ON ais.pos_reports;
       ais          rory    false    256            j           2620    18516    voy_reports ts_insert_blocker    TRIGGER     �   CREATE TRIGGER ts_insert_blocker BEFORE INSERT ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION _timescaledb_internal.insert_blocker();
 3   DROP TRIGGER ts_insert_blocker ON ais.voy_reports;
       ais          rory    false    257            �           826    138530    DEFAULT PRIVILEGES FOR TABLES    DEFAULT ACL     �   ALTER DEFAULT PRIVILEGES FOR ROLE rory IN SCHEMA ais REVOKE ALL ON TABLES  FROM rory;
ALTER DEFAULT PRIVILEGES FOR ROLE rory IN SCHEMA ais GRANT SELECT ON TABLES  TO api_user;
          ais          rory    false    14           