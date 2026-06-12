#!/bin/bash
# Exit on any error
set -e

echo "Setting up Data Service Styles environment..."

# Initialize SQLite database file
if [ ! -f "database/database.sqlite" ]; then
    echo "Initializing SQLite database..."
    touch database/database.sqlite
    chown sail:sail database/database.sqlite
fi

# Set proper ownership first (as root) - excluding .git directory
find /var/www/data-service-styles -type d -name ".git" -prune -o -type f -exec chown sail:sail {} \;
find /var/www/data-service-styles -type d ! -name ".git" -exec chown sail:sail {} \;
chown -R sail:sail /run/php

# Fix specific Laravel directories that need write permissions
chown -R sail:sail /var/www/data-service-styles/storage || true
chown -R sail:sail /var/www/data-service-styles/bootstrap/cache || true

# Change to the Laravel application directory
cd /var/www/data-service-styles

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

# Run migrations
echo "Running database migrations..."
gosu sail php artisan migrate --force

# Import database dump if available
# DUMPS_DIR="/var/opt/dumps"
# if [ -d "$DUMPS_DIR" ]; then
#     # Find the latest data-service-styles dump file
#     LATEST_DUMP=$(find "$DUMPS_DIR" -name "data-service-styles*.sql" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

#     if [ -n "$LATEST_DUMP" ] && [ -f "$LATEST_DUMP" ]; then
#         echo "Found database dump: $(basename "$LATEST_DUMP")"
#         echo "Importing database dump..."
#         # Import the dump directly using mysql command
#         mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "root" -ppassword "${DB_DATABASE}" < "$LATEST_DUMP"
#         echo "Database dump imported successfully!"
#     else
#         echo "No data-service-styles dump found"
#     fi
# else
#     echo "Dumps directory not found"
# fi

echo "Data Service Styles setup complete!"

# Start supervisor with PHP-FPM and Laravel server
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
