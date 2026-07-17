#!/bin/bash
set -e

echo "Setting up Data Service Artist Enrichment..."

# Fix permissions
find /var/www/data-service-artist-enrichment -type d -name ".git" -prune -o -type f -exec chown sail:sail {} \;
find /var/www/data-service-artist-enrichment -type d ! -name ".git" -exec chown sail:sail {} \;

chown -R sail:sail /var/www/data-service-artist-enrichment/storage 2>/dev/null || true
chown -R sail:sail /var/www/data-service-artist-enrichment/bootstrap/cache 2>/dev/null || true

cd /var/www/data-service-artist-enrichment

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USERNAME}" -d "${DB_DATABASE}" -c "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL.."
    sleep 2
done
echo "PostgreSQL is ready!"

# Install Composer dependencies if needed
if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
    echo "Installing Composer dependencies..."
    gosu sail composer install --no-dev --optimize-autoloader
fi

# Generate app key if missing
if [ ! -f ".env" ] || ! grep -q "APP_KEY=base64:" .env; then
    echo "Generating application key..."
    gosu sail php artisan key:generate --no-interaction
fi

# Run migrations
echo "Running database migrations..."
gosu sail php artisan migrate --force

echo "Data Service Artist Enrichment setup complete!"

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
