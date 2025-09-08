# Makefile for LDAP WiFi Authentication Server
# This file provides convenient targets for common operations

.PHONY: help init deploy stop restart clean backup restore test health logs setup-users init-certs copy-certs build-tls

# Default target
help:
	@echo "LDAP WiFi Authentication Server - Available Commands"
	@echo "=================================================="
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make init          - Complete initial setup (certificates + deployment + users)"
	@echo "  make init-certs    - Initialize certificates (requires external certbot)"
	@echo "  make build         - Build custom Docker images"
	@echo "  make copy-certs    - Copy certificates from external certbot for OpenLDAP build"
	@echo "  make build-tls     - Copy certificates and build OpenLDAP with TLS"
	@echo "  make deploy        - Deploy/start all services"
	@echo "  make setup-users   - Set up test users in LDAP"
	@echo "  make add-msad-attributes - Add MS AD attributes for WiFi AP compatibility"
	@echo "  make setup-users-msad    - Setup users with MS AD attributes (combined)"
	@echo ""
	@echo "Operations:"
	@echo "  make stop          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo "  make health        - Run health checks"
	@echo "  make logs          - Show service logs"
	@echo "  make logs-follow   - Follow service logs in real-time"
	@echo ""
	@echo "Backup & Restore:"
	@echo "  make backup        - Create full backup"
	@echo "  make restore FILE= - Restore from backup file"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests"
	@echo "  make test-auth     - Test authentication only"
	@echo "  make test-tls      - Test TLS configuration"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean         - Clean up containers and volumes"
	@echo "  make clean-all     - Clean everything including images"
	@echo "  make rebuild       - Rebuild images and redeploy"
	@echo "  make update        - Update container images"
	@echo ""
	@echo "Environment Setup:"
	@echo "  make env           - Create .env from template"
	@echo "  make check-env     - Validate environment configuration"
	@echo ""

# Environment setup
env:
	@if [ ! -f .env ]; then \
		echo "Creating .env file from template..."; \
		cp .env.example .env; \
		echo "Please edit .env file with your configuration before proceeding"; \
	else \
		echo ".env file already exists"; \
	fi

check-env:
	@echo "Checking environment configuration..."
	@if [ ! -f .env ]; then \
		echo "ERROR: .env file not found. Run 'make env' first"; \
		exit 1; \
	fi
	@echo "✓ .env file exists"
	@grep -q "LDAP_DOMAIN=" .env || (echo "ERROR: LDAP_DOMAIN not set in .env"; exit 1)
	@grep -q "LETSENCRYPT_EMAIL=" .env || (echo "ERROR: LETSENCRYPT_EMAIL not set in .env"; exit 1)
	@echo "✓ Required environment variables are set"

# Complete initial setup (certificates + services only)
init: check-env build init-certs deploy
	@echo ""
	@echo "🎉 Initial setup completed successfully!"
	@echo ""
	@echo "Your LDAP server is now ready."
	@echo "Run 'make setup-users' to add test data."

# Initialize certificates
init-certs: check-env
	@echo "Initializing certificates from external certbot..."
	@echo "NOTE: This requires the external certbot service to be running."
	@echo "Start it with: cd ../certbot && make deploy"
	@./scripts/copy-certs-for-build.sh

# Copy certificates from certbot for OpenLDAP build
copy-certs: check-env
	@echo "Copying certificates from certbot..."
	@./scripts/copy-certs-for-build.sh
	@echo "Certificates copied successfully"

# Build OpenLDAP with TLS certificates
build-tls: check-env copy-certs
	@echo "Building OpenLDAP with TLS certificates..."
	@docker compose build openldap
	@echo "OpenLDAP TLS image built successfully"

# Build custom Docker images
build: check-env
	@echo "Building custom Docker images..."
	@docker compose build
	@echo "Docker images built successfully"

# Deploy services
deploy: check-env build
	@echo "Deploying LDAP services..."
	@docker compose up -d
	@echo "Waiting for services to start..."
	@sleep 10
	@echo "Services deployed successfully"

# Setup test users
setup-users:
	@echo "Setting up test users..."
	@./scripts/setup-users.sh

# Add MS AD compatibility attributes for WiFi AP authentication
add-msad-attributes:
	@echo "Adding Microsoft AD compatibility attributes..."
	@./scripts/add-msad-attributes.sh

# Setup users with MS AD attributes (combined operation)
setup-users-msad: setup-users add-msad-attributes
	@echo "Users configured with MS AD attributes for WiFi AP compatibility"


# Stop services
stop:
	@echo "Stopping LDAP services..."
	@docker compose down

# Restart services
restart: stop deploy
	@echo "Services restarted successfully"

# Health check
health:
	@echo "Running health checks..."
	@./scripts/health-check.sh

# Health check with verbose output
health-verbose:
	@echo "Running verbose health checks..."
	@./scripts/health-check.sh --verbose

# Show logs
logs:
	@echo "Showing service logs..."
	@docker compose logs --tail=50

# Follow logs in real-time
logs-follow:
	@echo "Following service logs (Ctrl+C to stop)..."
	@docker compose logs -f

# Show OpenLDAP logs only
logs-ldap:
	@echo "Showing OpenLDAP logs..."
	@docker compose logs openldap --tail=50

# Show Certbot logs only
logs-certbot:
	@echo "Showing Certbot logs..."
	@docker compose logs certbot --tail=50

# Create backup
backup:
	@echo "Creating backup..."
	@./scripts/backup-ldap.sh

# Restore from backup
restore:
	@if [ -z "$(FILE)" ]; then \
		echo "ERROR: Please specify backup file with FILE=path/to/backup.tar.gz"; \
		echo "Available backups:"; \
		ls -la volumes/backups/*.tar.gz 2>/dev/null || echo "No backups found"; \
		exit 1; \
	fi
	@echo "Restoring from backup: $(FILE)"
	@./scripts/restore-ldap.sh "$(FILE)"

# Run all tests
test: test-auth test-tls test-attributes
	@echo "All tests completed"

# Test authentication
test-auth:
	@echo "Testing user authentication..."
	@./tests/test-authentication.sh

# Test TLS configuration
test-tls:
	@echo "Testing TLS configuration..."
	@./tests/test-tls.sh

# Test RUCKUS attributes
test-attributes:
	@echo "Testing RUCKUS One attribute retrieval..."
	@./tests/test-attributes.sh

# Performance test
test-performance:
	@echo "Running performance tests..."
	@./tests/load-test.sh

# Clean up containers and volumes
clean:
	@echo "Cleaning up containers and volumes..."
	@docker compose down -v
	@docker system prune -f

# Clean everything including images
clean-all: clean
	@echo "Removing Docker images..."
	@docker compose down --rmi all -v
	@docker system prune -af

# Rebuild images and redeploy
rebuild: stop
	@echo "Rebuilding Docker images..."
	@docker compose build --no-cache
	@echo "Redeploying services..."
	@docker compose up -d
	@echo "Rebuild and redeploy completed"

# Update container images
update:
	@echo "Updating base images and rebuilding..."
	@docker compose build --pull
	@docker compose up -d

# Show container status
status:
	@echo "Container Status:"
	@docker compose ps
	@echo ""
	@echo "Resource Usage:"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Manual certificate renewal
renew-certs:
	@echo "Manually renewing certificates..."
	@docker compose exec certbot certbot renew --force-renewal
	@docker compose restart openldap

# Force certificate renewal (for testing)
force-renew-certs:
	@echo "Force renewing certificates..."
	@docker compose exec certbot certbot renew --force-renewal
	@docker compose restart openldap

# Shell access to OpenLDAP container
shell-ldap:
	@echo "Opening shell in OpenLDAP container..."
	@docker compose exec openldap /bin/bash

# Shell access to Certbot container
shell-certbot:
	@echo "Opening shell in Certbot container..."
	@docker compose exec certbot /bin/sh

# View LDAP database contents
view-ldap:
	@echo "Viewing LDAP database contents..."
	@DOMAIN_DN=$$(grep LDAP_DOMAIN .env | cut -d= -f2 | sed 's/\./,dc=/g' | sed 's/^/dc=/') && docker compose exec openldap ldapsearch -x -H ldap://localhost -D "cn=admin,$$DOMAIN_DN" -w "$$(grep LDAP_ADMIN_PASSWORD .env | cut -d= -f2)" -b "$$DOMAIN_DN"

# Create test environment
dev-setup: env
	@echo "Setting up development environment..."
	@sed -i 's/ENVIRONMENT=production/ENVIRONMENT=development/' .env
	@sed -i 's/example.com/ldap.local/' .env
	@echo "Development environment configured"
	@echo "Note: Update /etc/hosts to point ldap.local to 127.0.0.1 for local testing"

# Production deployment check
prod-check: check-env
	@echo "Running production readiness check..."
	@grep -q "ENVIRONMENT=production" .env || (echo "WARNING: ENVIRONMENT not set to production"; exit 1)
	@grep -q "example.com" .env && (echo "ERROR: Still using example.com domain"; exit 1) || true
	@./scripts/health-check.sh
	@echo "✓ Production readiness check passed"

# Disaster recovery
disaster-recovery:
	@echo "Starting disaster recovery process..."
	@echo "This will restore the most recent backup"
	@LATEST_BACKUP=$$(ls -t volumes/backups/backup-*.tar.gz 2>/dev/null | head -1); \
	if [ -n "$$LATEST_BACKUP" ]; then \
		echo "Restoring from: $$LATEST_BACKUP"; \
		$(MAKE) restore FILE="$$LATEST_BACKUP"; \
	else \
		echo "ERROR: No backups found for disaster recovery"; \
		exit 1; \
	fi

# Show help for specific command
help-%:
	@case $* in \
		init) echo "make init - Complete initial setup including certificates, deployment, and user setup" ;; \
		deploy) echo "make deploy - Start all Docker containers and services" ;; \
		test) echo "make test - Run authentication, TLS, and attribute tests" ;; \
		backup) echo "make backup - Create a full backup of LDAP data, certificates, and configuration" ;; \
		*) echo "Help not available for: $*" ;; \
	esac