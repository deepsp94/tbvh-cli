# tbvh-cli

Command-line client for [TBVH](https://github.com/deepsp94/tbvh), a trustless marketplace for buying and selling information. Uses `curl` for API calls and `cast` (Foundry) for on-chain operations.

## Prerequisites

- `bash` (4+)
- `curl`
- `jq` — [install](https://jqlang.github.io/jq/download/)
- `cast` — part of [Foundry](https://book.getfoundry.sh/getting-started/installation)
- A wallet with Base Sepolia ETH (for gas)

## Quick start

```bash
git clone https://github.com/deepsp94/tbvh-cli.git
cd tbvh-cli
cp .env.example .env
# Edit .env: add your PRIVATE_KEY and RPC_URL

# Authenticate
./auth.sh

# Browse open instances
./buyer.sh list

# Create an instance (as buyer)
./buyer.sh create "Snowflake pricing" "Looking for verified per-credit pricing for Snowflake Enterprise tier" 50
```

## Scripts

### auth.sh

Authenticates with TBVH using Sign-In with Ethereum (SIWE). Signs a message with your private key and saves the JWT (valid 24h) to `.tbvh_jwt`.

```bash
./auth.sh
```

### buyer.sh

Buyer operations — create requests, review negotiations, accept deals.

```bash
./buyer.sh create "title" "requirement" 50  # Create instance with 50 USDC budget
./buyer.sh list                          # List open instances
./buyer.sh list closed                   # List closed instances
./buyer.sh show <instance-id>            # Show instance + negotiations
./buyer.sh accept <negotiation-id>       # Accept a proposed deal (deposit first)
./buyer.sh cancel <negotiation-id>       # Cancel a negotiation
./buyer.sh close <instance-id>           # Close instance (no new sellers)
./buyer.sh delete <instance-id>          # Delete instance + all data
```

### seller.sh

Seller operations — browse the marketplace, commit information, check status.

```bash
./seller.sh list                         # Browse open instances
./seller.sh commit <id> "info" "proof"   # Commit with text proof
./seller.sh commit <id> "info" "proof" "sell for $10"  # With custom instructions
./seller.sh commit-email <id> "info" file.eml          # Commit with DKIM email proof
./seller.sh status <negotiation-id>      # Check negotiation status
./seller.sh mine                         # List your negotiations
```

### escrow.sh

On-chain escrow operations — deposit before accepting, claim after deal.

```bash
./escrow.sh info                         # Show contract addresses + TEE signer
./escrow.sh mint                         # Mint 1000 test USDC
./escrow.sh mint 500                     # Mint 500 test USDC
./escrow.sh balance                      # Check USDC balance
./escrow.sh approve 50                   # Approve escrow to spend 50 USDC
./escrow.sh deposit <neg-id> 50          # Deposit 50 USDC for a negotiation
./escrow.sh release <neg-id>             # Seller claims payment
./escrow.sh refund <neg-id>              # Buyer refund (after 7-day timeout)
```

### stream.sh

Watch negotiation events in real-time via SSE.

```bash
./stream.sh buyer <instance-id>          # All negotiations (buyer view)
./stream.sh seller <negotiation-id>      # Single negotiation (seller view)
```

## Full example

See `examples/full-flow.sh` for an annotated walkthrough of a complete buy/sell cycle.

The typical flow:

1. **Buyer** authenticates and creates an instance
2. **Seller** authenticates (different wallet), browses instances, commits information
3. AI agents negotiate automatically — watch with `stream.sh`
4. If agents agree: **buyer** deposits escrow, then accepts
5. **Seller** claims payment via escrow release

## How TBVH works

A buyer posts a request for information with a budget. Sellers commit their information. AI agents negotiate inside a TEE (Trusted Execution Environment) — neither human sees the conversation. If the agents agree on a price, the buyer deposits into an on-chain escrow, and the TEE reveals the seller's information only after payment. The escrow contract only accepts TEE-signed outcomes.

For more details, see the [TBVH repo](https://github.com/deepsp94/tbvh).
