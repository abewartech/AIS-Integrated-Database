FROM timescale/timescaledb-ha:pg16.1-ts2.13.1
USER root
RUN  apt-get update \
  && apt-get install -y wget postgis unzip \
  && rm -rf /var/lib/apt/lists/*
USER postgres
# Select which scripts to run on first DB startup:
# COPY ./build/db/db_init_scripts/ais /docker-entrypoint-initdb.d/
COPY ./build/db/db_init_scripts/geo /docker-entrypoint-initdb.d/
COPY ./build/db/db_init_data /tmp/
RUN mkdir /tmp/unzips
# RUN chmod +777 /tmp/unzips
