#!/bin/bash
# Exit on any error
set -e

echo "Setting up Data Aggregator environment..."

# Setup utils environment if credentials are available
if [ -d "/var/opt/after_files" ] && [ "$(ls -A /var/opt/after_files 2>/dev/null)" ]; then
    ROOT_USER='root'
    ROOT_HOME="/home/${ROOT_USER}"
    DIR_FILES='/var/opt/after_files'

    # Ensure all files exist
    REQUIRED_FILES=('credentials' 'aic-aws.pem' 'github')

    for REQUIRED_FILE in "${REQUIRED_FILES[@]}"; do
        REQUIRED_PATH="${DIR_FILES}/${REQUIRED_FILE}"
        if [ ! -f "${REQUIRED_PATH}" ]; then
            echo "Missing file: ${REQUIRED_PATH}"
            exit 1
        fi
    done

    echo "All required credential files found"

    # Create necessary directories
    mkdir -p "${ROOT_HOME}/.aws"
    mkdir -p "${ROOT_HOME}/.ssh"

    # Verify SSH keys
    echo "Verifying SSH keys..."
    UNKNOWN_PUB=($(ssh-keygen -y -f "${DIR_FILES}/aic-aws.pem" | md5sum))
    DESIRED_PUB='35f84ba389901f5f53b18d4fb549af13'

    if [ "${UNKNOWN_PUB}" != "${DESIRED_PUB}" ]; then
        echo "Unexpected key signature: ${DIR_FILES}/aic-aws.pem"
        exit 1
    fi

    echo "SSH keys verified successfully"

    # Setup AWS and SSH credentials
    echo "Setting up AWS and SSH credentials..."
    cp "${DIR_FILES}/credentials" "${ROOT_HOME}/.aws/credentials"
    cp "${DIR_FILES}/aic-aws.pem" "${ROOT_HOME}/.ssh/aic-aws.pem"
    cp "${DIR_FILES}/github" "${ROOT_HOME}/.ssh/github"

    echo "Generating GitHub public key..."
    ssh-keygen -y -f "${ROOT_HOME}/.ssh/github" > "${ROOT_HOME}/.ssh/github.pub" 2>/dev/null || echo "Note: GitHub key may require passphrase"

    # Create AWS config
    cat << EOF > "/root/.aws/config"
[default]
output = json
region = us-east-1
EOF

    # Create SSH config
    cat << EOF > "/root/.ssh/config"
Host github github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github

Host *
    # Trust all hosts by default:
    ServerAliveInterval 60
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null

    # ...and stop yelling at me about it, too:
    LogLevel ERROR

    # Speed up SSH logon by disabling GSSAPI authentication
    GSSAPIAuthentication no

    # Default unless overridden:
    User ec2-user

    # Any keys added here will be checked for all hosts:
    IdentityFile ~/.ssh/aic-aws.pem
EOF

    # Set proper permissions
    chmod 600 \
        "${ROOT_HOME}/.aws/credentials" \
        "${ROOT_HOME}/.aws/config" \
        "${ROOT_HOME}/.ssh/config" \
        "${ROOT_HOME}/.ssh/aic-aws.pem" \
        "${ROOT_HOME}/.ssh/github" \
        "${ROOT_HOME}/.ssh/github.pub" 2>/dev/null

    # Change ownership to root user
    chown -R ${ROOT_USER}:${ROOT_USER} \
        "${ROOT_HOME}/.aws" \
        "${ROOT_HOME}/.ssh"

    # Copy AWS credentials to root user for ansible compatibility
    echo "Copying AWS credentials to root user..."
    mkdir -p /root/.aws
    cp "${ROOT_HOME}/.aws/credentials" /root/.aws/credentials
    cp "${ROOT_HOME}/.aws/config" /root/.aws/config
    chmod 600 /root/.aws/credentials /root/.aws/config

    echo "Utils environment setup completed!"
else
    echo "No credential files found, skipping utils setup"
fi

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysqladmin ping -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" --silent; do
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

# # Import database dump if available
# DUMPS_DIR="/var/opt/dumps"
# if [ -d "$DUMPS_DIR" ]; then
#     # Find the latest data_aggregator dump file
#     LATEST_DUMP=$(find "$DUMPS_DIR" -name "data_aggregator*.sql" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

#     if [ -n "$LATEST_DUMP" ] && [ -f "$LATEST_DUMP" ]; then
#         echo "Found database dump: $(basename "$LATEST_DUMP")"
#         echo "Importing database dump..."
#         # Import the dump directly using mysql command
#         mysql -h "${SETUP_DB_HOST}" -P "${SETUP_DB_PORT}" -u "root" -ppassword "${SETUP_DB_DATABASE}" < "$LATEST_DUMP"
#         echo "Database dump imported successfully!"
#     else
#         echo "No data_aggregator dump found"
#     fi
# else
#     echo "Dumps directory not found"
# fi

# echo "Verifying Elasticsearch indexes..."
# curl -s "http://${ELASTICSEARCH_HOST}/_cat/indices?v"

echo "Data Aggregator setup complete!"

# Start supervisor with PHP-FPM and Laravel server
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
