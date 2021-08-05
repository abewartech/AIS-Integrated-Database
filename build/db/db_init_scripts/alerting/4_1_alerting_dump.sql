--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5
-- Dumped by pg_dump version 12.5

-- Started on 2021-07-26 14:19:26 UTC

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
-- TOC entry 25 (class 2615 OID 326119)
-- Name: alerting; Type: SCHEMA; Schema: -; Owner: rory
--

CREATE SCHEMA alerting;


-- ALTER SCHEMA alerting OWNER TO rory;

--
-- TOC entry 671 (class 1259 OID 333844)
-- Name: data_feeds; Type: VIEW; Schema: alerting; Owner: rory
--

-- CREATE VIEW alerting.data_feeds AS
--  WITH required_feeds AS (
--          SELECT DISTINCT ON (pos_reports_source_counter.routing_key) pos_reports_source_counter.routing_key,
--             pos_reports_source_counter.bucket AS last_bucket,
--             pos_reports_source_counter.count
--            FROM ais.pos_reports_source_counter
--           WHERE (pos_reports_source_counter.bucket > (now() - '1 mon'::interval))
--           ORDER BY pos_reports_source_counter.routing_key, pos_reports_source_counter.bucket DESC
--         )
--  SELECT required_feeds.routing_key AS stopped_data_feed,
--     required_feeds.last_bucket
--    FROM required_feeds
--   WHERE (required_feeds.last_bucket < (now() - '02:00:00'::interval));


-- ALTER TABLE alerting.data_feeds OWNER TO rory;

--
-- TOC entry 647 (class 1259 OID 326138)
-- Name: foreign_fishing_report; Type: VIEW; Schema: alerting; Owner: rory
--

-- CREATE VIEW alerting.foreign_fishing_report AS
--  SELECT DISTINCT ON (aa.mmsi) aa.mmsi AS "MMSI",
--     cc.name AS "Name",
--     cc.callsign AS "Callsign",
--     cc.flag_state AS "Flag State",
--     aa.event_time AS "Last Position Report",
--     public.st_aslatlontext(aa."position", 'D°M''S.SSS"C'::text) AS "DMS",
--     aa.longitude AS lon,
--     aa.latitude AS lat,
--     aa.cog AS "Course",
--     aa.sog AS "Speed",
--     dd.description AS "Nav Status",
--     bb.geoname AS "Location"
--    FROM (((ais.hourly_pos_cagg aa
--      JOIN geo.ocean_geom bb ON (public.st_intersects(aa."position", bb.geom)))
--      LEFT JOIN ais.ship_details_agg cc ON ((aa.mmsi = cc.mmsi)))
--      LEFT JOIN ais.nav_status dd ON (((aa.nav_status)::text = dd.nav_status)))
--   WHERE (((bb.geoname)::text = 'South African Exclusive Economic Zone'::text) AND ((cc.type_and_cargo)::text = '30'::text) AND (aa.bucket > (now() - '25:00:00'::interval)) AND (cc.flag_state <> 'South Africa'::text))
--   ORDER BY aa.mmsi, aa.event_time DESC, cc.event_time DESC, bb.level DESC;


-- ALTER TABLE alerting.foreign_fishing_report OWNER TO rory;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 665 (class 1259 OID 332892)
-- Name: history; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.history (
    job_id integer,
    job_name name NOT NULL,
    start_time timestamp without time zone NOT NULL,
    runtime interval NOT NULL,
    mailed_to text,
    job_end_state text,
    job_end_time timestamp with time zone,
    user_id integer,
    report_id integer
);


-- ALTER TABLE alerting.history OWNER TO rory;

--
-- TOC entry 648 (class 1259 OID 326143)
-- Name: iran_vessels; Type: VIEW; Schema: alerting; Owner: rory
--

-- CREATE VIEW alerting.iran_vessels AS
--  WITH rsa_eez AS (
--          SELECT ocean_geom.geom
--            FROM geo.ocean_geom
--           WHERE ((ocean_geom.geoname)::text = 'South African Exclusive Economic Zone'::text)
--         ), report_data AS (
--          SELECT DISTINCT ON (aa.imo) dd.geoname AS "Location",
--             round(((public.st_distance(cc."position", rsa_eez.geom) * (60)::double precision))::numeric, 0) AS "Distance to RSA EEZ [nautical miles]",
--             aa.name AS "Name",
--             bb.mmsi AS "MMSI",
--             bb.imo AS "IMO",
--             bb.callsign AS "Radio Callsign",
--             bb.type_and_cargo_text AS "Vessel Type",
--             bb.flag_state AS "Flag",
--             cc.event_time AS "Last Message",
--             date_trunc('minute'::text, (now() - cc.event_time)) AS "Time since Last Message",
--             round((cc.latitude)::numeric, 3) AS lat,
--             round((cc.longitude)::numeric, 3) AS lon,
--             cc.cog AS "Course [Degrees]",
--             cc.sog AS "Speed [Knots]"
--            FROM rsa_eez,
--             (((pan.vessels_of_interest aa
--              LEFT JOIN ais.ship_details_agg bb ON ((aa.imo = bb.imo)))
--              LEFT JOIN ais.hourly_pos_cagg cc ON ((bb.mmsi = cc.mmsi)))
--              LEFT JOIN geo.ocean_geom dd ON (public.st_within(cc."position", dd.geom)))
--           WHERE (cc.bucket > (now() - '14 days'::interval))
--           ORDER BY aa.imo, bb.event_time DESC, dd.level
--         )
--  SELECT report_data."Location",
--     report_data."Distance to RSA EEZ [nautical miles]",
--     report_data."Name",
--     report_data."MMSI",
--     report_data."IMO",
--     report_data."Radio Callsign",
--     report_data."Vessel Type",
--     report_data."Flag",
--     report_data."Last Message",
--     report_data."Time since Last Message",
--     report_data.lat,
--     report_data.lon,
--     report_data."Course [Degrees]",
--     report_data."Speed [Knots]"
--    FROM report_data
--   ORDER BY report_data."Distance to RSA EEZ [nautical miles]";


-- ALTER TABLE alerting.iran_vessels OWNER TO rory;

--
-- TOC entry 650 (class 1259 OID 326150)
-- Name: jobs; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.jobs (
    id integer NOT NULL,
    application_name name NOT NULL,
    schedule_interval interval NOT NULL,
    max_runtime interval NOT NULL,
    max_retries integer NOT NULL,
    retry_period interval NOT NULL,
    owner name DEFAULT CURRENT_ROLE NOT NULL,
    scheduled boolean DEFAULT true NOT NULL,
    config jsonb,
    report_id integer,
    last_run timestamp with time zone
);


-- ALTER TABLE alerting.jobs OWNER TO rory;

--
-- TOC entry 649 (class 1259 OID 326148)
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: alerting; Owner: rory
--

CREATE SEQUENCE alerting.jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


-- ALTER TABLE alerting.jobs_id_seq OWNER TO rory;

--
-- TOC entry 6744 (class 0 OID 0)
-- Dependencies: 649
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: alerting; Owner: rory
--

ALTER SEQUENCE alerting.jobs_id_seq OWNED BY alerting.jobs.id;


--
-- TOC entry 645 (class 1259 OID 326120)
-- Name: reports; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.reports (
    report_id integer DEFAULT nextval('pan.reports_report_id_seq'::regclass) NOT NULL,
    report_name text,
    report_type text,
    source_type text,
    report_source text,
    creation_date timestamp with time zone,
    version text
);


-- ALTER TABLE alerting.reports OWNER TO rory;

--
-- TOC entry 669 (class 1259 OID 332930)
-- Name: user_reports; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.user_reports (
    id integer NOT NULL,
    user_id integer,
    report_id integer
);


-- ALTER TABLE alerting.user_reports OWNER TO rory;

--
-- TOC entry 667 (class 1259 OID 332905)
-- Name: users; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.users (
    id integer NOT NULL,
    user_name text,
    email_addr text,
    enabled boolean DEFAULT false,
    org text
);


-- ALTER TABLE alerting.users OWNER TO rory;

--
-- TOC entry 677 (class 1259 OID 343980)
-- Name: jobs_to_run; Type: VIEW; Schema: alerting; Owner: rory
--

CREATE VIEW alerting.jobs_to_run AS
 WITH last_run_details AS (
         SELECT DISTINCT ON (history.user_id, history.report_id, history.job_id) history.start_time AS last_time_run,
            history.user_id,
            history.report_id,
            history.job_id,
            history.job_end_state AS prev_end_state
           FROM alerting.history
          WHERE (history.job_end_state = 'success'::text)
          ORDER BY history.user_id, history.report_id, history.job_id, history.start_time DESC
        ), jobs_to_run AS (
         SELECT users.id AS user_id,
            reports.report_id,
            jobs.id AS job_id,
            users.enabled AS user_is_enabled,
            jobs.scheduled AS job_is_enabled,
            users.user_name,
            users.email_addr,
            users.org,
            reports.report_name,
            reports.report_type,
            reports.source_type,
            reports.report_source,
            reports.creation_date,
            reports.version,
            jobs.application_name,
            jobs.schedule_interval,
            jobs.max_runtime,
            jobs.max_retries,
            jobs.retry_period
           FROM (((alerting.users users
             JOIN alerting.user_reports aa_1 ON ((users.id = aa_1.user_id)))
             JOIN alerting.reports reports ON ((aa_1.report_id = reports.report_id)))
             JOIN alerting.jobs jobs ON ((jobs.report_id = reports.report_id)))
        )
 SELECT aa.user_id,
    aa.report_id,
    aa.job_id,
    aa.user_is_enabled,
    aa.job_is_enabled,
    aa.user_name,
    aa.email_addr,
    aa.org,
    aa.report_name,
    aa.report_type,
    aa.source_type,
    aa.report_source,
    aa.creation_date,
    aa.version,
    aa.application_name,
    aa.schedule_interval,
    aa.max_runtime,
    aa.max_retries,
    aa.retry_period,
    bb.last_time_run,
    bb.prev_end_state
   FROM (jobs_to_run aa
     LEFT JOIN last_run_details bb ON (((aa.user_id = bb.user_id) AND (aa.report_id = bb.report_id) AND (aa.job_id = bb.job_id))))
  WHERE ((bb.last_time_run < (now() - aa.schedule_interval)) OR (bb.last_time_run IS NULL));


-- ALTER TABLE alerting.jobs_to_run OWNER TO rory;

--
-- TOC entry 674 (class 1259 OID 336869)
-- Name: test; Type: VIEW; Schema: alerting; Owner: rory
--

CREATE VIEW alerting.test AS
 SELECT pos_reports.mmsi,
    pos_reports.navigation_status,
    pos_reports.rot,
    pos_reports.sog,
    pos_reports.longitude,
    pos_reports.latitude,
    pos_reports."position",
    pos_reports.cog,
    pos_reports.hdg,
    pos_reports.event_time,
    pos_reports.server_time,
    pos_reports.msg_type,
    pos_reports.routing_key
   FROM ais.pos_reports
  ORDER BY pos_reports.event_time DESC
 LIMIT 1;


-- ALTER TABLE alerting.test OWNER TO rory;

--
-- TOC entry 668 (class 1259 OID 332928)
-- Name: user_reports_id_seq; Type: SEQUENCE; Schema: alerting; Owner: rory
--

CREATE SEQUENCE alerting.user_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


-- ALTER TABLE alerting.user_reports_id_seq OWNER TO rory;

--
-- TOC entry 6745 (class 0 OID 0)
-- Dependencies: 668
-- Name: user_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: alerting; Owner: rory
--

ALTER SEQUENCE alerting.user_reports_id_seq OWNED BY alerting.user_reports.id;


--
-- TOC entry 666 (class 1259 OID 332903)
-- Name: users_id_seq; Type: SEQUENCE; Schema: alerting; Owner: rory
--

CREATE SEQUENCE alerting.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


-- ALTER TABLE alerting.users_id_seq OWNER TO rory;

--
-- TOC entry 6746 (class 0 OID 0)
-- Dependencies: 666
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: alerting; Owner: rory
--

ALTER SEQUENCE alerting.users_id_seq OWNED BY alerting.users.id;


--
-- TOC entry 646 (class 1259 OID 326129)
-- Name: vessels_of_interest; Type: TABLE; Schema: alerting; Owner: rory
--

CREATE TABLE alerting.vessels_of_interest (
    interest_id integer DEFAULT nextval('pan.vessels_of_interest_interest_id_seq'::regclass) NOT NULL,
    name text,
    type text,
    imo text,
    reason text,
    creation_date timestamp with time zone,
    mmsi text
);


-- ALTER TABLE alerting.vessels_of_interest OWNER TO rory;

--
-- TOC entry 6475 (class 2604 OID 326153)
-- Name: jobs id; Type: DEFAULT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.jobs ALTER COLUMN id SET DEFAULT nextval('alerting.jobs_id_seq'::regclass);


--
-- TOC entry 6480 (class 2604 OID 332933)
-- Name: user_reports id; Type: DEFAULT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.user_reports ALTER COLUMN id SET DEFAULT nextval('alerting.user_reports_id_seq'::regclass);


--
-- TOC entry 6478 (class 2604 OID 332908)
-- Name: users id; Type: DEFAULT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.users ALTER COLUMN id SET DEFAULT nextval('alerting.users_id_seq'::regclass);


--
-- TOC entry 6486 (class 2606 OID 332891)
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- TOC entry 6482 (class 2606 OID 326128)
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (report_id);


--
-- TOC entry 6490 (class 2606 OID 332935)
-- Name: user_reports user_reports_pkey; Type: CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.user_reports
    ADD CONSTRAINT user_reports_pkey PRIMARY KEY (id);


--
-- TOC entry 6488 (class 2606 OID 332913)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 6484 (class 2606 OID 326137)
-- Name: vessels_of_interest vessels_of_interest_pkey; Type: CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.vessels_of_interest
    ADD CONSTRAINT vessels_of_interest_pkey PRIMARY KEY (interest_id);


--
-- TOC entry 6492 (class 2606 OID 332898)
-- Name: history fk_user_id; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT fk_user_id FOREIGN KEY (job_id) REFERENCES alerting.jobs(id);


--
-- TOC entry 6491 (class 2606 OID 333716)
-- Name: jobs jobs_fk_report_id; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.jobs
    ADD CONSTRAINT jobs_fk_report_id FOREIGN KEY (report_id) REFERENCES alerting.reports(report_id);


--
-- TOC entry 6493 (class 2606 OID 343959)
-- Name: history report_fk_id; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT report_fk_id FOREIGN KEY (report_id) REFERENCES alerting.reports(report_id);


--
-- TOC entry 6495 (class 2606 OID 332941)
-- Name: user_reports reports_fk_reports; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.user_reports
    ADD CONSTRAINT reports_fk_reports FOREIGN KEY (report_id) REFERENCES alerting.reports(report_id);


--
-- TOC entry 6494 (class 2606 OID 336976)
-- Name: history user_fk_history; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT user_fk_history FOREIGN KEY (user_id) REFERENCES alerting.users(id);


--
-- TOC entry 6496 (class 2606 OID 332936)
-- Name: user_reports user_fk_reports; Type: FK CONSTRAINT; Schema: alerting; Owner: rory
--

ALTER TABLE ONLY alerting.user_reports
    ADD CONSTRAINT user_fk_reports FOREIGN KEY (user_id) REFERENCES alerting.users(id);


--
-- TOC entry 6743 (class 0 OID 0)
-- Dependencies: 650
-- Name: TABLE jobs; Type: ACL; Schema: alerting; Owner: rory
--

GRANT SELECT ON TABLE alerting.jobs TO PUBLIC;


-- Completed on 2021-07-26 14:19:29 UTC

--
-- PostgreSQL database dump complete
--

