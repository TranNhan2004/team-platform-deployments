```sh
#!/bin/sh
set -eu

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"

: "${TEAM_KEYCLOAK_DB:?TEAM_KEYCLOAK_DB is required}"
: "${KC_DB_USERNAME:?KC_DB_USERNAME is required}"
: "${KC_DB_PASSWORD:?KC_DB_PASSWORD is required}"

: "${TEAM_TICKETS_DB:?TEAM_TICKETS_DB is required}"
: "${TEAM_TICKETS_DB_USERNAME:?TEAM_TICKETS_DB_USERNAME is required}"
: "${TEAM_TICKETS_DB_PASSWORD:?TEAM_TICKETS_DB_PASSWORD is required}"

: "${TEAM_DOCUMENTS_DB:?TEAM_DOCUMENTS_DB is required}"
: "${TEAM_DOCUMENTS_DB_USERNAME:?TEAM_DOCUMENTS_DB_USERNAME is required}"
: "${TEAM_DOCUMENTS_DB_PASSWORD:?TEAM_DOCUMENTS_DB_PASSWORD is required}"


create_role() {
  role_name="$1"
  role_password="$2"

  exists="$(
    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --tuples-only \
      --no-align \
      --set=role_name="$role_name" \
      --command "SELECT 1 FROM pg_roles WHERE rolname = :'role_name';"
  )"

  if [ "$exists" != "1" ]; then
    echo "Creating PostgreSQL role: $role_name"

    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --set=role_name="$role_name" \
      --set=role_password="$role_password" \
      --command "CREATE ROLE :\"role_name\" WITH LOGIN PASSWORD :'role_password';"
  else
    echo "PostgreSQL role already exists: $role_name"

    # Đồng bộ lại password theo giá trị environment hiện tại.
    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --set=role_name="$role_name" \
      --set=role_password="$role_password" \
      --command "ALTER ROLE :\"role_name\" WITH LOGIN PASSWORD :'role_password';"
  fi
}


create_database() {
  db_name="$1"
  db_owner="$2"

  exists="$(
    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --tuples-only \
      --no-align \
      --set=db_name="$db_name" \
      --command "SELECT 1 FROM pg_database WHERE datname = :'db_name';"
  )"

  if [ "$exists" != "1" ]; then
    echo "Creating database: $db_name, owner: $db_owner"

    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --set=db_name="$db_name" \
      --set=db_owner="$db_owner" \
      --command "CREATE DATABASE :\"db_name\" OWNER :\"db_owner\";"
  else
    echo "Database already exists: $db_name"

    echo "Ensuring database owner is: $db_owner"

    psql \
      --username "$POSTGRES_USER" \
      --dbname "$POSTGRES_DB" \
      --set=db_name="$db_name" \
      --set=db_owner="$db_owner" \
      --command "ALTER DATABASE :\"db_name\" OWNER TO :\"db_owner\";"
  fi
}


create_role "$KC_DB_USERNAME" "$KC_DB_PASSWORD"
create_role "$TEAM_TICKETS_DB_USERNAME" "$TEAM_TICKETS_DB_PASSWORD"
create_role "$TEAM_DOCUMENTS_DB_USERNAME" "$TEAM_DOCUMENTS_DB_PASSWORD"

create_database "$TEAM_KEYCLOAK_DB" "$KC_DB_USERNAME"
create_database "$TEAM_TICKETS_DB" "$TEAM_TICKETS_DB_USERNAME"
create_database "$TEAM_DOCUMENTS_DB" "$TEAM_DOCUMENTS_DB_USERNAME"

echo "PostgreSQL roles and databases initialized successfully."
```
