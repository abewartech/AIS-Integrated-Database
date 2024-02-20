-- Create roles for new users and assign them the the users
-- Users should include
--   admin user: These users can do anything
--   write user: can only write to certain schemas
--   API data reader: can only read from certain schemas

CREATE ROLE readonly_api LOGIN; -- for API and untrusted users
CREATE ROLE readwrite_ais LOGIN; -- for DB inserters 
CREATE ROLE admin SUPERUSER LOGIN;
CREATE ROLE api WITH PASSWORD 'Secure_API_Password' LOGIN;

GRANT USAGE, SELECT ON ALL TABLES IN SCHEMA postgis_ftw TO readonly_api;
GRANT USAGE, SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ais TO readwrite_ais;
GRANT readonly_api TO api;
