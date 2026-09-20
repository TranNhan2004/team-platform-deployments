#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
KEYCLOAK_BACKUP_DIR="$(cd -- "$PROJECT_DIR/../keycloak" && pwd)"

ENV_FILE="$PROJECT_DIR/env/.env.dev"
COMPOSE_FILE="$PROJECT_DIR/docker-composes/compose.yml"
DEV_COMPOSE_FILE="$PROJECT_DIR/docker-composes/compose.dev.yml"

ACTION="${1:-up}"
PROFILE="${2:-}"

for file in "$ENV_FILE" "$COMPOSE_FILE" "$DEV_COMPOSE_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
  fi
done

compose() {
  local args=(
    --env-file "$ENV_FILE"
    -f "$COMPOSE_FILE"
    -f "$DEV_COMPOSE_FILE"
  )

  if [[ -n "$PROFILE" ]]; then
    args+=(--profile "$PROFILE")
  fi

  docker compose "${args[@]}" "$@"
}

case "$ACTION" in
  up)
    compose up -d --build
    ;;

  stop)
    compose stop
    ;;

  rebuild)
    compose build --no-cache
    compose up -d
    ;;

  down)
    compose down
    ;;

  down-v)
    compose down -v
    ;;

  restart)
    compose restart
    ;;

  logs)
    compose logs -f --tail=200
    ;;

  ps)
    compose ps
    ;;

  config)
    compose config
    ;;

  clean)
    compose down --remove-orphans
    ;;

  reset)
    echo "This will remove PostgreSQL and Redis volumes."
    read -r -p "Continue? [y/N] " answer

    case "$answer" in
      y|Y)
        compose down -v --remove-orphans
        compose up -d --build
        ;;
      *)
        echo "Cancelled."
        ;;
    esac
    ;;

  reset-keycloak-admin)
    echo "Stopping Keycloak..."
    compose stop keycloak

    echo "Creating temporary recovery admin..."

    if compose run --rm --no-deps keycloak \
        bootstrap-admin user \
        --username:env KC_BOOTSTRAP_ADMIN_USERNAME \
        --password:env KC_BOOTSTRAP_ADMIN_PASSWORD \
        --no-prompt
    then
        echo "Temporary admin created successfully."
    else
        status=$?
        echo "Failed to create temporary admin." >&2

        echo "Starting Keycloak again..."
        compose up -d keycloak

        exit "$status"
    fi

    echo "Starting Keycloak..."
    compose up -d keycloak

    echo
    echo "Recovery admin created."
    echo "Login to the master realm Admin Console using:"
    echo "  username: \$KC_BOOTSTRAP_ADMIN_USERNAME"
    echo "  password: \$KC_BOOTSTRAP_ADMIN_PASSWORD"
    ;;

  export-keycloak)
    echo "Stopping Keycloak..."
    compose stop keycloak

    mkdir -p "$KEYCLOAK_BACKUP_DIR"

    echo "Exporting realm team-platform..."

    if compose run --rm --no-deps \
        -v "$KEYCLOAK_BACKUP_DIR:/opt/keycloak/data/export" \
        keycloak \
        export \
        --dir /opt/keycloak/data/export \
        --realm team-platform \
        --users realm_file
    then
        echo "Export completed:"
        echo "  $KEYCLOAK_BACKUP_DIR/team-platform-realm.json"
    else
        status=$?
        echo "Export failed." >&2

        compose up -d keycloak
        exit "$status"
    fi

    echo "Starting Keycloak..."
    compose up -d keycloak
    ;;

  import-keycloak)
    BACKUP_FILE="$KEYCLOAK_BACKUP_DIR/team-platform-realm.json"

    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo "Backup file not found: $BACKUP_FILE" >&2
        exit 1
    fi

    echo "Stopping Keycloak..."
    compose stop keycloak

    echo "Importing realm team-platform..."

    if compose run --rm --no-deps \
        -v "$KEYCLOAK_BACKUP_DIR:/opt/keycloak/data/import:ro" \
        keycloak \
        import \
        --file /opt/keycloak/data/import/team-platform-realm.json \
        --override true
    then
        echo "Import completed."
    else
        status=$?
        echo "Import failed." >&2

        compose up -d keycloak
        exit "$status"
    fi

    echo "Starting Keycloak..."
    compose up -d keycloak
    ;;

  *)
    echo "Usage:"
    echo "  $0 up [profile]"
    echo "  $0 rebuild [profile]"
    echo "  $0 down [profile]"
    echo "  $0 restart [profile]"
    echo "  $0 logs [profile]"
    echo "  $0 ps [profile]"
    echo "  $0 config [profile]"
    echo "  $0 clean [profile]"
    echo "  $0 reset [profile]"
    echo "  $0 reset-keycloak-admin [profile]"
    exit 1
    ;;
esac