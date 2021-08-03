-- Building spatial indexes for the tables loaded with script 2.

-- CREATE INDEX world_eez_geom_idx
--     ON geo.world_eez USING gist
--     (geom)
--     TABLESPACE pg_default;

    
-- CREATE INDEX world_port_index_geom_idx
--     ON geo.world_port_index USING gist
--     (geom)
--     TABLESPACE pg_default;