#!/bin/bash
echo 'Downloading shapefiles from Marine Regions WFS...'
mkdir -p /tmp/shapes


if [ ! -f /tmp/shapes/world_eez.zip ]; then
    echo '--- Downloading World EEZ v11...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_boundaries&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_eez.zip
else
    echo 'World EEZ file exists. Skip download.'
fi


if [ ! -f /tmp/shapes/world_24nm.zip ]; then
    echo '--- Downloading World 24 NM...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_24nm&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_24nm.zip
else
    echo 'World 24 NM file exists. Skip download.'
fi
if [ ! -f /tmp/shapes/world_12nm.zip ]; then
    echo '--- Downloading World 12 NM...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_12nm&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_12nm.zip
else
    echo 'World 12 NM file exists. Skip download.'
fi

if [ ! -f /tmp/shapes/world_int_waters.zip ]; then
    echo '--- Downloading World Internal Waters...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_internal_waters&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_int_waters.zip
else
    echo 'World Internal Waters file exists. Skip download.'
fi

if [ ! -f /tmp/shapes/world_archi_waters.zip ]; then
    echo '--- Downloading World Archipelagic Waters...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=eez_archipelagic_waters&outputformat=SHAPE-ZIP" -O /tmp/shapes/world_archi_waters.zip
else
    echo 'World World Archipelagic Waters file exists. Skip download.'
fi

if [ ! -f /tmp/shapes/high_seas.zip ]; then
    echo '--- Downloading World High Seas v1...'
    wget -q "https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=high_seas&outputformat=SHAPE-ZIP" -O /tmp/shapes/high_seas.zip
else
    echo 'High Seas file exists. Skip download.'
fi

echo 'Downloading shapefiles from other places'
if [ ! -f /tmp/shapes/wpi.zip ]; then
    echo '--- Downloading World Port Index...'
    wget -q "https://msi.nga.mil/api/publications/download?key=16694622/SFH00000/WPI_Shapefile.zip&type=view" -O /tmp/shapes/wpi.zip
else
    echo 'WPI file exists. Skip download.'
fi

if [ ! -f /tmp/shapes/sampaz.zip ]; then
    echo '--- Downloading DEFF SAMPAZ MPA List...'
    wget -q "https://sfiler.environment.gov.za:8443/ssf/s/readFile/folderEntry/40950/8afbc1c77a484088017a5d45cb4202e6/1624344206000/last/SAMPAZ_OR_2021_Q1.zip" -O /tmp/shapes/sampaz.zip
else
    echo 'SAMPAZ file exists. Skip download.'
fi

if [ ! -f /tmp/shapes/country.zip ]; then
    echo '--- Downloading Admin Boundaries for Countries...'
    wget -q "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_countries.zip" -O /tmp/shapes/country.zip
else
    echo 'Admin Boundaries file exists. Skip download.'
fi

echo 'Downloads Complete' 

echo 'Loading shapefiles into GEO schema...' 
echo '--- Loading World EEZ v11'
echo '--- Loading World 24 NM'
echo '--- Loading World 12 NM'
echo '--- Loading World Internal Waters'
echo '--- Loading World Archipelagic Waters'
echo '--- Loading World High Seas v1' 
echo '--- Loading World Port Index'
echo '--- Loading DEFF SAMPAZ MPA List'
# shp2pgsql -I /tmp/World_EEZ_v10_20180221/eez_boundaries_v10.shp geo.world_eez | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
# shp2pgsql -I /tmp/WPI_Shapefile/WPI.shp geo.world_port_index | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}