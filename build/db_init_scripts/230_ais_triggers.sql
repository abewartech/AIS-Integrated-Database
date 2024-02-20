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



-- This trigger is intended to keep the ais.latest_vessel_details table up to date
-- by updating or inserting new voyage reports.

CREATE FUNCTION ais.vessel_details_upsert_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ais.latest_voy_reports AS aa
	VALUES(NEW.mmsi,
		   NEW.imo,
		   NEW.callsign,
		   NEW.name,
		   NEW.type_and_cargo,
		   NEW.to_bow,
		   NEW.to_stern,
		   NEW.to_port,
		   NEW.to_starboard,
		   NEW.fix_type,
		   NEW.eta_month,
		   NEW.eta_day,
		   NEW.eta_hour, 
		   NEW.eta_minute,
		   NEW.eta,
		   NEW.draught,
		   NEW.destination,
		   NEW.server_time,
		   NEW.event_time,
		   NEW.msg_type,
		   NEW.routing_key)
	ON CONFLICT (mmsi, routing_key)
	DO UPDATE SET 
		mmsi = COALESCE(EXCLUDED.mmsi, aa.mmsi), 
		imo = COALESCE(EXCLUDED.imo, aa.imo),
		callsign= COALESCE(EXCLUDED.callsign, aa.callsign),
		name= COALESCE(EXCLUDED.name, aa.name),
		type_and_cargo= COALESCE(EXCLUDED.type_and_cargo, aa.type_and_cargo),
		to_bow= COALESCE(EXCLUDED.to_bow, aa.to_bow),
		to_stern= COALESCE(EXCLUDED.to_stern, aa.to_stern),
		to_port= COALESCE(EXCLUDED.to_port, aa.to_port),
		to_starboard= COALESCE(EXCLUDED.to_starboard, aa.to_starboard),
		fix_type= COALESCE(EXCLUDED.fix_type, aa.fix_type),
		eta_month= COALESCE(EXCLUDED.eta_month, aa.eta_month),
		eta_day= COALESCE(EXCLUDED.eta_day, aa.eta_day),
		eta_hour = COALESCE(EXCLUDED.eta_hour, aa.eta_hour),
		eta_minute = COALESCE(EXCLUDED.eta_minute, aa.eta_minute),
		eta = COALESCE(EXCLUDED.eta, aa.eta),
		draught = COALESCE(EXCLUDED.draught, aa.draught),
		destination = COALESCE(EXCLUDED.destination, aa.destination),
		server_time = COALESCE(EXCLUDED.server_time, aa.server_time),
		event_time = COALESCE(EXCLUDED.event_time, aa.event_time),
		msg_type = COALESCE(EXCLUDED.msg_type, aa.msg_type),
		routing_key = COALESCE(EXCLUDED.routing_key, aa.routing_key);
RETURN NEW;
END;
$$;

CREATE TRIGGER vessel_details_upsert AFTER INSERT ON ais.voy_reports FOR EACH ROW EXECUTE FUNCTION ais.vessel_details_upsert_func();
