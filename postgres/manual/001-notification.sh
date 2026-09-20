#!/bin/sh
set -eu

ENV_FILE="${ENV_FILE:-../../env/.env.dev}"
COMPOSE_FILE="${COMPOSE_FILE:-../../docker-composes/compose.yml}"
COMPOSE_OVERRIDE_FILE="${COMPOSE_OVERRIDE_FILE:-../../docker-composes/compose.dev.yml}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Environment file not found: $ENV_FILE"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Compose file not found: $COMPOSE_FILE"
    exit 1
fi

echo "Loading environment variables from: $ENV_FILE"

set -a
. "$ENV_FILE"
set +a

: "${TEAM_NOTIFICATION_DB:?TEAM_NOTIFICATION_DB is required}"
: "${TEAM_NOTIFICATION_DB_USERNAME:?TEAM_NOTIFICATION_DB_USERNAME is required}"
: "${TEAM_NOTIFICATION_DB_PASSWORD:?TEAM_NOTIFICATION_DB_PASSWORD is required}"

POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

run_compose() {
    if [ -f "$COMPOSE_OVERRIDE_FILE" ]; then
        docker compose \
            --env-file "$ENV_FILE" \
            -f "$COMPOSE_FILE" \
            -f "$COMPOSE_OVERRIDE_FILE" \
            "$@"
    else
        docker compose \
            --env-file "$ENV_FILE" \
            -f "$COMPOSE_FILE" \
            "$@"
    fi
}

run_psql() {
    run_compose exec -T \
        "$POSTGRES_SERVICE" \
        psql \
        --username "$POSTGRES_USER" \
        --dbname "$POSTGRES_DB" \
        "$@"
}

create_role() {
    role_name="$1"
    role_password="$2"

    exists="$(
        run_psql \
            --tuples-only \
            --no-align \
            --set=role_name="$role_name" <<'SQL'
SELECT 1
FROM pg_roles
WHERE rolname = :'role_name';
SQL
    )"

    if [ "$exists" = "1" ]; then
        echo "PostgreSQL role already exists: $role_name"
        echo "Updating password for role: $role_name"

        run_psql \
            --set=role_name="$role_name" \
            --set=role_password="$role_password" <<'SQL'
ALTER ROLE :"role_name"
WITH LOGIN PASSWORD :'role_password';
SQL
    else
        echo "Creating PostgreSQL role: $role_name"

        run_psql \
            --set=role_name="$role_name" \
            --set=role_password="$role_password" <<'SQL'
CREATE ROLE :"role_name"
WITH LOGIN PASSWORD :'role_password';
SQL
    fi
}

create_database() {
    db_name="$1"
    db_owner="$2"

    exists="$(
        run_psql \
            --tuples-only \
            --no-align \
            --set=db_name="$db_name" <<'SQL'
SELECT 1
FROM pg_database
WHERE datname = :'db_name';
SQL
    )"

    if [ "$exists" = "1" ]; then
        echo "Database already exists: $db_name"
        echo "Ensuring database owner is: $db_owner"

        run_psql \
            --set=db_name="$db_name" \
            --set=db_owner="$db_owner" <<'SQL'
ALTER DATABASE :"db_name"
OWNER TO :"db_owner";
SQL
    else
        echo "Creating database: $db_name, owner: $db_owner"

        run_psql \
            --set=db_name="$db_name" \
            --set=db_owner="$db_owner" <<'SQL'
CREATE DATABASE :"db_name"
OWNER :"db_owner";
SQL
    fi
}

create_role \
    "$TEAM_NOTIFICATION_DB_USERNAME" \
    "$TEAM_NOTIFICATION_DB_PASSWORD"

create_database \
    "$TEAM_NOTIFICATION_DB" \
    "$TEAM_NOTIFICATION_DB_USERNAME"

echo "Team Notification Service database initialized successfully."