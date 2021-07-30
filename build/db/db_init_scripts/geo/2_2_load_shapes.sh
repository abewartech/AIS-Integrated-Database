#!/bin/bash
echo 'Loading shapefiles into DB'
#shp2pgsql -I /tmp/World_EEZ_v10_20180221/eez_boundaries_v10.shp geo.world_eez | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
#shp2pgsql -I /tmp/WPI_Shapefile/WPI.shp geo.world_port_index | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}