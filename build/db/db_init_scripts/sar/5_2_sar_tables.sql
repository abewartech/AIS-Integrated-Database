
CREATE TABLE public.sar_bilge
(
    database_id character varying(20) COLLATE pg_catalog."default",
    routing_key text COLLATE pg_catalog."default",
    server_timestamp timestamp with time zone NOT NULL,
    event_timestamp timestamp with time zone NOT NULL,
    message_type text COLLATE pg_catalog."default",
    "position" geometry(Point,4326) NOT NULL,
    boundbox geometry(Geometry,4326),
    bilge_polygon geometry(Geometry,4326),
    sar_polarization text COLLATE pg_catalog."default",
    sar_folder_name text COLLATE pg_catalog."default",
    sar_file_name text COLLATE pg_catalog."default",
    sar_image_id character varying(8) COLLATE pg_catalog."default",
    sar_pixel_size integer,
    sar_beam_mode text COLLATE pg_catalog."default",
    sar_processing_level character varying(8) COLLATE pg_catalog."default",
    sar_bilge_number integer,
    sar_bilge_row integer,
    sar_bilge_col integer,
    sar_bilge_length numeric(5,2),
    sar_bilge_width numeric(5,2),
    bilge_within_eez text COLLATE pg_catalog."default",
    bilge_distance_to_eez numeric(5,2)
);


CREATE TABLE public.sar_vessels
(
    database_id character varying(20) COLLATE pg_catalog."default",
    server_timestamp timestamp with time zone NOT NULL,
    event_timestamp timestamp with time zone NOT NULL,
    "position" geometry(Point,4326) NOT NULL,
    heading integer,
    sar_image_id character varying(8) COLLATE pg_catalog."default",
    sar_ship_number integer,
    sar_ship_row integer,
    sar_ship_col integer,
    sar_ship_length numeric(5,2),
    sar_ship_width numeric(5,2),
    sar_ship_image_dtype text COLLATE pg_catalog."default",
    sar_ship_ml_info text COLLATE pg_catalog."default",
    id serial PRIMARY KEY,
    sar_ship_image_data integer[],
    polarization text COLLATE pg_catalog."default",
    routing_key text COLLATE pg_catalog."default",
    sar_ship_image_scaled_data integer[],
    dark_target integer NOT NULL DEFAULT 0,
    auto_match text COLLATE pg_catalog."default",
    manual_match text COLLATE pg_catalog."default",
    nearby_port text COLLATE pg_catalog."default",
    distance_to_port_km numeric,
    within_eez boolean,
    distance_to_eez_km numeric,
    sar_ship_patch_data integer[],
    sar_ship_patch_dtype text COLLATE pg_catalog."default",
    lag_ais_id bigint,
    lead_ais_id bigint
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;
 
CREATE INDEX 
    ON public.sar_vessels USING gist
    ("position")
    TABLESPACE pg_default;
-- Index: sar_ves_pos

-- DROP INDEX public.sar_ves_pos;



CREATE TABLE public.sar_images
(
    database_id character varying(8) COLLATE pg_catalog."default",
    server_timestamp timestamp with time zone NOT NULL,
    event_timestamp timestamp with time zone NOT NULL,
    sar_sensor character varying(3) COLLATE pg_catalog."default",
    sar_rows integer,
    sar_cols integer,
    sar_beam_mode character varying(5) COLLATE pg_catalog."default",
    sar_polarization character varying(2) COLLATE pg_catalog."default",
    sar_processing_level character varying(5) COLLATE pg_catalog."default",
    sar_folder_name text COLLATE pg_catalog."default",
    sar_file_name text COLLATE pg_catalog."default",
    sar_num_bilge_detections integer,
    sar_num_ship_detections integer,
    sar_proc_environment text COLLATE pg_catalog."default",
    id serial PRIMARY KEY,
    routing_key text COLLATE pg_catalog."default",
    geom geometry(Polygon,4326),
    dark_target_processed boolean DEFAULT false,
    nearest_port text COLLATE pg_catalog."default",
    nearest_port_dist_km numeric,
    sar_centroid_lon double precision,
    sar_centroid_lat double precision 
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;


CREATE INDEX 
    ON public.sar_images USING gist
    (geom)
    TABLESPACE pg_default;