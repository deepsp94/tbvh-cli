#!/usr/bin/env bash
# Seller operations: list, commit, commit-email, status, mine
source "$(dirname "$0")/lib/common.sh"

CMD="${1:-help}"
shift || true

case "$CMD" in
  list)
    STATUS="${1:-open}"
    RESP=$(tbvh_get "/instances?status=$STATUS")
    COUNT=$(echo "$RESP" | jq length)
    print_info "$COUNT instances ($STATUS)"
    echo "$RESP" | jq -r '.[] | "  \(.id)  \(.max_payment) USDC  \(.buyer_requirement_title[:80])"'
    ;;

  commit)
    INSTANCE_ID="${1:?Usage: ./seller.sh commit <instance-id> \"info\" \"proof\" [\"instructions\"]}"
    INFO="${2:?Usage: ./seller.sh commit <instance-id> \"info\" \"proof\" [\"instructions\"]}"
    PROOF="${3:?Usage: ./seller.sh commit <instance-id> \"info\" \"proof\" [\"instructions\"]}"
    INSTRUCTIONS="${4:-}"
    JWT=$(require_jwt)
    DATA=$(jq -n \
      --arg info "$INFO" \
      --arg proof "$PROOF" \
      --arg prompt "$INSTRUCTIONS" \
      '{seller_info: $info, seller_proof: $proof} + (if $prompt != "" then {seller_prompt: $prompt} else {} end)')
    RESP=$(tbvh_post "/instances/$INSTANCE_ID/negotiate" "$DATA")
    NEG_ID=$(echo "$RESP" | jq -r '.id')
    STATUS=$(echo "$RESP" | jq -r '.status')
    print_ok "Committed: $NEG_ID (status: $STATUS)"
    echo "$RESP" | jq '{id, status, asking_price}'
    ;;

  commit-email)
    INSTANCE_ID="${1:?Usage: ./seller.sh commit-email <instance-id> \"info\" path/to/file.eml [\"instructions\"]}"
    INFO="${2:?Usage: ./seller.sh commit-email <instance-id> \"info\" path/to/file.eml [\"instructions\"]}"
    EML_PATH="${3:?Usage: ./seller.sh commit-email <instance-id> \"info\" path/to/file.eml [\"instructions\"]}"
    INSTRUCTIONS="${4:-}"
    JWT=$(require_jwt)
    if [[ ! -f "$EML_PATH" ]]; then
      print_err "File not found: $EML_PATH"
      exit 1
    fi
    CURL_ARGS=(-sf "$TBVH_API/instances/$INSTANCE_ID/negotiate"
      -H "Authorization: Bearer $JWT"
      -F "seller_info=$INFO"
      -F "email_file=@$EML_PATH")
    [[ -n "$INSTRUCTIONS" ]] && CURL_ARGS+=(-F "seller_prompt=$INSTRUCTIONS")
    RESP=$(curl "${CURL_ARGS[@]}")
    NEG_ID=$(echo "$RESP" | jq -r '.id')
    STATUS=$(echo "$RESP" | jq -r '.status')
    DOMAIN=$(echo "$RESP" | jq -r '.email_domain // empty')
    print_ok "Committed: $NEG_ID (status: $STATUS)"
    [[ -n "$DOMAIN" ]] && print_info "DKIM verified from $DOMAIN"
    echo "$RESP" | jq '{id, status, asking_price, email_domain, email_verified}'
    ;;

  status)
    NEG_ID="${1:?Usage: ./seller.sh status <negotiation-id>}"
    # Get negotiation via instance negotiations list (seller view)
    # We need the instance_id, so we check mine first
    MINE=$(tbvh_get "/instances/mine")
    NEG=$(echo "$MINE" | jq --arg id "$NEG_ID" '.as_seller[] | select(.id == $id)')
    if [[ -z "$NEG" || "$NEG" == "null" ]]; then
      print_err "Negotiation not found in your negotiations"
      exit 1
    fi
    echo "$NEG" | jq .
    ;;

  mine)
    RESP=$(tbvh_get "/instances/mine")
    NEGS=$(echo "$RESP" | jq '.as_seller')
    COUNT=$(echo "$NEGS" | jq length)
    print_info "$COUNT negotiations as seller"
    echo "$NEGS" | jq -r '.[] | "  \(.id)  \(.status)  \(.asking_price // "-") USDC  \(.buyer_requirement_title[:60])"'
    ;;

  help|*)
    echo "Usage: ./seller.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list [status]                                     List instances (default: open)"
    echo "  commit <instance-id> \"info\" \"proof\" [\"instr\"]     Commit with text proof"
    echo "  commit-email <instance-id> \"info\" file.eml [\"instr\"]  Commit with email proof"
    echo "  status <negotiation-id>                           Check negotiation status"
    echo "  mine                                              List your negotiations"
    ;;
esac
