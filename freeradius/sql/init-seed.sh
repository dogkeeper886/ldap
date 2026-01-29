#!/bin/bash
# Seed default users with passwords from environment variables

set -e

# Substitute environment variables in seed template
sed -e "s/{{TEST_USER_PASSWORD}}/${TEST_USER_PASSWORD:-testpass123}/g" \
    -e "s/{{GUEST_USER_PASSWORD}}/${GUEST_USER_PASSWORD:-guestpass123}/g" \
    /docker-entrypoint-initdb.d/seed.sql.template > /tmp/seed.sql

# Run the seed SQL
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < /tmp/seed.sql

echo "Seed data applied successfully"
