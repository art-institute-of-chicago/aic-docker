#!/bin/bash
# Exit on any error
set -e

echo "Setting up Data Aggregator environment..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "root" -ppassword -D "${DB_DATABASE}" -e "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for MySQL.."
    sleep 2
done

echo "Adding database privileges..."
  mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "root" -ppassword -e "
  GRANT ALL PRIVILEGES ON \`data-aggregator\`.* TO 'sail'@'%';
  GRANT ALL PRIVILEGES ON \`data-enhancer\`.* TO 'sail'@'%';
  FLUSH PRIVILEGES;
  SHOW GRANTS FOR 'sail'@'%';
  "
echo "Database privileges added!"

# Wait for Elasticsearch with better error handling and timeout
echo "Waiting for Elasticsearch to be ready..."
ELASTICSEARCH_HOST="elasticsearch:9200"
MAX_RETRIES=30
RETRY_COUNT=0

until curl -s --max-time 10 "http://${ELASTICSEARCH_HOST}/_cluster/health?wait_for_status=yellow&timeout=10s" > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Elasticsearch failed to start after ${MAX_RETRIES} attempts"
        echo "Checking Elasticsearch logs..."
        curl -v "http://${ELASTICSEARCH_HOST}/" || true
        exit 1
    fi
    echo "Waiting for Elasticsearch... (attempt ${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 5
done

echo "Elasticsearch is ready!"

# Test Elasticsearch connection
echo "Testing Elasticsearch connection..."
if ! curl -s -f "http://${ELASTICSEARCH_HOST}/" > /dev/null; then
    echo "ERROR: Cannot connect to Elasticsearch"
    exit 1
fi

echo "Elasticsearch connection verified successfully!"

# Set proper ownership first (as root) - excluding .git directory
find /var/www/data-aggregator/html -type d -name ".git" -prune -o -type f -exec chown sail:sail {} \;
find /var/www/data-aggregator/html -type d ! -name ".git" -exec chown sail:sail {} \;
chown -R sail:sail /run/php

# Fix specific Laravel directories that need write permissions
chown -R sail:sail /var/www/data-aggregator/html/storage || true
chown -R sail:sail /var/www/data-aggregator/html/bootstrap/cache || true

# Change to the Laravel application directory
cd /var/www/data-aggregator/html

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
DUMPS_DIR="/var/utils/dumps"
if [ -d "$DUMPS_DIR" ]; then
    # Find the latest data_aggregator dump file
    LATEST_DUMP=$(find "$DUMPS_DIR" -name "data_aggregator*.sql" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -n "$LATEST_DUMP" ] && [ -f "$LATEST_DUMP" ]; then
        echo "Found database dump: $(basename "$LATEST_DUMP")"
        echo "Importing database dump..."
        # Import the dump directly using mysql command
        mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "root" -ppassword "${DB_DATABASE}" < "$LATEST_DUMP"
        echo "Database dump imported successfully!"
    else
        echo "No data_aggregator dump found"
    fi
else
    echo "Dumps directory not found"
fi

# Clear any existing search indexes first
echo "Clearing existing Elasticsearch indexes..."
gosu sail php artisan scout:flush --all || true

# Set up Elasticsearch indexes with error handling
echo "Setting up Elasticsearch indexes..."
if ! gosu sail php artisan search:install; then
    echo "ERROR: Failed to install search indexes"
    echo "Checking Elasticsearch status..."
    curl -s "http://${ELASTICSEARCH_HOST}/_cat/health?v" || true
    exit 1
fi

# Import all data into search indexes
echo "Importing data into Elasticsearch..."
if ! gosu sail php artisan scout:import-all; then
    echo "ERROR: Failed to import data into Elasticsearch"
    echo "Checking existing indexes..."
    curl -s "http://${ELASTICSEARCH_HOST}/_cat/indices?v" || true
    exit 1
fi

echo "Verifying Elasticsearch indexes..."
curl -s "http://${ELASTICSEARCH_HOST}/_cat/indices?v"

echo "Data Aggregator setup complete!"

# Start supervisor with PHP-FPM and Laravel server
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf