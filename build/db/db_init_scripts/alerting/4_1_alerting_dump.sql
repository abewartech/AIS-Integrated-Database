--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5
-- Dumped by pg_dump version 12.5

-- Started on 2021-07-26 14:19:26 UTC

-- SET statement_timeout = 0;
-- SET lock_timeout = 0;
-- SET idle_in_transaction_session_timeout = 0;
-- SET client_encoding = 'UTF8';
-- SET standard_conforming_strings = on;
-- SELECT pg_catalog.set_config('search_path', '', false);
-- SET check_function_bodies = false;
-- SET xmloption = content;
-- SET client_min_messages = warning;
-- SET row_security = off;
 

CREATE SCHEMA alerting;

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
 

CREATE TABLE alerting.jobs (
    id SERIAL PRIMARY KEY,
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
 
ALTER SEQUENCE alerting.jobs_id_seq OWNED BY alerting.jobs.id;
 
CREATE TABLE alerting.reports (
    id SERIAL PRIMARY KEY,
    report_name text,
    report_type text,
    source_type text,
    report_source text,
    creation_date timestamp with time zone,
    version text
); 

CREATE TABLE alerting.user_reports (
    id SERIAL PRIMARY KEY,
    user_id integer,
    report_id integer
);

CREATE TABLE alerting.users (
    id SERIAL PRIMARY KEY,
    user_name text,
    email_addr text,
    enabled boolean DEFAULT false,
    org text
);

 
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
            reports.id,
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
             JOIN alerting.reports reports ON ((aa_1.report_id = reports.id)))
             JOIN alerting.jobs jobs ON ((jobs.report_id = reports.id)))
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
  
   
CREATE TABLE alerting.vessels_of_interest (
    id SERIAL PRIMARY KEY,
    name text,
    type text,
    imo text,
    reason text,
    creation_date timestamp with time zone,
    mmsi text
);

         

ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT fk_user_id FOREIGN KEY (job_id) REFERENCES alerting.jobs(id);
 
ALTER TABLE ONLY alerting.jobs
    ADD CONSTRAINT jobs_fk_report_id FOREIGN KEY (report_id) REFERENCES alerting.reports(id);
 
ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT report_fk_id FOREIGN KEY (report_id) REFERENCES alerting.reports(id);
 
ALTER TABLE ONLY alerting.user_reports
    ADD CONSTRAINT reports_fk_reports FOREIGN KEY (report_id) REFERENCES alerting.reports(id);
 
ALTER TABLE ONLY alerting.history
    ADD CONSTRAINT user_fk_history FOREIGN KEY (user_id) REFERENCES alerting.users(id);
 
ALTER TABLE ONLY alerting.user_reports
    ADD CONSTRAINT user_fk_reports FOREIGN KEY (user_id) REFERENCES alerting.users(id);
 