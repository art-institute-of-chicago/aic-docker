#!/bin/bash
# Exit on any error
set -e

echo "Setting up Data Aggregator environment..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" -u "root" -ppassword -D "${SETUP_DB_DATABASE}" -e "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for MySQL.."
    sleep 2
done

echo "Adding database privileges..."
  mysql -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" -u "root" -ppassword -e "
  GRANT ALL PRIVILEGES ON \`data-aggregator\`.* TO 'sail'@'%';
  GRANT ALL PRIVILEGES ON \`data-enhancer\`.* TO 'sail'@'%';
  FLUSH PRIVILEGES;
  SHOW GRANTS FOR 'sail'@'%';
  "
echo "Database privileges added!"

# Set proper ownership first (as root) - excluding .git, node_modules, and storage (chowned separately below)
find /var/www/data-aggregator \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type f -exec chown sail:sail {} +
find /var/www/data-aggregator \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type d -exec chown sail:sail {} +
chown -R sail:sail /run/php

# Fix specific Laravel directories that need write permissions
chown -R sail:sail /var/www/data-aggregator/storage || true
chown -R sail:sail /var/www/data-aggregator/bootstrap/cache || true

# Change to the Laravel application directory
cd /var/www/data-aggregator

# Install Composer dependencies if they don't exist
if [ ! -d "vendor" ]; then
    echo "Installing Composer dependencies..."
    gosu sail composer install --no-dev --optimize-autoloader
fi

# Generate app key if it doesn't exist
if [ ! -f ".env" ] || ! grep -q "APP_KEY=base64:" .env; then
    echo "Generating application key..."
    gosu sail php artisan key:generate --no-interaction
fi

# Import database dump if available
DUMPS_DIR="/var/opt/dumps"
if [ -d "$DUMPS_DIR" ]; then
    # Find the latest data_aggregator dump file
    LATEST_DUMP=$(find "$DUMPS_DIR" -name "data_aggregator*.sql" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -n "$LATEST_DUMP" ] && [ -f "$LATEST_DUMP" ]; then
        echo "Found database dump: $(basename "$LATEST_DUMP")"
        echo "Importing database dump..."
        # Import the dump directly using mysql command
        mysql -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" -u "root" -ppassword "${SETUP_DB_DATABASE}" < "$LATEST_DUMP"
        echo "Database dump imported successfully!"
    else
        echo "No data_aggregator dump found"
    fi
else
    echo "Dumps directory not found"
fi

# echo "Verifying Elasticsearch indexes..."
# curl -s "http://${ELASTICSEARCH_HOST}/_cat/indices?v"

echo "Data Aggregator setup complete!"

# Start supervisor with PHP-FPM and Laravel server
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
