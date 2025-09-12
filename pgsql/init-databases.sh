#!/bin/bash
set -e

# Create databases if they don't exist
createdb -U "$POSTGRES_USER" website 2>/dev/null || echo "Database 'website' already exists"
createdb -U "$POSTGRES_USER" vectors 2>/dev/null || echo "Database 'vectors' already exists"
createdb -U "$POSTGRES_USER" tours 2>/dev/null || echo "Database 'tours' already exists"

# Grant privileges and create extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE vectors TO sail;
    GRANT ALL PRIVILEGES ON DATABASE website TO sail;
    GRANT ALL PRIVILEGES ON DATABASE tours TO sail;
EOSQL

# Create extensions in each database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "vectors" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "website" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo "Database initialization complete!"