#!/usr/bin/env bash

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER sail
fi

# Setup utils environment if credentials are available
if [ -d "/var/opt/after_files" ] && [ "$(ls -A /var/opt/after_files 2>/dev/null)" ]; then
    echo "Setting up utils environment..."

    SAIL_USER='sail'
    SAIL_HOME="/home/${SAIL_USER}"
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
    mkdir -p "${SAIL_HOME}/.aws"
    mkdir -p "${SAIL_HOME}/.ssh"

    if [ "${UNKNOWN_PUB}" != "${DESIRED_PUB}" ]; then
        echo "Unexpected key signature: ${DIR_FILES}/aic-aws.pem"
        exit 1
    fi

    echo "SSH keys verified successfully"

    # Setup AWS and SSH credentials
    echo "Setting up AWS and SSH credentials..."
    cp "${DIR_FILES}/credentials" "${SAIL_HOME}/.aws/credentials"
    cp "${DIR_FILES}/aic-aws.pem" "${SAIL_HOME}/.ssh/aic-aws.pem"
    cp "${DIR_FILES}/github" "${SAIL_HOME}/.ssh/github"

    echo "Generating GitHub public key..."
    ssh-keygen -y -f "${SAIL_HOME}/.ssh/github" > "${SAIL_HOME}/.ssh/github.pub" 2>/dev/null || echo "Note: GitHub key may require passphrase"

    # Create AWS config
    cat << EOF > "${SAIL_HOME}/.aws/config"
[default]
output = json
region = us-east-1
EOF

    # Create SSH config
    cat << EOF > "${SAIL_HOME}/.ssh/config"
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
        "${SAIL_HOME}/.aws/credentials" \
        "${SAIL_HOME}/.aws/config" \
        "${SAIL_HOME}/.ssh/config" \
        "${SAIL_HOME}/.ssh/aic-aws.pem" \
        "${SAIL_HOME}/.ssh/github" \
        "${SAIL_HOME}/.ssh/github.pub" 2>/dev/null

    # Change ownership to sail user
    chown -R ${SAIL_USER}:${SAIL_USER} \
        "${SAIL_HOME}/.aws" \
        "${SAIL_HOME}/.ssh"

    # Copy AWS credentials to root user for ansible compatibility
    echo "Copying AWS credentials to root user..."
    mkdir -p /root/.aws
    cp "${SAIL_HOME}/.aws/credentials" /root/.aws/credentials
    cp "${SAIL_HOME}/.aws/config" /root/.aws/config
    chmod 600 /root/.aws/credentials /root/.aws/config

    echo "Utils environment setup completed!"
else
    echo "No credential files found, skipping utils setup"
fi

# Set proper ownership of the working directory (skip git directories to avoid permission issues)
find /var/opt/utils -type f ! -path '*/.git/*' -exec chown sail:sail {} \; 2>/dev/null || true
find /var/opt/utils -type d ! -path '*/.git*' -exec chown sail:sail {} \; 2>/dev/null || true

if [ $# -gt 0 ]; then
    exec gosu sail "$@"
else
    # Keep the container running and switch to sail user for interactive use
    exec gosu sail bash -c "cd /var/opt/utils && exec bash"
fi
