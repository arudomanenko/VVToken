#!/usr/bin/env bash

set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

ADMIN_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" 
VOTER1_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
VOTER2_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
VOTER3_PK="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

ADMIN_ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
VOTER1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VOTER2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
VOTER3_ADDR="0x90F79bf6EB2c4f870365E785982E1f101E93b906"

echo "Using RPC_URL=$RPC_URL"
echo "Admin:  $ADMIN_ADDR"
echo "Voter1: $VOTER1_ADDR"
echo "Voter2: $VOTER2_ADDR"
echo "Voter3: $VOTER3_ADDR"
echo

if ! command -v forge >/dev/null 2>&1; then
  echo "forge not found (install Foundry)."
  exit 1
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "cast not found (install Foundry)."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found (install jq)."
  exit 1
fi

echo "=== 1) Deploy contracts via Deploy.s.sol ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="$(cast --to-wei 10000000 ether)" \
  VOTING_DESCRIPTION="Quadratic time-weighted voting test" \
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

echo "VVToken deployed at:      $VV_TOKEN_ADDR"
echo "Staking deployed at:      $STAKING_ADDR"
echo "VotingResult deployed at: $VOTING_RESULT_ADDR"
echo "Voting deployed at:       $VOTING_ADDR"
echo

echo "Starting watchVoteDebug.js (logging to vote_events.log)..."
VOTING_ADDR="$VOTING_ADDR" STAKING_ADDR="$STAKING_ADDR" RPC_URL="$RPC_URL" node ../watchVoteDebug.js >> vote_events.log 2>&1 &
sleep 2
echo

echo "=== 2) Distribute VV tokens to voters ==="
VOTER_STAKE_AMOUNT_WEI="$(cast --to-wei 1000 ether)"

for ADDR in "$VOTER1_ADDR" "$VOTER2_ADDR" "$VOTER3_ADDR"; do
  echo "Minting $VOTER_STAKE_AMOUNT_WEI VV to $ADDR"
  cast send "$VV_TOKEN_ADDR" "mint(address,uint256)" "$ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" >/dev/null
done
echo

echo "=== 3) Voters approve and stake with different durations (Di in [1,4]) ==="
NOW_TS="$(date +%s)"
UNIT_SECONDS=$((1))

EXPIRY_V1=$((NOW_TS + 1 * UNIT_SECONDS))
EXPIRY_V2=$((NOW_TS + 2 * UNIT_SECONDS))
EXPIRY_V3=$((NOW_TS + 4 * UNIT_SECONDS))

echo "Base duration (UNIT_SECONDS): $UNIT_SECONDS"
echo "Voter1 expiry (D=1): $EXPIRY_V1"
echo "Voter2 expiry (D=2): $EXPIRY_V2"
echo "Voter3 expiry (D=4): $EXPIRY_V3"
echo

echo "Voter1 approve + stake (D=1)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V1" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 approve + stake (D=2)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V2" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 approve + stake (D=4)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V3" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null
echo

echo "=== 4) Voters cast their votes (quadratic time-weighted power) ==="
echo "Voter1 (shortest lock, D=1) votes YES"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 (medium lock, D=2) votes YES"
cast send "$VOTING_ADDR" "vote(bool)" false \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 (longest lock, D=4) votes NO"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null
echo

echo "=== 5) Admin finalizes the vote ==="
cast send "$VOTING_ADDR" "finalize()" \
  --rpc-url "$RPC_URL" \
  --private-key "$ADMIN_PK" >/dev/null

echo "Fetching VotingResult NFT outcome (tokenId 0)..."
VOTE_NFT_RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 \
  --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $VOTE_NFT_RESULT"
echo

INFO_RAW="$(cast call "$VOTING_ADDR" \
  "getCurrentVoteInfo()(tuple(bytes32,uint256,uint256,string,uint256,uint256,bool))" \
  --rpc-url "$RPC_URL")"

echo "Voting finalized."
echo "Raw VotingInfo (id,deadline,threshold,description,yesVotes,noVotes,isOver):"
echo "$INFO_RAW"

echo
echo "=== 6) Users unstake after successful vote ==="
echo "Voter3 unstakes stake index 0"
cast send "$STAKING_ADDR" "unstake(uint256)" 0 \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER3_PK" >/dev/null

echo "Voter2 unstakes stake index 0"
cast send "$STAKING_ADDR" "unstake(uint256)" 0 \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null

echo "Voter1 unstakes stake index 0"
cast send "$STAKING_ADDR" "unstake(uint256)" 0 \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo
echo "Scenario complete."

