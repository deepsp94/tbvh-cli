#!/usr/bin/env bash
# Shared helpers for tbvh-cli scripts

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Resolve script directory (works regardless of where scripts are called from)
CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env
if [[ -f "$CLI_DIR/.env" ]]; then
  set -a
  source "$CLI_DIR/.env"
  set +a
else
  echo -e "${RED}No .env file found. Copy .env.example to .env and fill in your values.${NC}"
  exit 1
fi

# Check required tools
for cmd in curl jq cast; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Missing required tool: $cmd${NC}"
    [[ "$cmd" == "cast" ]] && echo "  Install Foundry: https://book.getfoundry.sh/getting-started/installation"
    [[ "$cmd" == "jq" ]] && echo "  Install jq: https://jqlang.github.io/jq/download/"
    exit 1
  fi
done

# Check required env vars
for var in TBVH_API TBVH_DOMAIN PRIVATE_KEY RPC_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo -e "${RED}Missing env var: $var${NC}"
    exit 1
  fi
done

# Derive address from private key
get_address() {
  cast wallet address "$PRIVATE_KEY"
}

# JWT management
JWT_FILE="$CLI_DIR/.tbvh_jwt"

load_jwt() {
  if [[ -f "$JWT_FILE" ]]; then
    cat "$JWT_FILE"
  else
    echo ""
  fi
}

require_jwt() {
  local jwt
  jwt=$(load_jwt)
  if [[ -z "$jwt" ]]; then
    echo -e "${RED}Not authenticated. Run ./auth.sh first.${NC}"
    exit 1
  fi
  echo "$jwt"
}

# API helpers
tbvh_get() {
  local path="$1"
  local jwt
  jwt=$(load_jwt)
  if [[ -n "$jwt" ]]; then
    curl -sf "$TBVH_API$path" -H "Authorization: Bearer $jwt"
  else
    curl -sf "$TBVH_API$path"
  fi
}

tbvh_post() {
  local path="$1"
  local data="${2:-}"
  local jwt
  jwt=$(require_jwt)
  if [[ -n "$data" ]]; then
    curl -sf "$TBVH_API$path" \
      -H "Authorization: Bearer $jwt" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -sf "$TBVH_API$path" \
      -X POST \
      -H "Authorization: Bearer $jwt"
  fi
}

tbvh_delete() {
  local path="$1"
  local jwt
  jwt=$(require_jwt)
  curl -sf "$TBVH_API$path" \
    -X DELETE \
    -H "Authorization: Bearer $jwt"
}

# TEE info (cached per session)
_TEE_INFO=""
get_tee_info() {
  if [[ -z "$_TEE_INFO" ]]; then
    _TEE_INFO=$(curl -sf "$TBVH_API/tee/info")
  fi
  echo "$_TEE_INFO"
}

get_escrow_address() {
  get_tee_info | jq -r '.contractAddress'
}

get_usdc_address() {
  get_tee_info | jq -r '.tokenAddress'
}

# Convert negotiation UUID to bytes32 for escrow contract
neg_id_to_bytes32() {
  local neg_id="$1"
  cast keccak "$(cast --to-hex-data "$neg_id")"
}

# Pretty print helpers
print_ok() { echo -e "${GREEN}✓${NC} $1"; }
print_err() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}→${NC} $1"; }
print_warn() { echo -e "${YELLOW}!${NC} $1"; }
print_dim() { echo -e "${DIM}$1${NC}"; }
