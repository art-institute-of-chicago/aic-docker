#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# All available profiles with descriptions (sync with docker-compose.yml)
# Parallel arrays: ALL_PROFILES[i] matches SERVICE_DESC[i]
ALL_PROFILES=(
  website
  utils
  data-aggregator
  data-service-assets
  data-service-styles
  data-service-archives
  data-enhancer
  journeymaker-client
  data-service-artist-enrichment
)

SERVICE_DESC=(
  "Main website (Laravel)"
  "Utility scripts + Ansible"
  "Data aggregation pipeline"
  "Assets microservice"
  "Styles microservice"
  "Archives microservice"
  "Data enhancement service"
  "JourneyMaker frontend"
  "Artist enrichment service"
)

# ── helpers ──────────────────────────────────────────────────
build_profile_flags() {
  local flags=()
  for p in "$@"; do
    flags+=(--profile "$p")
  done
  echo "${flags[@]}"
}

run_compose() {
  local down="$1"; local build="$2"; shift 2
  local profiles=("$@")

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "No services selected." >&2
    return 1
  fi

  cd "$SCRIPT_DIR"

  if $down; then
    echo "Stopping: ${profiles[*]}"
    docker compose $(build_profile_flags "${profiles[@]}") down
  else
    echo "Starting: ${profiles[*]}"
    if $build; then
      docker compose $(build_profile_flags "${profiles[@]}") up -d --build
    else
      docker compose $(build_profile_flags "${profiles[@]}") up -d
    fi
  fi
}

# ── interactive menu ─────────────────────────────────────────
interactive_menu() {
  local down="$1"
  local build="$2"

  echo ""
  echo "  Select services to $( $down && echo "stop" || echo "start" ):"
  echo "  ─────────────────────────────────────────"
  for i in "${!ALL_PROFILES[@]}"; do
    local name="${ALL_PROFILES[$i]}"
    local num=$((i + 1))
    printf "  %2d) %-36s %s\n" "$num" "$name" "${SERVICE_DESC[$i]}"
  done
  echo "  ─────────────────────────────────────────"
  echo "   a) All services"
  echo "   q) Quit"
  echo ""

  while true; do
    read -r -p "  Enter numbers (space/comma-separated) or 'a': " input

    # Normalize: replace commas with spaces, collapse whitespace
    input=$(echo "$input" | tr ',' ' ' | xargs)

    if [[ -z "$input" ]]; then
      continue
    fi

    # Quit
    if [[ "$input" =~ ^[qQ]$ ]]; then
      echo "  Cancelled."
      return 1
    fi

    # All
    if [[ "$input" =~ ^[aA]$ ]]; then
      run_compose "$down" "$build" "${ALL_PROFILES[@]}"
      return
    fi

    # Parse numbers
    local selected=()
    local invalid=false
    for token in $input; do
      if [[ "$token" =~ ^[0-9]+$ ]]; then
        local idx=$((token - 1))
        if [[ $idx -ge 0 && $idx -lt ${#ALL_PROFILES[@]} ]]; then
          selected+=("${ALL_PROFILES[$idx]}")
        else
          echo "  Invalid number: $token (1-${#ALL_PROFILES[@]})" >&2
          invalid=true
        fi
      else
        echo "  Invalid input: $token" >&2
        invalid=true
      fi
    done

    if $invalid; then
      continue
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
      continue
    fi

    echo ""
    echo "  Selected: ${selected[*]}"
    read -r -p "  Confirm? [Y/n] " confirm

    if [[ "$confirm" =~ ^[Nn] ]]; then
      continue
    fi

    run_compose "$down" "$build" "${selected[@]}"
    return
  done
}

# ── CLI mode ─────────────────────────────────────────────────
usage() {
  echo "Usage: compose.sh [SERVICE...] [--all] [--build] [--down] [--list]"
  echo ""
  echo "  No args  → interactive prompt to select services"
  echo ""
  echo "  SERVICE   One or more service names"
  echo "  --all     All services"
  echo "  --build   Rebuild images before starting"
  echo "  --down    Stop and remove (all or specified)"
  echo "  --list    List available services"
  echo "  -h,--help This help"
  echo ""
  echo "Examples:"
  echo "  compose.sh                              # Interactive menu"
  echo "  compose.sh website data-aggregator"
  echo "  compose.sh --all"
  echo "  compose.sh --down"
  echo "  compose.sh --build website"
}

# ── main ─────────────────────────────────────────────────────
BUILD=false
DOWN=false
ALL=false
PROFILES=()

for arg in "$@"; do
  case "$arg" in
    --build) BUILD=true ;;
    --down)  DOWN=true ;;
    --all|-a) ALL=true ;;
    -h|--help) usage; exit 0 ;;
    --list|-l|--ls)
      echo "Available services:"
      for i in "${!ALL_PROFILES[@]}"; do
        printf "  %-36s %s\n" "${ALL_PROFILES[$i]}" "${SERVICE_DESC[$i]}"
      done
      exit 0
      ;;
    -*)
      echo "Unknown flag: $arg" >&2
      usage
      exit 1
      ;;
    *)
      if printf '%s\n' "${ALL_PROFILES[@]}" | grep -qxF "$arg"; then
        PROFILES+=("$arg")
      else
        echo "Unknown service: $arg" >&2
        echo "Run 'compose.sh --list' for available services." >&2
        exit 1
      fi
      ;;
  esac
done

# ── execute ──────────────────────────────────────────────────
if $ALL; then
  run_compose "$DOWN" "$BUILD" "${ALL_PROFILES[@]}"
elif [[ ${#PROFILES[@]} -gt 0 ]]; then
  run_compose "$DOWN" "$BUILD" "${PROFILES[@]}"
else
  interactive_menu "$DOWN" "$BUILD"
fi
