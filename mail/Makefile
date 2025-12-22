.PHONY: help env deploy stop logs clean copy-certs add-user del-user update-password list-users read-guest-mail clean-mail

help:
	@echo "Mail Server (Receive Only)"
	@echo "=========================="
	@echo ""
	@echo "  make deploy        - Start mail server"
	@echo "  make stop          - Stop mail server"
	@echo "  make logs          - Show logs"
	@echo "  make clean         - Clean containers and volumes"
	@echo ""
	@echo "User Management:"
	@echo "  make add-user         - Add a mail user (interactive)"
	@echo "  make del-user         - Delete a mail user (interactive)"
	@echo "  make update-password  - Update user password (interactive)"
	@echo "  make list-users       - List mail users"
	@echo ""
	@echo "Certificate Management:"
	@echo "  make copy-certs    - Copy certificates from certbot"
	@echo ""
	@echo "Guest Mail:"
	@echo "  make read-guest-mail  - Read guest credential emails"
	@echo "  make clean-mail       - Delete all mail"
	@echo ""

env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env - edit with your configuration"; \
	fi

copy-certs:
	@echo "Copying certificates from certbot..."
	@./scripts/copy-certs.sh

deploy: env copy-certs
	@echo "Starting mail server..."
	@docker compose up -d

stop:
	@docker compose down

logs:
	@docker compose logs -f

clean:
	@docker compose down -v

add-user:
	@docker exec -it mailserver setup email add

list-users:
	@docker exec mailserver setup email list

del-user:
	@docker exec -it mailserver setup email del

update-password:
	@docker exec -it mailserver setup email update

read-guest-mail:
	@docker cp scripts/read-guest-mail.sh mailserver:/tmp/read-guest-mail.sh
	@. ./.env && docker exec -e MAIL_DOMAIN=$$MAIL_DOMAIN -e MAIL_USER=$$MAIL_USER mailserver bash /tmp/read-guest-mail.sh

clean-mail:
	@. ./.env && docker exec mailserver sh -c "rm -f /var/mail/$$MAIL_DOMAIN/$$MAIL_USER/new/* /var/mail/$$MAIL_DOMAIN/$$MAIL_USER/cur/*"
