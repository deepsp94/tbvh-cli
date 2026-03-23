#!/usr/bin/env bash
# Authenticate with TBVH using SIWE (Sign-In with Ethereum)
source "$(dirname "$0")/lib/common.sh"

ADDRESS=$(get_address)
print_info "Authenticating as $ADDRESS"

# 1. Get nonce
NONCE_RESP=$(curl -sf "$TBVH_API/auth/nonce?address=$ADDRESS")
NONCE=$(echo "$NONCE_RESP" | jq -r '.nonce')

if [[ -z "$NONCE" || "$NONCE" == "null" ]]; then
  print_err "Failed to get nonce"
  echo "$NONCE_RESP"
  exit 1
fi

# 2. Construct SIWE message
ISSUED_AT=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
MESSAGE="${TBVH_DOMAIN} wants you to sign in with your Ethereum account:
${ADDRESS}

Sign in to TBVH

URI: https://${TBVH_DOMAIN}
Version: 1
Chain ID: 84532
Nonce: ${NONCE}
Issued At: ${ISSUED_AT}"

# 3. Sign the message
SIGNATURE=$(cast wallet sign --private-key "$PRIVATE_KEY" "$MESSAGE")

# 4. Verify with backend
VERIFY_RESP=$(curl -sf "$TBVH_API/auth/verify" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg msg "$MESSAGE" --arg sig "$SIGNATURE" '{message: $msg, signature: $sig}')")

TOKEN=$(echo "$VERIFY_RESP" | jq -r '.token')
EXPIRES=$(echo "$VERIFY_RESP" | jq -r '.expiresAt')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  print_err "Authentication failed"
  echo "$VERIFY_RESP"
  exit 1
fi

# 5. Save JWT
echo -n "$TOKEN" > "$JWT_FILE"
print_ok "Authenticated successfully"
print_dim "  Address: $ADDRESS"
print_dim "  Expires: $EXPIRES"
print_dim "  JWT saved to .tbvh_jwt"
