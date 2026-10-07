#!/bin/bash
# Exit on any error
set -e

echo "Setting up Membership Lookup environment..."

# Set proper ownership first (as root) - excluding .git directory
find /var/www/member-lookups \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type f -exec chown sail:sail {} +
find /var/www/member-lookups \( -name ".git" -o -name "node_modules" -o -name "storage" \) -prune -o -type d -exec chown sail:sail {} +
chown -R sail:sail /run/php

# Fix specific Laravel directories that need write permissions
chown -R sail:sail /var/www/member-lookups/storage || true
chown -R sail:sail /var/www/member-lookups/bootstrap/cache || true

# Change to the Laravel application directory
cd /var/www/member-lookups

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

echo "Membership Lookup setup complete!"

# Start supervisor with PHP-FPM
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
