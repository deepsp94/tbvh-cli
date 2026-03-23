#!/usr/bin/env bash
# Watch negotiation events via SSE
source "$(dirname "$0")/lib/common.sh"

CMD="${1:-help}"
shift || true

JWT=$(require_jwt)

case "$CMD" in
  buyer)
    INSTANCE_ID="${1:?Usage: ./stream.sh buyer <instance-id>}"
    print_info "Streaming events for instance $INSTANCE_ID (buyer view)"
    print_dim "Press Ctrl+C to stop"
    echo ""
    curl -Ns "$TBVH_API/instances/$INSTANCE_ID/stream?token=$JWT" | while read -r line; do
      # SSE format: "data: {...}" or ": heartbeat"
      if [[ "$line" == data:* ]]; then
        DATA="${line#data: }"
        TYPE=$(echo "$DATA" | jq -r '.type // empty')
        NEG=$(echo "$DATA" | jq -r '.negotiation_id // empty' | head -c 8)
        TURN=$(echo "$DATA" | jq -r '.turn // empty')
        case "$TYPE" in
          turn_start)    echo -e "${CYAN}[$NEG]${NC} Turn $TURN starting" ;;
          seller_response) echo -e "${YELLOW}[$NEG]${NC} Seller responded (turn $TURN)" ;;
          buyer_response)  echo -e "${GREEN}[$NEG]${NC} Buyer responded (turn $TURN)" ;;
          proposed)
            PRICE=$(echo "$DATA" | jq -r '.asking_price // empty')
            echo -e "${GREEN}${BOLD}[$NEG] PROPOSED at $PRICE USDC${NC}" ;;
          rejected)      echo -e "${RED}[$NEG] REJECTED${NC}" ;;
          error)
            ERR=$(echo "$DATA" | jq -r '.error // empty')
            echo -e "${RED}[$NEG] ERROR: $ERR${NC}" ;;
        esac
      fi
    done
    ;;

  seller)
    NEG_ID="${1:?Usage: ./stream.sh seller <negotiation-id>}"
    print_info "Streaming events for negotiation $NEG_ID (seller view)"
    print_dim "Press Ctrl+C to stop"
    echo ""
    curl -Ns "$TBVH_API/negotiations/$NEG_ID/stream?token=$JWT" | while read -r line; do
      if [[ "$line" == data:* ]]; then
        DATA="${line#data: }"
        TYPE=$(echo "$DATA" | jq -r '.type // empty')
        TURN=$(echo "$DATA" | jq -r '.turn // empty')
        case "$TYPE" in
          turn_start)    echo -e "${CYAN}Turn $TURN starting${NC}" ;;
          seller_response) echo -e "${YELLOW}Seller responded (turn $TURN)${NC}" ;;
          buyer_response)  echo -e "${GREEN}Buyer responded (turn $TURN)${NC}" ;;
          proposed)
            PRICE=$(echo "$DATA" | jq -r '.asking_price // empty')
            echo -e "${GREEN}${BOLD}PROPOSED at $PRICE USDC${NC}" ;;
          rejected)      echo -e "${RED}REJECTED${NC}" ;;
          error)
            ERR=$(echo "$DATA" | jq -r '.error // empty')
            echo -e "${RED}ERROR: $ERR${NC}" ;;
        esac
      fi
    done
    ;;

  help|*)
    echo "Usage: ./stream.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  buyer <instance-id>       Stream all negotiation events (buyer view)"
    echo "  seller <negotiation-id>   Stream single negotiation events (seller view)"
    ;;
esac
