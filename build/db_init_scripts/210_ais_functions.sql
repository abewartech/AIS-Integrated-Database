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
-- Name: ais_aggregation_1km_full(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: ais; Owner: vliz
--

CREATE FUNCTION ais.ais_aggregation_1km_full(begin_time timestamp without time zone, end_time timestamp without time zone) RETURNS TABLE(gid double precision, event_date date, type_and_cargo character varying, cardinal_seg numeric, sog_bin numeric, track_count bigint, avg_time_delta double precision, cum_time_in_grid double precision)
    LANGUAGE sql ROWS 1e+06 PARALLEL SAFE
    AS $_$
  
 SELECT 
    grid.gid,
    traj.event_date, 
    det.type_and_cargo, 
	trunc((mod(traj.cog + 22.5, 360) / (45)::numeric)) AS cardinal_seg,
	FLOOR(traj.sog) AS sog_bin,
	count(traj.traj) AS track_count,
    avg(traj.time_delta) AS avg_time_delta,
    sum(((st_length(st_intersection(traj.traj, grid.geom)) * traj.time_delta) / traj.traj_dist)) AS cum_time_in_grid
   FROM ((rory.aoi_hex_grid_1km2 grid
     LEFT JOIN ( SELECT subquery.mmsi,
            subquery.event_date,
            subquery.cog,
            subquery.sog,
            subquery.time_delta,
            st_makeline(subquery.pos, subquery.pos2) AS traj,
            st_distance(subquery.pos, subquery.pos2) AS traj_dist
           FROM ( SELECT ais.mmsi,
                    date(ais.event_time) AS event_date,
                    date_part('epoch'::text, (lead(ais.event_time) OVER time_order - ais.event_time)) AS time_delta,
                    ais."position" AS pos,
                    NULLIF(ais.sog, 102.3) AS sog,
                    NULLIF(ais.cog, 360.0) AS cog,
                    ais.navigation_status,
                    lead(ais."position") OVER time_order AS pos2
                   FROM ais.pos_reports ais
 WHERE ((ais.event_time >= $1) 
	  AND (ais.event_time <= $2))
                  WINDOW time_order AS (PARTITION BY ais.mmsi ORDER BY ais.event_time)) subquery
          WHERE (subquery.pos2 IS NOT NULL)) traj ON (st_intersects(traj.traj, grid.geom)))
     LEFT JOIN ais.latest_voy_reports det ON ((traj.mmsi = det.mmsi)))
  WHERE ((traj.traj_dist > (0)::double precision) AND (traj.time_delta > (0)::double precision) AND (traj.traj_dist < (0.05)::double precision))
  GROUP BY grid.gid, det.type_and_cargo, traj.event_date, FLOOR(traj.sog), trunc((mod(traj.cog + 22.5, 360) / (45)::numeric))
 
$_$;


CREATE PROCEDURE ais.build_trajectories(job_id integer, config jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
  WITH lead_lag AS (
         SELECT ais.mmsi,
            ais."position",
            ais.event_time,
            ais.sog,
            lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time) <= (ais.event_time - '01:00:00'::interval) AS time_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) < 0::double precision OR st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) > 0.1::double precision AS dist_step,
            (st_distancesphere(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) / NULLIF(date_part('epoch'::text, ais.event_time - lag(ais.event_time) OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)), 0::double precision)) >= (2::numeric * (ais.sog + 0.5))::double precision AS sog_step,
            st_distance(ais."position", lag(ais."position") OVER (PARTITION BY ais.mmsi ORDER BY ais.event_time)) AS dist
           FROM ais.pos_reports ais
          WHERE ais.event_time >= date(now()) - interval '1 day' AND ais.event_time <= date(now()) 
        ), lead_lag_groups AS (
         SELECT lead_lag_1.mmsi,
            lead_lag_1."position",
            lead_lag_1.event_time,
            lead_lag_1.sog,
            lead_lag_1.time_step,
            lead_lag_1.dist_step,
            lead_lag_1.dist,
            lead_lag_1.sog_step,
            count(*) FILTER (WHERE lead_lag_1.time_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS time_grp,
            count(*) FILTER (WHERE lead_lag_1.dist_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS dist_grp,
            count(*) FILTER (WHERE lead_lag_1.sog_step) OVER (PARTITION BY lead_lag_1.mmsi ORDER BY lead_lag_1.event_time) AS sog_grp
           FROM lead_lag lead_lag_1
          WHERE lead_lag_1.dist > 0::double precision
        )
	  INSERT INTO ais.trajectories 
 SELECT 
		  lead_lag.mmsi,
		lead_lag.time_grp,
		lead_lag.dist_grp,
		lead_lag.sog_grp,
		first(lead_lag.event_time, lead_lag.event_time) AS first_time,
		last(lead_lag.event_time, lead_lag.event_time) AS last_time,
		st_length(st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326)) AS geom_length,
		st_setsrid(st_makeline(lead_lag."position" ORDER BY lead_lag.event_time), 4326) AS geom
	   FROM lead_lag_groups lead_lag 
  GROUP BY lead_lag.mmsi, lead_lag.time_grp, lead_lag.dist_grp, lead_lag.sog_grp;
END
$$;


CREATE PROCEDURE ais.create_yesterday_density(job_id integer, config jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
INSERT INTO ais.vessel_density_agg
SELECT 
    ais_heatmap.gid,
    ais_heatmap.event_date, 
    ais_heatmap.type_and_cargo,
    ais_heatmap.cardinal_seg,
    ais_heatmap.sog_bin,
    ais_heatmap.track_count, 
    ais_heatmap.avg_time_delta,
    ais_heatmap.cum_time_in_grid
   FROM ais.ais_aggregation_1km_full((current_date - INTERVAL '2 day')::date,
									 (current_date - INTERVAL '1 day')::date) as ais_heatmap ;
END
$$;
