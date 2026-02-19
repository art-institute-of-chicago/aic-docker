#!/usr/bin/env bash

if [ "$SUPERVISOR_PHP_USER" != "root" ] && [ "$SUPERVISOR_PHP_USER" != "sail" ]; then
    echo "You should set SUPERVISOR_PHP_USER to either 'sail' or 'root'."
    exit 1
fi

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER sail
fi

if [ ! -d /.composer ]; then
    mkdir /.composer
fi

chmod -R ugo+rw /.composer

# Setup utils environment if credentials are available
if [ -d "/var/opt/after_files" ] && [ "$(ls -A /var/opt/after_files 2>/dev/null)" ]; then
    echo "Setting up utils environment..."
    UTILS_SETUP_SCRIPT="/var/opt/utils/docker/setup.sh"
    if [ -f "$UTILS_SETUP_SCRIPT" ]; then
        # Fix permissions and line endings if needed
        chmod +x "$UTILS_SETUP_SCRIPT"
        # Convert Windows line endings to Unix if present
        sed -i 's/\r$//' "$UTILS_SETUP_SCRIPT" 2>/dev/null || true

        if [ -x "$UTILS_SETUP_SCRIPT" ]; then
            bash "$UTILS_SETUP_SCRIPT"
            echo "Utils environment setup completed"
        else
            echo "Warning: Could not make setup script executable at $UTILS_SETUP_SCRIPT"
        fi
    else
        echo "Warning: Utils setup script not found at $UTILS_SETUP_SCRIPT"
        echo "Expected location: /var/opt/utils/docker/setup.sh"
    fi
else
    echo "No credential files found in /var/opt/after_files, skipping utils setup"
fi

# Ensure PHP-FPM runtime directory exists
mkdir -p /run/php
chown -R sail:sail /run/php

if [ $# -gt 0 ]; then
    exec gosu $WWWUSER "$@"
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
