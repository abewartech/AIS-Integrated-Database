#!/bin/bash

mkdir -p /tmp/shapes/
mkdir -p /tmp/unzips/
rm -rf /tmp/unzips/*


# fetch_geo title table zip shape url [referer]
fetch_geo () {
    local title="$1"
    local table="$2"
    local zip="$3"
    local shape="$4"
    local url="$5"
    local wget_referer=
    if [ -n "$6" ] ; then wget_referer="--referer $6" ; fi
    if [ ! -f "/tmp/shapes/${zip}" ]; then
        echo "--- Downloading ${title}..."
        wget -q $wget_referer "${url}" -O "/tmp/shapes/${zip}"
    else
        echo "${title} file exists. Skip download."
    fi
    echo "--- Loading ${title}"
    unzip "/tmp/shapes/${zip}" -d /tmp/unzips/
    shp2pgsql -W Latin1 -I "/tmp/unzips/${shape}" "geo.${table}" | psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
    rm -rf /tmp/unzips/*
}


#
# Marine Regions WFS
#
echo 'Downloading shapefiles from Marine Regions WFS...'


MARINE_REGIONS_SHAPE_ZIP='https://geo.vliz.be/geoserver/MarineRegions/wfs?service=WFS&version=1.0.0&request=GetFeature&outputformat=SHAPE-ZIP'


fetch_geo \
    'World 24 NM' \
    'world_eez' \
    'world_eez.zip' \
    'eez.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=eez"


fetch_geo \
    'World EEZ v11' \
    'eez_24nm' \
    'world_24nm.zip' \
    'eez_24nm.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=eez_24nm"

fetch_geo \
    'World 12 NM' \
    'eez_12nm' \
    'world_12nm.zip' \
    'eez_12nm.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=eez_12nm"

fetch_geo \
    'World Internal Waters' \
    'eez_internal_waters' \
    'world_int_waters.zip' \
    'eez_internal_waters.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=eez_internal_waters"

fetch_geo \
    'World Archipelagic Waters' \
    'eez_archipelagic_waters' \
    'world_archi_waters.zip' \
    'eez_archipelagic_waters.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=eez_archipelagic_waters"

fetch_geo \
    'World High Seas v1' \
    'oceans_world' \
    'high_seas.zip' \
    'high_seas.shp' \
    "${MARINE_REGIONS_SHAPE_ZIP}&typeName=high_seas"



#
# Other places
#
echo 'Downloading shapefiles from other places'


fetch_geo \
    'World Port Index' \
    'world_port_index' \
    'wpi.zip' \
    'WPI.shp' \
    'https://msi.nga.mil/api/publications/download?key=16694622/SFH00000/WPI_Shapefile.zip&type=view'

fetch_geo \
    'DEFF SAMPAZ MPA List' \
    'sampaz' \
    'sampaz.zip' \
    'SAMPAZ_OR_2021_Q1.shp' \
    'https://sfiler.environment.gov.za:8443/ssf/s/readFile/folderEntry/40950/8afbc1c77a484088017a5d45cb4202e6/1624344206000/last/SAMPAZ_OR_2021_Q1.zip'

fetch_geo \
    'Admin Boundaries for Countries' \
    'admin_0_countriesd_eez' \
    'country.zip' \
    'ne_50m_admin_0_countries.shp' \
    'https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/cultural/ne_50m_admin_0_countries.zip' \
    'https://www.naturalearthdata.com/'



#
# The end
#
echo '==============================================='
echo 'Downloads Complete and inserted into geo schema' 
echo '==============================================='
