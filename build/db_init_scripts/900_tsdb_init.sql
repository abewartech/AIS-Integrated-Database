-- These need to be called after data has been inserted in order to "kick start" the continous aggregates

CALL refresh_continuous_aggregate('ais.vessel_details_cagg', '2023-01-01', '2024-02-01');
CALL refresh_continuous_aggregate('ais.hourly_pos_cagg', '2023-01-01', '2024-02-01');
CALL refresh_continuous_aggregate('ais.daily_pos_cagg', '2023-01-01', '2024-02-01');
CALL refresh_continuous_aggregate('ais.daily_30min_trajectories_cagg', '2023-01-01', '2024-02-01');
