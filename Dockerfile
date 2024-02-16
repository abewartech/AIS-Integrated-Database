# Dockerfile for production instance
FROM timescale/timescaledb-ha:pg16.1-ts2.13.1
USER root
RUN  apt-get update \
  && apt-get install -y wget postgis unzip \
  && rm -rf /var/lib/apt/lists/*
USER postgres
# Select which scripts to run on first DB startup:
COPY ./build/db_init_scripts /docker-entrypoint-initdb.d/
COPY ./build/db_init_scripts_extra /docker-entrypoint-initdb.d/
COPY ./build/db_init_data /tmp/db_init_data/
RUN mkdir /tmp/unzips 