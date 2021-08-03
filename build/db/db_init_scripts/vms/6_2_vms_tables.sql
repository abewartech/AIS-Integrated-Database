-- Table: public.login_vms_history

-- DROP TABLE public.login_vms_history;

CREATE TABLE vms.vms_history
(
    "position" geometry(Point,4326) NOT NULL,
    event_time timestamp with time zone NOT NULL,
    server_time timestamp with time zone NOT NULL,
    cog numeric(3,0),
    sog numeric(4,1),
    port_from character varying(3) COLLATE pg_catalog."default",
    name text COLLATE pg_catalog."default",
    callsign text COLLATE pg_catalog."default",
    flag_state character varying(3) COLLATE pg_catalog."default",
    routing_key text COLLATE pg_catalog."default",
    id serial PRIMARY KEY 
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

-- Index: login_vms_history_callsign_idx

-- DROP INDEX public.login_vms_history_callsign_idx;

CREATE INDEX 
    ON vms.vms_history USING btree
    (callsign COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: login_vms_history_event_time_idx

-- DROP INDEX public.login_vms_history_event_time_idx;

CREATE INDEX 
    ON vms.vms_history USING btree
    (event_time ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: vms_ves_pos

-- DROP INDEX public.vms_ves_pos;

CREATE INDEX 
    ON vms.vms_history USING gist
    ("position")
    TABLESPACE pg_default;