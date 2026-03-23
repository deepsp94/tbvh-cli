#!/usr/bin/env bash
# Escrow operations: info, mint, balance, approve, deposit, release, refund
source "$(dirname "$0")/lib/common.sh"

CMD="${1:-help}"
shift || true

ADDRESS=$(get_address)

case "$CMD" in
  info)
    INFO=$(get_tee_info)
    echo -e "${BOLD}TEE Info${NC}"
    echo "$INFO" | jq '{signerAddress, contractAddress, tokenAddress, chainId, enabled}'
    ;;

  mint)
    AMOUNT="${1:-1000}"
    USDC=$(get_usdc_address)
    WEI=$(echo "$AMOUNT * 1000000" | bc | cut -d. -f1)
    print_info "Minting $AMOUNT USDC to $ADDRESS"
    cast send "$USDC" "mint(address,uint256)" "$ADDRESS" "$WEI" \
      --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --quiet
    print_ok "Minted $AMOUNT USDC"
    ;;

  balance)
    USDC=$(get_usdc_address)
    RAW=$(cast call "$USDC" "balanceOf(address)(uint256)" "$ADDRESS" --rpc-url "$RPC_URL" | awk '{print $1}')
    BALANCE=$(echo "scale=6; $RAW / 1000000" | bc)
    echo -e "${BOLD}$BALANCE${NC} USDC"
    ;;

  approve)
    AMOUNT="${1:?Usage: ./escrow.sh approve <amount>}"
    USDC=$(get_usdc_address)
    ESCROW=$(get_escrow_address)
    WEI=$(echo "$AMOUNT * 1000000" | bc | cut -d. -f1)
    print_info "Approving $AMOUNT USDC for escrow"
    cast send "$USDC" "approve(address,uint256)" "$ESCROW" "$WEI" \
      --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --quiet
    print_ok "Approved"
    ;;

  deposit)
    NEG_ID="${1:?Usage: ./escrow.sh deposit <negotiation-id> <amount>}"
    AMOUNT="${2:?Usage: ./escrow.sh deposit <negotiation-id> <amount>}"
    ESCROW=$(get_escrow_address)
    BYTES32=$(neg_id_to_bytes32 "$NEG_ID")
    WEI=$(echo "$AMOUNT * 1000000" | bc | cut -d. -f1)
    print_info "Depositing $AMOUNT USDC for negotiation $NEG_ID"
    cast send "$ESCROW" "deposit(bytes32,uint256)" "$BYTES32" "$WEI" \
      --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --quiet
    print_ok "Deposited"
    ;;

  release)
    NEG_ID="${1:?Usage: ./escrow.sh release <negotiation-id>}"
    ESCROW=$(get_escrow_address)
    BYTES32=$(neg_id_to_bytes32 "$NEG_ID")
    # Fetch TEE verification data
    print_info "Fetching TEE signature..."
    VERIFY=$(curl -sf "$TBVH_API/tee/verify/$NEG_ID")
    SELLER=$(echo "$VERIFY" | jq -r '.seller')
    OUTCOME=$(echo "$VERIFY" | jq -r '.outcome')
    FINAL_PRICE=$(echo "$VERIFY" | jq -r '.finalPrice')
    TIMESTAMP=$(echo "$VERIFY" | jq -r '.timestamp')
    SIGNATURE=$(echo "$VERIFY" | jq -r '.signature')
    print_info "Releasing payment to $SELLER"
    cast send "$ESCROW" \
      "release(bytes32,address,string,uint256,uint256,bytes)" \
      "$BYTES32" "$SELLER" "$OUTCOME" "$FINAL_PRICE" "$TIMESTAMP" "$SIGNATURE" \
      --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --quiet
    print_ok "Payment released"
    ;;

  refund)
    NEG_ID="${1:?Usage: ./escrow.sh refund <negotiation-id>}"
    ESCROW=$(get_escrow_address)
    BYTES32=$(neg_id_to_bytes32 "$NEG_ID")
    print_info "Refunding escrow for $NEG_ID (7-day timeout)"
    cast send "$ESCROW" "refund(bytes32)" "$BYTES32" \
      --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --quiet
    print_ok "Refunded"
    ;;

  help|*)
    echo "Usage: ./escrow.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  info                                Show contract addresses and TEE signer"
    echo "  mint [amount]                       Mint test USDC (default: 1000)"
    echo "  balance                             Show USDC balance"
    echo "  approve <amount>                    Approve escrow to spend USDC"
    echo "  deposit <negotiation-id> <amount>   Deposit into escrow"
    echo "  release <negotiation-id>            Seller claims payment (fetches TEE sig)"
    echo "  refund <negotiation-id>             Buyer timeout refund (after 7 days)"
    ;;
esac
