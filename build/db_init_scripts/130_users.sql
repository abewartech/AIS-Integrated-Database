-- Create roles for new users and assign them the the users
-- Users should include
--   admin user: These users can do anything
--   write user: can only write to certain schemas
--   API data reader: can only read from certain schemas

CREATE USER api WITH PASSWORD 'Secure_API_Password' LOGIN;
GRANT USAGE ON SCHEMA postgis_ftw TO api;
GRANT SELECT ON ALL TABLES IN SCHEMA postgis_ftw TO api;
ALTER DEFAULT PRIVILEGES IN SCHEMA postgis_ftw GRANT SELECT ON TABLES TO api;

