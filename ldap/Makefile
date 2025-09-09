# LDAP WiFi Authentication Server - Simple Makefile

.PHONY: help env deploy stop logs clean init copy-certs build-tls backup

help:
	@echo "LDAP WiFi Authentication Server"
	@echo "==============================="
	@echo ""
	@echo "  make env           - Create .env from template"
	@echo "  make init          - Complete setup (certs + deploy)"
	@echo "  make deploy        - Start LDAP service"
	@echo "  make stop          - Stop LDAP service"
	@echo "  make logs          - Show logs"
	@echo "  make clean         - Clean containers and volumes"
	@echo ""
	@echo "Certificate Management:"
	@echo "  make copy-certs    - Copy certificates from external certbot"
	@echo "  make build-tls     - Build OpenLDAP with TLS certificates"
	@echo ""
	@echo "Maintenance:"
	@echo "  make backup        - Export LDAP data"
	@echo ""

env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env - edit with your configuration"; \
	fi

copy-certs:
	@echo "Copying certificates from external certbot..."
	@./scripts/copy-certs-for-build.sh

build-tls: copy-certs
	@echo "Building OpenLDAP with TLS..."
	@docker compose build openldap

deploy: build-tls
	@echo "Starting LDAP service..."
	@docker compose up -d

init: env deploy
	@echo "LDAP server ready!"

stop:
	@docker compose down

logs:
	@docker compose logs -f

clean:
	@docker compose down -v
	@docker system prune -f

backup:
	@echo "Creating LDAP backup..."
	@./scripts/backup-ldap.sh
