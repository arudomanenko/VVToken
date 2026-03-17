#!/usr/bin/env bash

set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

# Exact anvil accounts you posted
ADMIN_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # (0)
VOTER1_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" # (1)
VOTER2_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" # (2)
VOTER3_PK="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" # (3)
VOTER4_PK="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" # (4)

VOTER1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VOTER2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
VOTER3_ADDR="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
VOTER4_ADDR="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"

echo "RPC_URL=$RPC_URL"
echo "Voters (hard-coded from anvil):"
echo "  V1: $VOTER1_ADDR"
echo "  V2: $VOTER2_ADDR"
echo "  V3: $VOTER3_ADDR"
echo "  V4: $VOTER4_ADDR"
echo

echo "=== 1) Deploy contracts (short_locks_vs_long_locks) ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="$(cast --to-wei 10000000 ether)" \
  VOTING_DESCRIPTION="Short locks vs long locks (mixed YES/NO)" \
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" \
    --broadcast \
    -vvv
)"

VV_TOKEN_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/VVToken deployed at:/ {print $NF}' | tail -n1)"
STAKING_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/Staking deployed at:/ {print $NF}' | tail -n1)"
VOTING_RESULT_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/VotingResult deployed at:/ {print $NF}' | tail -n1)"
VOTING_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/Voting deployed at:/ {print $NF}' | tail -n1)"

echo "VVToken:      $VV_TOKEN_ADDR"
echo "Staking:      $STAKING_ADDR"
echo "VotingResult: $VOTING_RESULT_ADDR"
echo "Voting:       $VOTING_ADDR"
echo

echo "Starting watchVoteDebug.js (logging to vote_events_short_locks.log)..."
VOTING_ADDR="$VOTING_ADDR" STAKING_ADDR="$STAKING_ADDR" RPC_URL="$RPC_URL" node ../swatchVoteDebug.js >> vote_events_short_locks.log 2>&1 &
sleep 2
echo

echo "=== 2) Mint VV to voters (same balance) ==="
VOTER_STAKE_AMOUNT_WEI="$(cast --to-wei 1000 ether)"
for ADDR in "$VOTER1_ADDR" "$VOTER2_ADDR" "$VOTER3_ADDR" "$VOTER4_ADDR"; do
  echo "Minting $VOTER_STAKE_AMOUNT_WEI VV to $ADDR"
  cast send "$VV_TOKEN_ADDR" "mint(address,uint256)" "$ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" >/dev/null
done
echo

echo "=== 3) Stakes: V1,V2 short; V3,V4 long ==="
NOW_TS="$(date +%s)"
SHORT_LOCK=$((NOW_TS + 60))      # 1 minute
LONG_LOCK=$((NOW_TS + 60 * 60))  # 1 hour

echo "Short lock until: $SHORT_LOCK"
echo "Long lock until:  $LONG_LOCK"
echo

echo "Voter1 short lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$SHORT_LOCK" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 short lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$SHORT_LOCK" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 long lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$LONG_LOCK" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null

echo "Voter4 long lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER4_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$LONG_LOCK" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER4_PK" >/dev/null
echo

echo "=== 4) Voting: short locks vote NO, long locks vote YES ==="
echo "Voter1 votes NO"
cast send "$VOTING_ADDR" "vote(bool)" false \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 votes NO"
cast send "$VOTING_ADDR" "vote(bool)" false \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 votes YES"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null

echo "Voter4 votes YES"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER4_PK" >/dev/null
echo

echo "=== 5) Finalize and read NFT ==="
cast send "$VOTING_ADDR" "finalize()" \
  --rpc-url "$RPC_URL" \
  --private-key "$ADMIN_PK" >/dev/null

RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 \
  --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $RESULT"
echo

echo "Done: short_locks_vs_long_locks."

