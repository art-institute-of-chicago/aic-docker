#!/bin/bash
# Exit on any error
set -e

echo "Setting up Mobile Admin environment..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysqladmin ping -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" --silent; do
    echo "Waiting for MySQL.."
    sleep 2
done

echo "Adding database privileges..."
  mysql -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" -u "root" -ppassword -e "
  CREATE DATABASE IF NOT EXISTS \`mobile-admin\`;
  GRANT ALL PRIVILEGES ON \`mobile-admin\`.* TO 'sail'@'%';
  FLUSH PRIVILEGES;
  SHOW GRANTS FOR 'sail'@'%';
  "
echo "Database privileges added!"

# Set proper ownership first (as root) - excluding .git directory
find /var/www/mobile-admin \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type f -exec chown sail:sail {} +
find /var/www/mobile-admin \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type d -exec chown sail:sail {} +
chown -R sail:sail /run/php

# Fix specific Laravel directories that need write permissions
chown -R sail:sail /var/www/mobile-admin/storage || true
chown -R sail:sail /var/www/mobile-admin/bootstrap/cache || true

# Change to the Laravel application directory
cd /var/www/mobile-admin

# Clear caches
gosu sail php artisan config:clear
gosu sail php artisan route:clear

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

# Symlink storage
echo "Symlinking public storage..."
gosu sail php artisan storage:link

echo "Mobile Admin setup complete!"

# Start supervisor with PHP-FPM and Laravel server
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
