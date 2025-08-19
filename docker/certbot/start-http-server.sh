#!/bin/bash
# HTTP File Server for Certificate Sharing
# Purpose: Serve certificate files to other containers via HTTP

set -euo pipefail

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[HttpServer][$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] HTTP-SERVER: $1" >> /opt/certbot-logs/certbot.log
}

error() {
    echo -e "${RED}[HttpServer][$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] HTTP-SERVER ERROR: $1" >> /opt/certbot-logs/certbot.log
}

warn() {
    echo -e "${YELLOW}[HttpServer][$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] HTTP-SERVER WARNING: $1" >> /opt/certbot-logs/certbot.log
}

# Configuration
HTTP_PORT=${HTTP_PORT:-8080}
CERT_DIR="/etc/letsencrypt/ldap-certs"
SERVER_ROOT="/tmp/http-server"

# Setup HTTP server directory structure
setup_server_directory() {
    log "Setting up HTTP server directory structure..."
    
    # Create server root directory
    mkdir -p "$SERVER_ROOT"
    
    # Create symbolic links to certificate files
    if [ -d "$CERT_DIR" ]; then
        log "Creating symlinks to certificate files..."
        
        # Remove old symlinks if they exist
        rm -f "$SERVER_ROOT"/*.pem 2>/dev/null || true
        
        # Create new symlinks if certificates exist
        if [ -f "$CERT_DIR/cert.pem" ]; then
            ln -sf "$CERT_DIR/cert.pem" "$SERVER_ROOT/cert.pem"
            log "Symlink created: cert.pem"
        fi
        
        if [ -f "$CERT_DIR/privkey.pem" ]; then
            ln -sf "$CERT_DIR/privkey.pem" "$SERVER_ROOT/privkey.pem"
            log "Symlink created: privkey.pem"
        fi
        
        if [ -f "$CERT_DIR/fullchain.pem" ]; then
            ln -sf "$CERT_DIR/fullchain.pem" "$SERVER_ROOT/fullchain.pem"
            log "Symlink created: fullchain.pem"
        fi
        
        # Create a status endpoint
        cat > "$SERVER_ROOT/status.json" << EOF
{
  "server": "ldap-certbot-http",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "domain": "${DOMAIN:-unknown}",
  "certificates": {
    "cert.pem": $([ -f "$CERT_DIR/cert.pem" ] && echo "true" || echo "false"),
    "privkey.pem": $([ -f "$CERT_DIR/privkey.pem" ] && echo "true" || echo "false"),
    "fullchain.pem": $([ -f "$CERT_DIR/fullchain.pem" ] && echo "true" || echo "false")
  }
}
EOF
        
        log "HTTP server directory setup completed"
    else
        warn "Certificate directory $CERT_DIR not found"
        
        # Create empty status file
        cat > "$SERVER_ROOT/status.json" << EOF
{
  "server": "ldap-certbot-http",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "domain": "${DOMAIN:-unknown}",
  "error": "Certificate directory not found"
}
EOF
    fi
}

# Start simple Python HTTP server
start_http_server() {
    log "Starting HTTP server on port $HTTP_PORT..."
    log "Serving directory: $SERVER_ROOT"
    
    cd "$SERVER_ROOT"
    
    # Start Python HTTP server in background
    if command -v python3 >/dev/null 2>&1; then
        python3 -m http.server "$HTTP_PORT" &
        local server_pid=$!
        
        log "HTTP server started with PID: $server_pid"
        
        # Wait a moment and check if server started successfully
        sleep 2
        
        if kill -0 $server_pid 2>/dev/null; then
            log "HTTP server is running successfully"
            log "Certificate files available at:"
            log "  http://certbot:$HTTP_PORT/cert.pem"
            log "  http://certbot:$HTTP_PORT/privkey.pem"
            log "  http://certbot:$HTTP_PORT/fullchain.pem"
            log "  http://certbot:$HTTP_PORT/status.json"
            
            # Return the PID so parent can track it
            echo $server_pid
            return 0
        else
            error "HTTP server failed to start"
            return 1
        fi
    else
        error "Python3 not found, cannot start HTTP server"
        return 1
    fi
}

# Watch for certificate updates and refresh symlinks
watch_certificate_updates() {
    log "Starting certificate update watcher..."
    
    local last_update_time=0
    
    while true; do
        # Check if certificate files have been updated
        if [ -f "$CERT_DIR/cert.pem" ]; then
            local current_update_time
            current_update_time=$(stat -f%m "$CERT_DIR/cert.pem" 2>/dev/null || stat -c%Y "$CERT_DIR/cert.pem" 2>/dev/null || echo 0)
            
            if [ "$current_update_time" -gt "$last_update_time" ]; then
                log "Certificate update detected, refreshing HTTP server content..."
                setup_server_directory
                last_update_time=$current_update_time
            fi
        fi
        
        # Check every 30 seconds
        sleep 30
    done
}

# Signal handler for graceful shutdown
setup_signal_handlers() {
    shutdown_handler() {
        log "Received shutdown signal, stopping HTTP server..."
        
        # Kill HTTP server processes
        pkill -f "python3 -m http.server $HTTP_PORT" >/dev/null 2>&1 || true
        
        log "HTTP server shutdown complete"
        exit 0
    }
    
    trap shutdown_handler SIGTERM SIGINT SIGQUIT
}

# Main function
main() {
    local mode="${1:-start}"
    
    case "$mode" in
        "start")
            log "Starting HTTP certificate server..."
            setup_signal_handlers
            
            # Setup initial directory structure
            setup_server_directory
            
            # Start HTTP server
            local server_pid
            if server_pid=$(start_http_server); then
                log "HTTP server initialization successful"
                
                # Start certificate watcher in background
                watch_certificate_updates &
                local watcher_pid=$!
                
                log "Certificate watcher started with PID: $watcher_pid"
                
                # Wait for either process to exit
                wait
            else
                error "Failed to start HTTP server"
                exit 1
            fi
            ;;
        "test")
            log "Testing HTTP server connectivity..."
            
            if curl -s "http://localhost:${HTTP_PORT}/status.json" >/dev/null; then
                log "HTTP server is accessible"
                curl -s "http://localhost:${HTTP_PORT}/status.json" | python3 -m json.tool
            else
                error "HTTP server is not accessible"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [start|test]"
            echo "  start - Start HTTP certificate server (default)"
            echo "  test  - Test HTTP server connectivity"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"