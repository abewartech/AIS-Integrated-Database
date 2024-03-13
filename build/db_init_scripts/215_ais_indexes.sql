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


-- --
-- CREATE INDEX latest_voy_reports_mmsi_idx ON ais.latest_voy_reports USING btree (mmsi);
-- --
-- -- CREATE INDEX voy_reports_event_time_idx ON ais.voy_reports USING btree (event_time DESC);
-- CREATE INDEX voy_reports_mmsi_event_time_idx ON ais.voy_reports USING btree (mmsi, event_time DESC);

-- -- PosReport Hypertable
-- CREATE INDEX pos_reports_event_time_idx ON ais.pos_reports USING btree (event_time DESC);
-- CREATE INDEX pos_reports_mmsi_event_time_idx ON ais.pos_reports USING btree (mmsi, event_time DESC);
-- CREATE INDEX pos_reports_position_idx ON ais.pos_reports USING gist ("position");

CREATE INDEX trajectories_first_time_mmsi_idx ON ais.trajectories USING btree (first_time DESC, mmsi);
CREATE INDEX trajectories_mmsi_first_time_idx ON ais.trajectories USING btree (mmsi, first_time DESC);

CREATE INDEX vessel_density_agg_event_date_idx ON ais.vessel_density_agg USING btree (event_date);
CREATE INDEX vessel_density_agg_gid_idx ON ais.vessel_density_agg USING btree (gid);