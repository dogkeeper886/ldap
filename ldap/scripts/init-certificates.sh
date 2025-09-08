#!/bin/bash
# Script: init-certificates.sh
# Purpose: Initial Let's Encrypt certificate acquisition for LDAP server

set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Load environment variables
source .env

log "Starting certificate initialization for $LDAP_DOMAIN..."

# Stop any running services
if docker compose ps | grep -q "Up"; then
    log "Stopping running services..."
    docker compose down
fi

# Acquire certificate using certbot standalone
log "Acquiring Let's Encrypt certificate..."
docker run --rm \
    -p 80:80 \
    -v certificates:/etc/letsencrypt \
    certbot/certbot:v2.7.4 \
    certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$LETSENCRYPT_EMAIL" \
    --domains "$LDAP_DOMAIN" \
    --rsa-key-size 4096

log "Certificate acquisition completed"

# Copy certificates for OpenLDAP
log "Setting up certificates for OpenLDAP..."
docker run --rm \
    -v certificates:/etc/letsencrypt \
    --user root \
    alpine:latest \
    sh -c "
        mkdir -p /etc/letsencrypt/ldap-certs
        cp /etc/letsencrypt/live/$LDAP_DOMAIN/cert.pem /etc/letsencrypt/ldap-certs/
        cp /etc/letsencrypt/live/$LDAP_DOMAIN/privkey.pem /etc/letsencrypt/ldap-certs/
        cp /etc/letsencrypt/live/$LDAP_DOMAIN/fullchain.pem /etc/letsencrypt/ldap-certs/
        chmod 644 /etc/letsencrypt/ldap-certs/*
    "

log "Certificates ready for use"