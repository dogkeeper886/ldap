# FreeRADIUS Server Makefile
# RADIUS server with automated TLS certificate management

# Load .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

.PHONY: help copy-certs copy-client-ca build-tls deploy stop restart clean logs test build setup-users \
       sql-auth sql-acct sql-by-mac sql-clear sql-detail debug debug-stop

# Default target
help:
	@echo "FreeRADIUS Server - Available Commands"
	@echo "====================================="
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make init          - Complete initial setup (certificates + deployment)"
	@echo "  make copy-certs    - Copy server certificates from external certbot"
	@echo "  make copy-client-ca - Copy client CA for EAP-TLS (requires CLIENT_CA_FILE)"
	@echo "  make build-tls     - Copy certificates and build FreeRADIUS with TLS"
	@echo "  make build         - Build FreeRADIUS Docker image"
	@echo "  make deploy        - Deploy/start FreeRADIUS service"
	@echo ""
	@echo "Operations:"
	@echo "  make stop          - Stop FreeRADIUS service"
	@echo "  make restart       - Restart FreeRADIUS service"
	@echo "  make logs          - Show FreeRADIUS logs"
	@echo "  make logs-follow   - Follow FreeRADIUS logs in real-time"
	@echo "  make debug         - Run FreeRADIUS in debug mode (-X)"
	@echo "  make debug-stop    - Stop debug mode and return to normal"
	@echo ""
	@echo "User Management:"
	@echo "  make setup-users   - Update user passwords (run after make init)"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Test RADIUS authentication"
	@echo "  make test-users    - Test all configured users"
	@echo "  make test-tls      - Test TLS/RadSec functionality"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean         - Clean containers and volumes"
	@echo "  make status        - Show service status"
	@echo "  make config-test   - Test FreeRADIUS configuration"
	@echo ""

# Environment setup
env:
	@if [ ! -f .env ]; then \
		echo "Creating .env from template..."; \
		cp .env.example .env; \
		echo "Please edit .env file with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi

# Copy server certificates from external certbot
copy-certs:
	@echo "Copying server certificates from external certbot..."
	@./scripts/copy-certs-for-build.sh

# Copy client CA for EAP-TLS client verification
copy-client-ca:
	@if [ -z "$(CLIENT_CA_FILE)" ]; then \
		echo "Usage: make copy-client-ca CLIENT_CA_FILE=/path/to/ca.pem"; \
		echo "Or set CLIENT_CA_FILE in .env file"; \
		exit 1; \
	fi
	@echo "Copying client CA from $(CLIENT_CA_FILE)..."
	@mkdir -p ./docker/freeradius/certs/ca
	@cp "$(CLIENT_CA_FILE)" ./docker/freeradius/certs/ca/client-ca.pem
	@chmod 644 ./docker/freeradius/certs/ca/client-ca.pem
	@echo "Client CA copied successfully"

# Build FreeRADIUS with TLS certificates
build-tls: copy-certs copy-client-ca build
	@echo "FreeRADIUS TLS image built successfully"

# Build FreeRADIUS Docker image
build:
	@echo "Building FreeRADIUS Docker image..."
	docker compose build

# Complete initial setup
init: env copy-certs copy-client-ca build deploy
	@echo "FreeRADIUS server initialization completed"
	@echo "Testing basic authentication..."
	@sleep 10
	@make test

# Deploy FreeRADIUS service
deploy:
	@echo "Starting FreeRADIUS service..."
	docker compose up -d
	@echo "FreeRADIUS service started. Checking status..."
	@sleep 5
	@make status

# Show service status
status:
	@echo "FreeRADIUS Service Status:"
	@echo "=========================="
	@if docker ps | grep -q freeradius-server; then \
		echo "✓ FreeRADIUS container is running"; \
		echo ""; \
		echo "Container Details:"; \
		docker ps --filter "name=freeradius-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
		echo ""; \
		echo "Health Check:"; \
		docker inspect freeradius-server --format '{{.State.Health.Status}}' 2>/dev/null || echo "No health check configured"; \
	else \
		echo "✗ FreeRADIUS container is not running"; \
		echo "Run 'make deploy' to start the service"; \
	fi

# Show service logs
logs:
	docker compose logs

# Follow service logs in real-time
logs-follow:
	docker compose logs -f

# Test RADIUS authentication
test:
	@echo "Testing RADIUS authentication..."
	@echo "Testing test user..."
	@if command -v radtest >/dev/null 2>&1; then \
		radtest test $${TEST_USER_PASSWORD:-testpass123} localhost 1812 $${RADIUS_SECRET:-testing123}; \
	else \
		docker exec freeradius-server /opt/bin/radtest test $${TEST_USER_PASSWORD:-testpass123} localhost 1812 $${RADIUS_SECRET:-testing123}; \
	fi

# Test all configured users
test-users:
	@echo "Testing all configured users..."
	@./scripts/test-all-users.sh

# Test TLS/RadSec functionality
test-tls:
	@echo "Testing TLS/RadSec functionality..."
	@echo "Checking TLS listener on port 2083..."
	@if docker exec freeradius-server netstat -ln | grep :2083; then \
		echo "✓ TLS listener is active on port 2083"; \
	else \
		echo "✗ TLS listener not found on port 2083"; \
	fi

# Test FreeRADIUS configuration
config-test:
	@echo "Testing FreeRADIUS configuration..."
	docker exec freeradius-server freeradius -C -d /etc/freeradius/3.0

# Stop FreeRADIUS service
stop:
	@echo "Stopping FreeRADIUS service..."
	docker compose down

# Restart FreeRADIUS service
restart:
	@echo "Restarting FreeRADIUS service..."
	docker compose restart

# Clean containers and volumes
clean:
	@echo "Cleaning up FreeRADIUS containers and volumes..."
	docker compose down -v
	docker system prune -f

# Update user passwords from .env file
setup-users:
	@echo "Setting up user passwords..."
	@./scripts/setup-users.sh

# Show environment configuration
show-config:
	@echo "Current Configuration:"
	@echo "====================="
	@if [ -f .env ]; then \
		grep -v '^#' .env | grep -v '^$$'; \
	else \
		echo "No .env file found. Run 'make env' to create one."; \
	fi

# SQL Logging Queries
sql-auth:
	@echo "Recent Authentication Attempts (last 20):"
	@echo "=========================================="
	@docker exec radius-postgres psql -U radius -d radius -c \
		"SELECT authdate, username, reply, nasidentifier, callingstationid FROM radpostauth ORDER BY authdate DESC LIMIT 20;"

sql-acct:
	@echo "Recent Accounting Sessions (last 20):"
	@echo "======================================"
	@docker exec radius-postgres psql -U radius -d radius -c \
		"SELECT acctstarttime, username, nasidentifier, callingstationid, acctstoptime, acctterminatecause FROM radacct ORDER BY acctstarttime DESC LIMIT 20;"

sql-by-mac:
	@if [ -z "$(MAC)" ]; then \
		echo "Usage: make sql-by-mac MAC=C6-AD-50-7C-41-04"; \
		exit 1; \
	fi
	@echo "Auth and Accounting for MAC: $(MAC)"
	@echo "===================================="
	@echo ""
	@echo "Authentication:"
	@docker exec radius-postgres psql -U radius -d radius -c \
		"SELECT authdate, username, reply, nasidentifier FROM radpostauth WHERE callingstationid ILIKE '%$(MAC)%' ORDER BY authdate DESC LIMIT 10;"
	@echo ""
	@echo "Accounting:"
	@docker exec radius-postgres psql -U radius -d radius -c \
		"SELECT acctstarttime, username, nasidentifier, acctstoptime, acctterminatecause FROM radacct WHERE callingstationid ILIKE '%$(MAC)%' ORDER BY acctstarttime DESC LIMIT 10;"

sql-clear:
	@echo "Clearing auth and accounting tables..."
	@docker exec radius-postgres psql -U radius -d radius -c "TRUNCATE radpostauth, radacct RESTART IDENTITY;"
	@echo "Tables cleared."

sql-detail:
	@if [ -z "$(MAC)" ]; then \
		echo "Usage: make sql-detail MAC=B6-64-89-61-87-E5"; \
		exit 1; \
	fi
	@echo ""
	@echo "=== Latest Auth Record for $(MAC) ==="
	@docker exec radius-postgres psql -U radius -d radius -t -c "\x" -c \
		"SELECT * FROM radpostauth WHERE callingstationid ILIKE '%$(MAC)%' ORDER BY authdate DESC LIMIT 1;"
	@echo ""
	@echo "=== Latest Accounting Record for $(MAC) ==="
	@docker exec radius-postgres psql -U radius -d radius -t -c "\x" -c \
		"SELECT * FROM radacct WHERE callingstationid ILIKE '%$(MAC)%' ORDER BY acctstarttime DESC LIMIT 1;"

# Debug mode - run FreeRADIUS with -X flag for verbose output
debug:
	@echo "Starting FreeRADIUS in debug mode..."
	@docker compose stop freeradius
	DEBUG_MODE=true docker compose up -d freeradius
	@sleep 5
	@echo "FreeRADIUS running in debug mode."
	@echo "Use 'make logs-follow' to view debug output."
	@echo "Use 'make debug-stop' to return to normal mode."

# Stop debug mode and return to normal
debug-stop:
	@echo "Stopping debug mode and restarting normal service..."
	@docker compose stop freeradius
	DEBUG_MODE=false docker compose up -d freeradius
	@sleep 5
	@make status
