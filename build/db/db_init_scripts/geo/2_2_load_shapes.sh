#!/bin/bash
echo 'Downloading shapefiles from Marine Regions WFS...'
mkdir -p /tmp/shapes
mkdir -p /tmp/unzips
rm -rf /tmp/unzips/*

if [ ! -f /tmp/shapes/world_eez.zip ]; then
    echo '--- Downloading World EEZ v11...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_eez.zip
else
    echo 'World EEZ file exists. Skip download.'
fi
echo '--- Loading World EEZ v11'
unzip /tmp/shapes/world_eez.zip -d /tmp/unzips/.
shp2pgsql -I /tmp/unzips/eez.shp geo.world_eez | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/world_24nm.zip ]; then
    echo '--- Downloading World 24 NM...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_24nm&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_24nm.zip
else
    echo 'World 24 NM file exists. Skip download.'
fi
echo '--- Loading World 24 NM'
unzip /tmp/shapes/world_24nm.zip -d /tmp/unzips/.
shp2pgsql -I /tmp/unzips/eez_24nm.shp geo.eez_24nm | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/world_12nm.zip ]; then
    echo '--- Downloading World 12 NM...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_12nm&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_12nm.zip
else
    echo 'World 12 NM file exists. Skip download.'
fi
echo '--- Loading World 12 NM'
unzip /tmp/shapes/world_12nm.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/eez_12nm.shp geo.eez_12nm | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/world_int_waters.zip ]; then
    echo '--- Downloading World Internal Waters...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_internal_waters&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_int_waters.zip
else
    echo 'World Internal Waters file exists. Skip download.'
fi
echo '--- Loading World Internal Waters'
unzip /tmp/shapes/world_int_waters.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/eez_internal_waters.shp geo.eez_internal_waters | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/world_archi_waters.zip ]; then
    echo '--- Downloading World Archipelagic Waters...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_archipelagic_waters&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_archi_waters.zip
else
    echo 'World World Archipelagic Waters file exists. Skip download.'
fi
echo '--- Loading World Archipelagic Waters'
unzip /tmp/shapes/world_archi_waters.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/eez_archipelagic_waters.shp geo.eez_archipelagic_waters | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/high_seas.zip ]; then
    echo '--- Downloading World High Seas v1...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=high_seas&outputformat=SHAPE-ZIP" -O /tmp/shapes/high_seas.zip
else
    echo 'High Seas file exists. Skip download.'
fi
echo '--- Loading World High Seas v1' 
unzip /tmp/shapes/high_seas.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/high_seas.shp geo.oceans_world | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
echo 'Downloading shapefiles from other places'
######################################################
if [ ! -f /tmp/shapes/wpi.zip ]; then
    echo '--- Downloading World Port Index...'
    wget -q "https://msi.nga.mil/api/publications/download?key=16694622/SFH00000/WPI_Shapefile.zip&type=view" -O /tmp/shapes/wpi.zip
else
    echo 'WPI file exists. Skip download.'
fi
echo '--- Loading World Port Index'
unzip /tmp/shapes/wpi.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/WPI.shp geo.world_port_index | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/sampaz.zip ]; then
    echo '--- Downloading DEFF SAMPAZ MPA List...'
    wget -q "https://sfiler.environment.gov.za:8443/ssf/s/readFile/folderEntry/40950/8afbc1c77a484088017a5d45cb4202e6/1624344206000/last/SAMPAZ_OR_2021_Q1.zip" -O /tmp/shapes/sampaz.zip
else
    echo 'SAMPAZ file exists. Skip download.'
fi
echo '--- Loading DEFF SAMPAZ MPA List'
unzip /tmp/shapes/sampaz.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/SAMPAZ_OR_2021_Q1.shp geo.sampaz | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
if [ ! -f /tmp/shapes/country.zip ]; then
    echo '--- Downloading Admin Boundaries for Countries...'
    wget -q "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_countries.zip" -O /tmp/shapes/country.zip
else
    echo 'Admin Boundaries file exists. Skip download.'
fi
echo '--- Loading Country Admin Boundaries'
unzip /tmp/shapes/country.zip -d /tmp/unzips/
shp2pgsql -I /tmp/unzips/ne_50m_admin_0_countries.shp geo.admin_0_countriesd_eez | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
rm -rf ../unzips/*

######################################################
echo '==============================================='
echo 'Downloads Complete and inserted into geo schema' 
echo '==============================================='

# shp2pgsql -I /tmp/World_EEZ_v10_20180221/eez_boundaries_v10.shp geo.world_eez | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
# shp2pgsql -I /tmp/WPI_Shapefile/WPI.shp geo.world_port_index | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}