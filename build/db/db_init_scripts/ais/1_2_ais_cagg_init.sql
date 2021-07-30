
BEGIN;

DROP MATERIALIZED VIEW IF EXISTS ais.vessel_details_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.vessel_details_cagg WITH
(timescaledb.continuous )
AS
SELECT 
	mmsi,
	time_bucket('1d', event_time) as day,
	last(imo, event_time) as imo,
	last(callsign, event_time) as callsign,
	last(name, event_time) as name,
	last(type_and_cargo, event_time) as type_and_cargo,
	last(to_bow, event_time) as to_bow,
	last(to_stern, event_time) as to_stern,
	last(to_port, event_time) as to_port,
	last(to_starboard, event_time) as to_starboard,
	last(fix_type, event_time) as fix_type,
	last(eta_month, event_time) as eta_month,
	last(eta_day, event_time) as eta_day,
	last(eta_hour, event_time) as eta_hour,
	last(eta_minute, event_time) as eta_minute,
	last(eta, event_time) as eta,
	last(draught, event_time) as draught,
	last(destination, event_time) as destination,
	last(event_time, event_time) as event_time,
	last(msg_type, event_time) as msg_type,
	last(routing_key, event_time) as routing_key
FROM ais.voy_reports
GROUP BY mmsi, day, routing_key;

SELECT add_continuous_aggregate_policy('ais.vessel_details_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 h',
    schedule_interval => INTERVAL '1 h');

DROP MATERIALIZED VIEW IF EXISTS ais.hourly_pos_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.hourly_pos_cagg WITH
(timescaledb.continuous )
AS
 SELECT pos_reports.mmsi,
    time_bucket('00:30:00'::interval, pos_reports.event_time) AS bucket,
    last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    last(pos_reports."position", pos_reports.event_time) AS "position",
    last(pos_reports.cog, pos_reports.event_time) AS cog,
    last(pos_reports.sog, pos_reports.event_time) AS sog,
    last(pos_reports.navigation_status, pos_reports.event_time) AS nav_status,    
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, (time_bucket('01:00:00'::interval, pos_reports.event_time));

SELECT add_continuous_aggregate_policy('ais.hourly_pos_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '30 minutes',
    schedule_interval => INTERVAL '30 minutes');

DROP MATERIALIZED VIEW IF EXISTS ais.daily_pos_cagg CASCADE;
CREATE MATERIALIZED VIEW ais.daily_pos_cagg WITH
(timescaledb.continuous )
AS
   SELECT pos_reports.mmsi,
    time_bucket('12h'::interval, pos_reports.event_time) AS day,
    last(pos_reports.event_time, pos_reports.event_time) AS event_time,
    last(pos_reports.longitude, pos_reports.event_time) AS longitude,
    last(pos_reports.latitude, pos_reports.event_time) AS latitude,
    last(pos_reports."position", pos_reports.event_time) AS "position",
    last(pos_reports.cog, pos_reports.event_time) AS cog,
    last(pos_reports.sog, pos_reports.event_time) AS sog,
    avg(pos_reports.cog) AS avg_cog,
    avg(pos_reports.sog) AS avg_sog,
    max(pos_reports.cog) AS max_cog,
    max(pos_reports.sog) AS max_sog,
    min(pos_reports.cog) AS min_cog,
    min(pos_reports.sog) AS min_sog
   FROM ais.pos_reports
  GROUP BY pos_reports.mmsi, (time_bucket('1 day'::interval, pos_reports.event_time));

SELECT add_continuous_aggregate_policy('ais.daily_pos_cagg',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '30 minutes',
    schedule_interval => INTERVAL '30 minutes');

COMMIT;
