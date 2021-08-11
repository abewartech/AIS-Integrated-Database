--
-- Data for Name: dummy_foreign_flag_fishing; Type: TABLE DATA; Schema: ais; Owner: -
--
CREATE SCHEMA testing;
CREATE TABLE testing.foreign_flag_fishing
(
    mmsi text, 
    name text, 
    callsign text, 
    flag_state text, 
    last_position_report timestamp with time zone, 
    dms text, 
    longitude double precision NOT NULL,
    latitude double precision NOT NULL,
    cog numeric(4, 1),
    sog numeric(4, 1), 
    navigation_status text,
    location text

);
 
COPY testing.foreign_flag_fishing (mmsi, name, callsign, flag_state, last_position_report, dms, longitude, latitude,cog,sog,navigation_status,location)
FROM '/tmp/dummy_fff_report.csv' DELIMITER ',' CSV HEADER;


CREATE view api.foreign_flag_fishing AS SELECT * FROM  testing.foreign_flag_fishing;
GRANT SELECT ON api.foreign_flag_fishing TO web_anon;


-- INSERT testing.foreign_flag_fishing ("MMSI", "Name", "Callsign", "Flag State", "Last Position Report", "DMS", lon, lat, "Course", "Speed", "Nav Status", "Location") FROM stdin;
-- 224132000, ZUMAYA DOUS, ECBF, Spain, 2021-08-06 11:48:36+00, 31°36'10.698"S 33°51'6.594"E, 33.85183166666667, -31.602971666666665, 127.3, 6.0, \N, South African Exclusive Economic Zone
-- 416005644, YUN MAO NO.1, \N, Taiwan, 2021-08-06 13:47:47.041006+00, 33°54'18.168"S 18°26'37.230"E, 18.443675, -33.905046666666664, 332.5, 0.0, \N, South African Exclusive Economic Zone
-- 416331000, KAO FONG NO8, \N, Taiwan, 2021-08-06 13:24:00.63048+00, 33°48'22.224"S 17°54'49.866"E, 17.913851666666666, -33.806173333333334, 279.5, 9.5, \N, South African Exclusive Economic Zone
-- 440154000, NO.805 ORYONG, 6KAI, Korea, 2021-08-06 13:29:56+00, 32°37'21.234"S 16°12'50.352"E, 16.213986666666667, -32.622565, 128.2, 8.7, \N, South African Exclusive Economic Zone
-- 440863000, SAE IN LEADER, DTBP9, Korea, 2021-08-06 13:49:05.186359+00, 33°54'18.372"S 18°26'22.980"E, 18.439716666666666, -33.90510333333334, 0.0, 0.0, Under way sailing, South African Exclusive Economic Zone
-- 441645000, NO.638 DONG WON, DTBW9, Korea, 2021-08-06 13:32:02+00, 34°56'36.660"S 16°35'8.040"E, 16.585566666666665, -34.94351666666667, 53.2, 8.9, \N, South African Exclusive Economic Zone
-- 613003609, AVACHINSKY, TJMC64 Cameroon, 2021-08-06 13:47:10+00, 33°55'2.154"S 18°26'22.278"E, 18.439521666666668, -33.917265, 211.1, 0.0, Moored, South African Exclusive Economic Zone
-- \.


-- --
-- -- PostgreSQL database dump complete
-- --
