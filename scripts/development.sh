```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$PROJECT_DIR/env/.env.development"
COMPOSE_FILE="$PROJECT_DIR/compose.yaml"
DEV_COMPOSE_FILE="$PROJECT_DIR/compose.development.yaml"

ACTION="${1:-up}"
PROFILE="${2:-full}"

compose() {
  docker compose \
    --env-file "$ENV_FILE" \
    -f "$COMPOSE_FILE" \
    -f "$DEV_COMPOSE_FILE" \
    --profile "$PROFILE" \
    "$@"
}

case "$ACTION" in
  up)
    compose up -d --build
    ;;

  rebuild)
    compose build --no-cache
    compose up -d
    ;;

  down)
    compose down
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
    exit 1
    ;;
esac
```
