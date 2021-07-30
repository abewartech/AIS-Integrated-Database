-- Table: public.login_vms_history

-- DROP TABLE public.login_vms_history;

CREATE TABLE public.login_vms_history
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
    id bigint NOT NULL DEFAULT nextval('login_vms_history_id_seq'::regclass),
    CONSTRAINT login_vms_history_pkey PRIMARY KEY (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.login_vms_history
    OWNER to postgres;
-- Index: login_vms_history_callsign_idx

-- DROP INDEX public.login_vms_history_callsign_idx;

CREATE INDEX login_vms_history_callsign_idx
    ON public.login_vms_history USING btree
    (callsign COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: login_vms_history_event_time_idx

-- DROP INDEX public.login_vms_history_event_time_idx;

CREATE INDEX login_vms_history_event_time_idx
    ON public.login_vms_history USING btree
    (event_time ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: vms_ves_pos

-- DROP INDEX public.vms_ves_pos;

CREATE INDEX vms_ves_pos
    ON public.login_vms_history USING gist
    ("position")
    TABLESPACE pg_default;