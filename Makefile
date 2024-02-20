DOCKER_IMAGE=local-db

HOST=aisdb.vliz.be
PORT=5432
USER=vliz

.PHONY: build db init fetch

build:
	docker build . -t "${DOCKER_IMAGE}"

db: | ./data/pgdata ./data/result
	docker run -it --rm \
		-v ./data/pgdata:/home/postgres/pgdata/data \
		-v ./data/result:/home/postgres/result \
		--name "${DOCKER_IMAGE}" \
		-p 5432:5432 \
		"${DOCKER_IMAGE}"

#init:
#	mkdir -p ./data
#	chmod 777 ./data
#	mkdir -p ./data/pgdata
#	chmod 777 ./data/pgdata
#	mkdir -p ./data/result
#	chmod 777 ./data/result
#	docker run -it --rm \
#		-v ./docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
#		-v ./data/pgdata:/home/postgres/pgdata/data \
#		-v ./data/result:/home/postgres/result \
#		--name "${DOCKER_IMAGE}" \
#		-p 5432:5432 \
#		"${DOCKER_IMAGE}" \
#		--init \
#		--host=$(HOST) \
#		--port="$(PORT)" \
#		--user="$(USER)"

fetch_position: | ./data/pgdata
	docker exec -it \
		"${DOCKER_IMAGE}" \
		/home/postgres/container.sh \
		--fetch-position \
		--host=$(HOST) \
		--port="$(PORT)" \
		--user="$(USER)" \
		--start="$(START)" \
		--end="$(END)" \
		--lon="$(LON)" \
		--lat="$(LAT)" \
		--distance="$(DISTANCE)"

fetch_voyage: | ./data/pgdata
	docker exec -it \
		"${DOCKER_IMAGE}" \
		/home/postgres/container.sh \
		--fetch-voyage \
		--host=$(HOST) \
		--port="$(PORT)" \
		--user="$(USER)" \
		--start="$(START)" \
		--end="$(END)"

./data:
	mkdir -p ./data
	chmod 777 ./data

./data/pgdata: | ./data
	mkdir -p ./data/pgdata
	chmod 777 ./data/pgdata

./data/fetch: | ./data
	mkdir -p ./data/fetch
	chmod 777 ./data/fetch

./data/result: | ./data
	mkdir -p ./data/result
	chmod 777 ./data/result
