#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

ADMIN_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
VOTER1_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
VOTER2_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
VOTER3_PK="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
VOTER4_PK="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"

VOTER1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VOTER2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
VOTER3_ADDR="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
VOTER4_ADDR="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"

echo "RPC_URL=$RPC_URL"
echo "Voters:  V1=$VOTER1_ADDR  V2=$VOTER2_ADDR  V3=$VOTER3_ADDR  V4=$VOTER4_ADDR"
echo

for cmd in forge cast jq node; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found"; exit 1; }
done

echo "=== 1) Deploy contracts ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="1000000000000000000000000000000000000" \
  VOTING_DESCRIPTION="Short locks vs long locks (mixed YES/NO)" \
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" \
    --broadcast \
    -vvv 2>&1
)"

VV_TOKEN_ADDR="$(echo "$DEPLOY_OUTPUT"      | awk '/VVToken deployed at:/ {print $NF}' | tail -n1)"
STAKING_ADDR="$(echo "$DEPLOY_OUTPUT"       | awk '/Staking deployed at:/ {print $NF}' | tail -n1)"
VOTING_RESULT_ADDR="$(echo "$DEPLOY_OUTPUT" | awk '/VotingResult deployed at:/ {print $NF}' | tail -n1)"
VOTING_ADDR="$(echo "$DEPLOY_OUTPUT"        | awk '/Voting deployed at:/ {print $NF}' | tail -n1)"
echo "VVToken:      $VV_TOKEN_ADDR"
echo "Staking:      $STAKING_ADDR"
echo "VotingResult: $VOTING_RESULT_ADDR"
echo "Voting:       $VOTING_ADDR"
echo

VOTE_ID="$(cast call "$VOTING_ADDR" "getAllVoteIds()(bytes32[])" --rpc-url "$RPC_URL" | tr -d '[] ' | awk -F',' '{print $1}')"
echo "voteId (from chain): $VOTE_ID"
echo

LOG_FILE="test_scenations/scenario_short_locks_vs_long_locks_events.txt"
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

echo "=== 2) Mint VV tokens to voters ==="
VOTER_STAKE_AMOUNT_WEI="$(cast --to-wei 1000 ether)"
for ADDR in "$VOTER1_ADDR" "$VOTER2_ADDR" "$VOTER3_ADDR" "$VOTER4_ADDR"; do
  echo "Minting to $ADDR"
  cast send "$VV_TOKEN_ADDR" "mint(address,uint256)" "$ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
    --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" >/dev/null
done
echo

echo "=== 3) Stakes: V1+V2 short (1w), V3+V4 long (4w) ==="
NOW_TS="$(cast block latest --rpc-url "$RPC_URL" --field timestamp)"
SHORT_LOCK=$(( NOW_TS + 604800 + 3600 ))   # 1 week + 1h buffer (avoids sub-MIN on stake tx)
LONG_LOCK=$(( NOW_TS + 2419200 - 60 ))    # 4 weeks (just under MAX)
echo "Short lock: $SHORT_LOCK  |  Long lock: $LONG_LOCK"
echo

echo "Voter1 short lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$SHORT_LOCK" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 short lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$SHORT_LOCK" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 long lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$LONG_LOCK" \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null

echo "Voter4 long lock"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER4_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$LONG_LOCK" \
  --rpc-url "$RPC_URL" --private-key "$VOTER4_PK" >/dev/null
echo

echo "=== 4) Voting: short locks → NO, long locks → YES ==="
echo "Voter1 votes NO (short lock)"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" false \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 votes NO (short lock)"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" false \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null

echo "Voter3 votes YES (long lock)"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER3_PK" >/dev/null

echo "Voter4 votes YES (long lock)"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER4_PK" >/dev/null
echo

echo "=== 5) Admin finalizes after deadline ==="
DEADLINE="$(cast call "$VOTING_ADDR" \
  "getVoteInfo(bytes32)(tuple(bytes32,uint256,uint256,string,uint256,uint256,bool))" \
  "$VOTE_ID" --rpc-url "$RPC_URL" | awk 'NR==1{print $2}' | tr -d ',')"
cast rpc anvil_setNextBlockTimestamp "$(( DEADLINE + 1 ))" --rpc-url "$RPC_URL" >/dev/null
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null

cast send "$VOTING_ADDR" "finalize(bytes32)" "$VOTE_ID" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" >/dev/null

RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $RESULT  (expected: Yes — long locks outweigh short locks)"
echo

echo "Done: short_locks_vs_long_locks."
