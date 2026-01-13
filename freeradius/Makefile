# FreeRADIUS Server Makefile
# RADIUS server with automated TLS certificate management

.PHONY: help copy-certs build-tls deploy stop restart clean logs test build setup-users

# Default target
help:
	@echo "FreeRADIUS Server - Available Commands"
	@echo "====================================="
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make init          - Complete initial setup (certificates + deployment)"
	@echo "  make copy-certs    - Copy certificates from external certbot"
	@echo "  make build-tls     - Copy certificates and build FreeRADIUS with TLS"
	@echo "  make build         - Build FreeRADIUS Docker image"
	@echo "  make deploy        - Deploy/start FreeRADIUS service"
	@echo ""
	@echo "Operations:"
	@echo "  make stop          - Stop FreeRADIUS service"
	@echo "  make restart       - Restart FreeRADIUS service"
	@echo "  make logs          - Show FreeRADIUS logs"
	@echo "  make logs-follow   - Follow FreeRADIUS logs in real-time"
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

# Copy certificates from external certbot
copy-certs:
	@echo "Copying certificates from external certbot..."
	@./scripts/copy-certs-for-build.sh

# Build FreeRADIUS with TLS certificates
build-tls: copy-certs build
	@echo "FreeRADIUS TLS image built successfully"

# Build FreeRADIUS Docker image
build:
	@echo "Building FreeRADIUS Docker image..."
	docker compose build

# Complete initial setup
init: env copy-certs build deploy
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
