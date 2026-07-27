#!/bin/bash
# Exit on any error
set -e

echo "Setting up Journeymaker Client environment..."

# Set proper ownership first (as root) - excluding .git directory
find /var/www/journeymaker-client -type d -name ".git" -prune -o -type f -exec chown sail:sail {} \;
find /var/www/journeymaker-client -type d ! -name ".git" -exec chown sail:sail {} \;

# Change to the Laravel application directory
cd /var/www/journeymaker-client

# Import database dump if available
# DUMPS_DIR="/var/opt/dumps"
# if [ -d "$DUMPS_DIR" ]; then
#     # Find the latest journeymaker-client dump file
#     LATEST_DUMP=$(find "$DUMPS_DIR" -name "journeymaker-client*.sql" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

#     if [ -n "$LATEST_DUMP" ] && [ -f "$LATEST_DUMP" ]; then
#         echo "Found database dump: $(basename "$LATEST_DUMP")"
#         echo "Importing database dump..."
#         # Import the dump directly using mysql command
#         mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "root" -ppassword "${DB_DATABASE}" < "$LATEST_DUMP"
#         echo "Database dump imported successfully!"
#     else
#         echo "No journeymaker-client dump found"
#     fi
# else
#     echo "Dumps directory not found"
# fi

echo "Journeymaker Client setup complete!"

# Keep the container running (files are served by the shared nginx container)
exec tail -f /dev/null
