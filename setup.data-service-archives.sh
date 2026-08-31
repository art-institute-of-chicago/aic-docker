#!/bin/bash
set -e

echo "Setting up Data Service Archives environment..."

echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD="${SETUP_DB_PASSWORD}" psql -h "${SETUP_DB_HOST}" -p "${SETUP_DB_PORT}" -U "${SETUP_DB_USERNAME}" -d "${SETUP_DB_DATABASE}" -c "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL.."
    sleep 2
done

echo "PostgreSQL is ready!"

find /var/www/data-service-archives -type d -name ".git" -prune -o -type f -exec chown sail:sail {} \;
find /var/www/data-service-archives -type d ! -name ".git" -exec chown sail:sail {} \;
chown -R sail:sail /run/php

chown -R sail:sail /var/www/data-service-archives/storage || true
chown -R sail:sail /var/www/data-service-archives/bootstrap/cache || true

cd /var/www/data-service-archives

if [ ! -d "vendor" ]; then
    echo "Installing Composer dependencies..."
    gosu sail composer install --no-dev --optimize-autoloader
fi

if [ ! -f ".env" ] || ! grep -q "APP_KEY=base64:" .env; then
    echo "Generating application key..."
    gosu sail php artisan key:generate --no-interaction
fi

echo "Data Service Archives setup complete!"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
