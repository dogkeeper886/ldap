# Keycloak SAML IdP Makefile
# SAML 2.0 Identity Provider with LDAP Federation

.PHONY: help env copy-certs deploy stop restart clean logs logs-follow test test-ldap setup-realm status init

# Default target
help:
	@echo "Keycloak SAML IdP - Available Commands"
	@echo "======================================"
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make env           - Create .env from template"
	@echo "  make init          - Complete initial setup (certs + deploy)"
	@echo "  make copy-certs    - Copy certificates from external certbot"
	@echo "  make deploy        - Start Keycloak service"
	@echo ""
	@echo "Configuration:"
	@echo "  make setup-realm   - Configure SAML realm with LDAP federation"
	@echo ""
	@echo "Operations:"
	@echo "  make stop          - Stop Keycloak service"
	@echo "  make restart       - Restart Keycloak service"
	@echo "  make logs          - Show Keycloak logs"
	@echo "  make logs-follow   - Follow Keycloak logs in real-time"
	@echo "  make status        - Show service status"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Test Keycloak connectivity"
	@echo "  make test-ldap     - Test LDAP federation"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean         - Clean containers and volumes"
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

# Complete initial setup
init: env copy-certs deploy
	@echo "Keycloak server initialization completed"
	@echo "Waiting for Keycloak to start..."
	@sleep 30
	@make test

# Deploy Keycloak service
deploy:
	@echo "Starting Keycloak service..."
	docker compose up -d
	@echo "Keycloak service started. Checking status..."
	@sleep 5
	@make status

# Show service status
status:
	@echo "Keycloak Service Status:"
	@echo "========================"
	@if docker ps | grep -q keycloak; then \
		echo "Keycloak container is running"; \
		echo ""; \
		echo "Container Details:"; \
		docker ps --filter "name=keycloak" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
	else \
		echo "Keycloak container is not running"; \
		echo "Run 'make deploy' to start the service"; \
	fi

# Show service logs
logs:
	docker compose logs

# Follow service logs in real-time
logs-follow:
	docker compose logs -f

# Test Keycloak connectivity
test:
	@echo "Testing Keycloak connectivity..."
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/health/ready || echo "Keycloak may still be starting..."

# Test LDAP federation
test-ldap:
	@echo "Testing LDAP connectivity from Keycloak..."
	@docker exec keycloak bash -c 'curl -s ldap://$${LDAP_HOST}:389 2>&1 || echo "LDAP connection test (port 389)"'
	@docker exec keycloak bash -c 'echo | openssl s_client -connect $${LDAP_HOST}:636 2>/dev/null | head -5 || echo "LDAPS connection test (port 636)"'

# Configure SAML realm with LDAP federation
setup-realm:
	@echo "Configuring SAML realm with LDAP federation..."
	@./scripts/setup-realm.sh

# Stop Keycloak service
stop:
	@echo "Stopping Keycloak service..."
	docker compose down

# Restart Keycloak service
restart:
	@echo "Restarting Keycloak service..."
	docker compose restart

# Clean containers and volumes
clean:
	@echo "Cleaning up Keycloak containers and volumes..."
	docker compose down -v
	docker system prune -f
