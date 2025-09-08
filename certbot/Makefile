# Standalone Certbot Makefile
# Multi-domain certificate management for LDAP + FreeRADIUS projects

.PHONY: help init-certs copy-certs-to-all deploy stop restart clean logs build test

# Default target
help:
	@echo "Standalone Certbot - Multi-Domain Certificate Management"
	@echo "======================================================="
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make init-certs      - Initialize multi-domain certificates"
	@echo "  make deploy          - Start certbot service"
	@echo "  make build           - Build certbot Docker image"
	@echo ""
	@echo "Certificate Distribution:"
	@echo "  make copy-certs-to-all    - Copy certificates to all projects"
	@echo "  make copy-certs-to-ldap   - Copy certificates to LDAP project"
	@echo "  make copy-certs-to-radius - Copy certificates to FreeRADIUS project"
	@echo ""
	@echo "Operations:"
	@echo "  make stop            - Stop certbot service"
	@echo "  make restart         - Restart certbot service"
	@echo "  make logs            - Show certbot logs"
	@echo "  make renew           - Force certificate renewal"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean           - Clean containers and volumes"
	@echo "  make test            - Test certificate validity"
	@echo "  make status          - Show certificate status"
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

# Build custom certbot image
build:
	@echo "Building standalone certbot image..."
	docker compose build

# Initialize certificates
init-certs: env
	@echo "Initializing multi-domain certificates..."
	docker compose run --rm certbot acquire

# Deploy certbot service
deploy: build
	@echo "Starting standalone certbot service..."
	docker compose up -d
	@echo "Certbot service started. Checking status..."
	sleep 5
	@make status

# Copy certificates to all projects
copy-certs-to-all:
	@echo "Copying certificates to all projects..."
	@./scripts/copy-certs-to-all.sh

# Copy certificates to LDAP project
copy-certs-to-ldap:
	@echo "Copying certificates to LDAP project..."
	@./scripts/copy-certs-to-ldap.sh

# Copy certificates to FreeRADIUS project
copy-certs-to-radius:
	@echo "Copying certificates to FreeRADIUS project..."
	@./scripts/copy-certs-to-radius.sh

# Show service logs
logs:
	docker compose logs -f

# Show container status
status:
	@echo "Checking container status..."
	@if docker ps | grep -q standalone-certbot; then \
		echo "✓ Certbot container is running"; \
	else \
		echo "✗ Certbot container is not running"; \
		echo "Run 'make deploy' to start the service"; \
	fi

# Force certificate renewal
renew:
	@echo "Forcing certificate renewal..."
	docker compose exec certbot renew

# Stop certbot service
stop:
	@echo "Stopping certbot service..."
	docker compose down

# Restart certbot service
restart:
	@echo "Restarting certbot service..."
	docker compose restart

# Test certificate validity
test:
	@echo "Testing certificate validity..."
	@./scripts/test-certificates.sh

# Clean up containers and volumes
clean:
	@echo "Cleaning up certbot containers and volumes..."
	docker compose down -v
	docker system prune -f

# Show environment configuration
show-config:
	@echo "Current Configuration:"
	@echo "====================="
	@if [ -f .env ]; then \
		grep -v '^#' .env | grep -v '^$$'; \
	else \
		echo "No .env file found. Run 'make env' to create one."; \
	fi