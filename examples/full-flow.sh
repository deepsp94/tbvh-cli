#!/usr/bin/env bash
# Full end-to-end TBVH flow using the CLI
#
# This script walks through a complete buy/sell cycle:
# 1. Buyer creates an instance
# 2. Seller commits information
# 3. Agents negotiate automatically
# 4. Buyer deposits escrow and accepts
# 5. Seller claims payment
#
# Prerequisites:
# - Two .env files: .env (buyer) and .env.seller (seller, different PRIVATE_KEY)
# - Both wallets funded with Base Sepolia ETH
# - Run ./auth.sh for both wallets first
#
# Usage: ./examples/full-flow.sh

set -euo pipefail
CLI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CLI_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

step() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}\n"; }
pause() { echo -e "${DIM}Press Enter to continue...${NC}"; read -r; }

# ============================================
step "Step 1: Authenticate as buyer"
# ============================================
echo "Make sure .env has the BUYER's private key, then run:"
echo "  ./auth.sh"
pause

# ============================================
step "Step 2: Create an instance"
# ============================================
echo "Creating a request for information..."
INSTANCE=$(./buyer.sh create "Looking for the WiFi password for the office on 5th floor" 20)
INSTANCE_ID=$(echo "$INSTANCE" | grep -oP '[0-9a-f-]{36}' | head -1)
echo "Instance ID: $INSTANCE_ID"
pause

# ============================================
step "Step 3: Switch to seller"
# ============================================
echo "Now switch .env to the SELLER's private key and run:"
echo "  ./auth.sh"
echo ""
echo "Then commit as seller:"
echo "  ./seller.sh commit $INSTANCE_ID \"The WiFi password is hunter2\" \"I work on the 5th floor and connect daily\""
echo ""
echo "Or with email proof:"
echo "  ./seller.sh commit-email $INSTANCE_ID \"The WiFi password is hunter2\" path/to/wifi-email.eml"
pause

# ============================================
step "Step 4: Watch the negotiation"
# ============================================
echo "As the seller, watch your negotiation:"
echo "  ./seller.sh mine"
echo "  # Get the negotiation ID, then:"
echo "  ./stream.sh seller <negotiation-id>"
echo ""
echo "As the buyer (switch .env back), watch all negotiations:"
echo "  ./stream.sh buyer $INSTANCE_ID"
echo ""
echo "Wait for the negotiation to reach 'proposed' status."
pause

# ============================================
step "Step 5: Deposit escrow (as buyer)"
# ============================================
echo "Switch .env back to the BUYER's private key."
echo "Check the proposed price, then deposit:"
echo "  ./escrow.sh mint              # Get test USDC"
echo "  ./escrow.sh balance           # Check balance"
echo "  ./escrow.sh approve 20        # Approve escrow"
echo "  ./escrow.sh deposit <negotiation-id> 20"
pause

# ============================================
step "Step 6: Accept (as buyer)"
# ============================================
echo "Accept the negotiation:"
echo "  ./buyer.sh accept <negotiation-id>"
echo ""
echo "This will reveal the seller's information!"
pause

# ============================================
step "Step 7: Claim payment (as seller)"
# ============================================
echo "Switch .env to the SELLER's private key."
echo "  ./escrow.sh release <negotiation-id>"
echo ""
echo "Done! The seller receives USDC, the buyer has the information."

echo -e "\n${GREEN}${BOLD}Flow complete.${NC}"
