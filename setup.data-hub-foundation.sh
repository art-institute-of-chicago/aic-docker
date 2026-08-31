#!/bin/bash
# Exit on any error
set -e

echo "Setting up Data Hub Foundation environment..."

# Set proper ownership first (as root) - excluding .git directory
find /var/www/data-hub-foundation \( -name ".git" -o -name "node_modules" \) -prune -o -type f -exec chown sail:sail {} +
find /var/www/data-hub-foundation \( -name ".git" -o -name "node_modules" \) -prune -o -type d -exec chown sail:sail {} +

git config --global --add safe.directory /var/www/data-hub-foundation

# Change to the Laravel application directory
cd /var/www/data-hub-foundation

echo "Data Hub Foundation setup complete!@"

# Keep the container running (files are served by the shared nginx container)
exec tail -f /dev/null
