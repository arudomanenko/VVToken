#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

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

for cmd in forge cast jq node; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found"; exit 1; }
done

echo "=== 1) Deploy contracts via Deploy.s.sol ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="1000000000000000000000000000000000000" \
  VOTING_DESCRIPTION="Quadratic time-weighted voting test" \
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" \
    --broadcast \
    -vvv 2>&1
)"

VV_TOKEN_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/VVToken deployed at:/ {print $NF}' | tail -n1)"
STAKING_ADDR="$(echo "$DEPLOY_OUTPUT"  | awk '/Staking deployed at:/ {print $NF}' | tail -n1)"
VOTING_RESULT_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/VotingResult deployed at:/ {print $NF}' | tail -n1)"
VOTING_ADDR="$(echo "$DEPLOY_OUTPUT"   | awk '/Voting deployed at:/ {print $NF}' | tail -n1)"
echo "VVToken deployed at:      $VV_TOKEN_ADDR"
echo "Staking deployed at:      $STAKING_ADDR"
echo "VotingResult deployed at: $VOTING_RESULT_ADDR"
echo "Voting deployed at:       $VOTING_ADDR"
echo

VOTE_ID="$(cast call "$VOTING_ADDR" "getAllVoteIds()(bytes32[])" --rpc-url "$RPC_URL" | tr -d '[] ' | awk -F',' '{print $1}')"
echo "Initial voteId (from chain): $VOTE_ID"
echo

LOG_FILE="test_scenations/scenario_average_events.txt"
: > "$LOG_FILE"
WATCHER_PID=""
stop_watcher() {
  sleep 1
  [ -n "$WATCHER_PID" ] && { kill "$WATCHER_PID" 2>/dev/null || true; wait "$WATCHER_PID" 2>/dev/null || true; }
  echo "Event log saved to $LOG_FILE"
}
trap stop_watcher EXIT
RPC_URL="$RPC_URL" VOTING_ADDR="$VOTING_ADDR" STAKING_ADDR="$STAKING_ADDR" \
  node test_scenations/watchVoteDebug.js >> "$LOG_FILE" 2>&1 &
WATCHER_PID=$!
echo "Event watcher started (pid $WATCHER_PID) → $LOG_FILE"
sleep 1
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

echo "=== 3) Voters approve and stake with different durations ==="
NOW_TS="$(cast block latest --rpc-url "$RPC_URL" --field timestamp)"
EXPIRY_V1=$(( NOW_TS + 604800 + 3600 ))   # 1 week + 1h buffer (avoids sub-MIN on stake tx)
EXPIRY_V2=$(( NOW_TS + 1209600 ))         # 2 weeks
EXPIRY_V3=$(( NOW_TS + 2419200 - 60 ))   # 4 weeks (just under MAX)

echo "Voter1 expiry (1w):  $EXPIRY_V1"
echo "Voter2 expiry (2w):  $EXPIRY_V2"
echo "Voter3 expiry (4w):  $EXPIRY_V3"
echo

echo "Voter1 approve + stake (1w)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V1" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 approve + stake (2w)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V2" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 approve + stake (4w)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$EXPIRY_V3" \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null
echo

echo "=== 4) Voters cast votes on voteId=$VOTE_ID ==="
echo "Voter1 (1w lock) votes YES"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 (2w lock) votes NO"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" false \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 (4w lock) votes YES"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null
echo

echo "=== 5) Admin creates a second vote (multi-vote demo) ==="
DEADLINE2=$(( $(cast block latest --rpc-url "$RPC_URL" --field timestamp) + 86400 ))
VOTE_ID2="$(cast send "$VOTING_ADDR" \
  "createVote(uint256,uint256,string)(bytes32)" \
  "$DEADLINE2" "$(cast --to-wei 10000000 ether)" "Second proposal" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" \
  --json | jq -r '.logs[0].topics[1] // empty')"

ALL_IDS="$(cast call "$VOTING_ADDR" "getAllVoteIds()(bytes32[])" --rpc-url "$RPC_URL")"
echo "All vote IDs: $ALL_IDS"
echo

echo "=== 6) Admin finalizes the first vote ==="

DEADLINE1="$(cast call "$VOTING_ADDR" "getVoteInfo(bytes32)(tuple(bytes32,uint256,uint256,string,uint256,uint256,bool))" \
  "$VOTE_ID" --rpc-url "$RPC_URL" | awk 'NR==1{print $2}' | tr -d ',')"
cast rpc anvil_setNextBlockTimestamp "$(( DEADLINE1 + 1 ))" --rpc-url "$RPC_URL" >/dev/null
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null

cast send "$VOTING_ADDR" "finalize(bytes32)" "$VOTE_ID" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" >/dev/null

echo "Fetching VotingResult NFT outcome (tokenId 0)..."
VOTE_NFT_RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $VOTE_NFT_RESULT"
echo

INFO_RAW="$(cast call "$VOTING_ADDR" \
  "getVoteInfo(bytes32)(tuple(bytes32,uint256,uint256,string,uint256,uint256,bool))" \
  "$VOTE_ID" --rpc-url "$RPC_URL")"
echo "VotingInfo (id,deadline,threshold,description,yesVotes,noVotes,isOver):"
echo "$INFO_RAW"
echo

echo "=== 7) Voters unstake ==="
for PK in "$VOTER1_PK" "$VOTER2_PK" "$VOTER3_PK"; do
  cast send "$STAKING_ADDR" "unstake(uint256)" 0 \
    --rpc-url "$RPC_URL" --private-key "$PK" >/dev/null
done

echo
echo "Scenario complete: average."
