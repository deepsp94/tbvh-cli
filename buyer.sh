#!/usr/bin/env bash
# Buyer operations: create, list, show, accept, cancel, close, delete
source "$(dirname "$0")/lib/common.sh"

CMD="${1:-help}"
shift || true

case "$CMD" in
  create)
    REQUIREMENT="${1:?Usage: ./buyer.sh create \"requirement\" max_payment}"
    MAX_PAYMENT="${2:?Usage: ./buyer.sh create \"requirement\" max_payment}"
    RESP=$(tbvh_post "/instances" "$(jq -n \
      --arg req "$REQUIREMENT" \
      --argjson max "$MAX_PAYMENT" \
      '{buyer_requirement: $req, max_payment: $max}')")
    ID=$(echo "$RESP" | jq -r '.id')
    print_ok "Instance created: $ID"
    echo "$RESP" | jq .
    ;;

  list)
    STATUS="${1:-open}"
    RESP=$(tbvh_get "/instances?status=$STATUS")
    COUNT=$(echo "$RESP" | jq length)
    print_info "$COUNT instances ($STATUS)"
    echo "$RESP" | jq -r '.[] | "  \(.id)  \(.max_payment) USDC  \(.buyer_requirement[:80])"'
    ;;

  show)
    INSTANCE_ID="${1:?Usage: ./buyer.sh show <instance-id>}"
    echo -e "${BOLD}Instance${NC}"
    tbvh_get "/instances/$INSTANCE_ID" | jq .
    echo ""
    echo -e "${BOLD}Negotiations${NC}"
    tbvh_get "/instances/$INSTANCE_ID/negotiations" | jq .
    ;;

  accept)
    NEG_ID="${1:?Usage: ./buyer.sh accept <negotiation-id>}"
    RESP=$(tbvh_post "/negotiations/$NEG_ID/accept")
    STATUS=$(echo "$RESP" | jq -r '.status')
    if [[ "$STATUS" == "accepted" ]]; then
      print_ok "Negotiation accepted!"
      SELLER_INFO=$(echo "$RESP" | jq -r '.seller_info // empty')
      if [[ -n "$SELLER_INFO" ]]; then
        echo ""
        echo -e "${BOLD}Seller Information:${NC}"
        echo "$SELLER_INFO"
      fi
    else
      print_err "Accept failed"
      echo "$RESP" | jq .
    fi
    ;;

  cancel)
    NEG_ID="${1:?Usage: ./buyer.sh cancel <negotiation-id>}"
    RESP=$(tbvh_post "/negotiations/$NEG_ID/cancel")
    print_ok "Negotiation cancelled"
    echo "$RESP" | jq '{id, status}'
    ;;

  close)
    INSTANCE_ID="${1:?Usage: ./buyer.sh close <instance-id>}"
    RESP=$(tbvh_post "/instances/$INSTANCE_ID/close")
    print_ok "Instance closed"
    echo "$RESP" | jq '{id, status}'
    ;;

  delete)
    INSTANCE_ID="${1:?Usage: ./buyer.sh delete <instance-id>}"
    tbvh_delete "/instances/$INSTANCE_ID"
    print_ok "Instance deleted"
    ;;

  help|*)
    echo "Usage: ./buyer.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create <requirement> <max_payment>  Create a new instance"
    echo "  list [status]                       List instances (default: open)"
    echo "  show <instance-id>                  Show instance + negotiations"
    echo "  accept <negotiation-id>             Accept a proposed negotiation"
    echo "  cancel <negotiation-id>             Cancel a negotiation"
    echo "  close <instance-id>                 Close instance (no new sellers)"
    echo "  delete <instance-id>                Delete instance + all data"
    ;;
esac
