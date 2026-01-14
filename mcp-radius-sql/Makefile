.PHONY: copy-certs build deploy stop logs status

copy-certs:
	@./scripts/copy-certs-for-build.sh

build: copy-certs
	docker compose -f ../freeradius/docker-compose.yml build mcp-radius-sql

deploy: build
	docker compose -f ../freeradius/docker-compose.yml up -d mcp-radius-sql

stop:
	docker compose -f ../freeradius/docker-compose.yml stop mcp-radius-sql

logs:
	docker compose -f ../freeradius/docker-compose.yml logs -f mcp-radius-sql

status:
	docker compose -f ../freeradius/docker-compose.yml ps mcp-radius-sql
