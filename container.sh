#!/usr/bin/bash

LOCAL_POSTGRES_USER=vliz
LOCAL_POSTGRES_PASSWORD=vliz
LOCAL_POSTGRES_DB=vessels

POSTGRES_USER="${LOCAL_POSTGRES_USER}"
POSTGRES_PASSWORD="${LOCAL_POSTGRES_PASSWORD}"
POSTGRES_DB="${LOCAL_POSTGRES_DB}"

set -euo pipefail

# Modes: init, fetch_position, fetch_voyage, idle
MODE=idle

HOST=
PORT=
USER=

START=
END=
LON=
LAT=
DISTANCE=


for arg in "$@"
do
    case $arg in
        --init)
            MODE=init
            ;;
        --fetch-position)
            MODE=fetch_position
            ;;
        --fetch-voyage)
            MODE=fetch_voyage
            ;;
        --host=*)
            HOST="${arg#"--host="}"
            ;;
        --port=*)
            PORT="${arg#"--port="}"
            ;;
        --user=*)
            USER="${arg#"--user="}"
            ;;
        --start=*)
            START="${arg#"--start="}"
            ;;
        --end=*)
            END="${arg#"--end="}"
            ;;
        --lon=*)
            LON="${arg#"--lon="}"
            ;;
        --lat=*)
            LAT="${arg#"--lat="}"
            ;;
        --distance=*)
            DISTANCE="${arg#"--distance="}"
            ;;
        *)
            echo "ERROR Invalid argument '${arg}'" 2>&1
            exit 1
            ;;
    esac
done


# Initialization:
#   Connect to the original Open AIS database and fetch the schema.
init() {
    if [[ "${HOST}" && "${PORT}" && "${USER}" ]]
    then
        echo 'Initializing...'
        echo '(doing nothing)'
        # pg_dump \
        #     --host="${HOST}" \
        #     --port="${PORT}" \
        #     --user="${USER}" \
        #     --schema-only \
        #     --schema=ais \
        #     vessels \
        #     > /docker-entrypoint-initdb.d/200_ais.sql
        echo 'Initialization done.'
    else
        echo 'Not initializing the database, which requires:'
        echo '  --host=HOST'
        echo '  --port=PORT'
        echo '  --user=USER'
    fi
}


# Run PostgreSQL
run() {
    export POSTGRES_USER
    export POSTGRES_PASSWORD
    export POSTGRES_DB

    /docker-entrypoint.sh postgres -c 'config_file=/home/postgres/postgresql.conf'
}


# Fetch data
fetch_position() {
    if [[ "${HOST}" && "${PORT}" && "${USER}" && "${START}" && "${END}" && "${LON}" && "${LAT}" && "${DISTANCE}" ]]
    then
        echo 'Fetching data...'
        filename="${HOME}/result/pos_reports-${START}_${END}_${LON}_${LAT}_${DISTANCE}.csv"
        echo "   File: ${filename}"
        echo "    Fetching..."
        psql \
            --dbname="postgresql://${USER}${SRC_PASS:+:${SRC_PASS}}@${HOST}:${PORT}/${POSTGRES_DB}" \
            -c "\\COPY ( SELECT * FROM ais.pos_reports WHERE event_time BETWEEN DATE '${START}' AND DATE '${END}' AND longitude BETWEEN ${LON}-${DISTANCE} AND ${LON}+${DISTANCE} AND latitude BETWEEN ${LAT}-${DISTANCE} AND ${LAT}+${DISTANCE} ORDER BY event_time ) TO '${filename}' WITH(FORMAT csv,HEADER true);"
        echo "    Inserting..."
        POSTGRES_PASSWORD="${LOCAL_POSTGRES_PASSWORD}" psql \
            --dbname="${POSTGRES_DB}" \
            -U "${POSTGRES_USER}" \
            -c "\\COPY ais.pos_reports FROM '${filename}' DELIMITER ',' CSV HEADER;"
        echo 'Done.'
    else
        echo 'Not fetching data, which requires:'
        echo '  --host=HOST'
        echo '  --port=PORT'
        echo '  --user=USER'
        echo '  --start=YYYY-MM-DD'
        echo '  --end=YYYY-MM-DD'
        echo '  --lon=LONGITUDE'
        echo '  --lat=LATITUDE'
        echo '  --distance=DEGREES'
    fi
}

# Fetch voyage data
fetch_voyage() {
    if [[ "${HOST}" && "${PORT}" && "${USER}" && "${START}" && "${END}" ]]
    then
        echo 'Fetching data...'
        filename="${HOME}/result/voy_reports-${START}_${END}.csv"
        echo "   File: ${filename}"
        echo "    Fetching..."
        psql \
            --dbname="postgresql://${USER}${SRC_PASS:+:${SRC_PASS}}@${HOST}:${PORT}/${POSTGRES_DB}" \
            -c "\\COPY ( SELECT * FROM ais.voy_reports WHERE event_time BETWEEN DATE '${START}' AND DATE '${END}' ORDER BY event_time ) TO '${filename}' WITH(FORMAT csv,HEADER true);"
        du -hs "${filename}"
        gzip "${filename}"
        du -hs "${filename}.gz"
        echo "    Inserting..."
        zcat "${filename}.gz" | timescaledb-parallel-copy \
            --connection "host=localhost user=${LOCAL_POSTGRES_USER} sslmode=disable" \
            --db-name "vessels" \
            --schema "ais" \
            --table "voy_reports" \
            --workers 12 \
            --reporting-period 30s \
            --skip-header
        # echo "    Inserting..."
        # POSTGRES_PASSWORD="${LOCAL_POSTGRES_PASSWORD}" psql \
        #     --dbname="${POSTGRES_DB}" \
        #     -U "${POSTGRES_USER}" \
        #     -c "\\COPY ais.voy_reports FROM '${filename}' DELIMITER ',' CSV HEADER;"
        echo 'Done.'
    else
        echo 'Not fetching data, which requires:'
        echo '  --host=HOST'
        echo '  --port=PORT'
        echo '  --user=USER'
        echo '  --start=YYYY-MM-DD'
        echo '  --end=YYYY-MM-DD'
    fi
}

case "${MODE}" in
    init)
        init
        run
        ;;
    fetch_position)
        fetch_position
        ;;
    fetch_voyage)
        fetch_voyage
        ;;
    idle)
        run
        ;;
esac

