.PHONY: help deploy stop logs clean

help:
	@echo "Simple Certbot - Let's Encrypt Certificate Management"
	@echo "===================================================="
	@echo ""
	@echo "  make deploy          - Start certbot service"
	@echo "  make stop            - Stop certbot service"
	@echo "  make logs            - Show certbot logs"
	@echo "  make clean           - Clean containers and volumes"
	@echo ""

env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env - edit with your domains and email"; \
	fi

deploy: env
	docker compose up -d

stop:
	docker compose down

logs:
	docker compose logs -f

clean:
	docker compose down -v