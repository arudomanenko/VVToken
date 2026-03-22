#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

ADMIN_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
VOTER1_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
VOTER2_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

VOTER1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VOTER2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

echo "RPC_URL=$RPC_URL"
echo "Voters: $VOTER1_ADDR (stake will expire), $VOTER2_ADDR (active)"
echo

for cmd in forge cast node; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found"; exit 1; }
done

echo "=== 1) Deploy contracts ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

# Voting deadline is 14 days out; voter1 only stakes for 1 week
DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="1000000000000000000000000000000000000" \
  VOTING_DEADLINE_OFFSET="$((14 * 86400))" \
  VOTING_DESCRIPTION="One stake expires before voting" \
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

LOG_FILE="test_scenations/scenario_stake_expires_before_vote_events.txt"
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

echo "=== 2) Mint VV to both voters ==="
VOTER_STAKE_AMOUNT_WEI="$(cast --to-wei 1000 ether)"
for ADDR in "$VOTER1_ADDR" "$VOTER2_ADDR"; do
  echo "Minting to $ADDR"
  cast send "$VV_TOKEN_ADDR" "mint(address,uint256)" "$ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
    --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" >/dev/null
done
echo

echo "=== 3) Stakes: V1 = 1 week (expires before vote), V2 = 2 weeks ==="
NOW_TS="$(cast block latest --rpc-url "$RPC_URL" --field timestamp)"
V1_END=$(( NOW_TS + 604800 + 3600 ))    # 1 week + 1h buffer (avoids sub-MIN on stake tx)
V2_END=$(( NOW_TS + 1209600 ))          # 2 weeks

echo "Voter1 stake ends: $V1_END (1w)"
echo "Voter2 stake ends: $V2_END (2w)"
echo

echo "Voter1 stake (1w)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$V1_END" \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 stake (2w)"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$V2_END" \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null
echo

echo "=== 4) Fast-forward Anvil past Voter1 stake expiry (1w+1s) ==="
cast rpc anvil_setNextBlockTimestamp "$(( V1_END + 1 ))" --rpc-url "$RPC_URL" >/dev/null
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null
echo "Block timestamp is now past Voter1 expiry."
echo

echo "=== 5) Voting ==="
echo "Voter1 tries to vote YES (stake expired → expected to revert with 'No active voting power')"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER1_PK" 2>&1 | grep -E 'revert|error|No active' || true

echo "Voter2 votes YES (stake still active)"
cast send "$VOTING_ADDR" "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null
echo

echo "=== 6) Admin finalizes after voting deadline ==="
DEADLINE="$(cast call "$VOTING_ADDR" \
  "getVoteInfo(bytes32)(tuple(bytes32,uint256,uint256,string,uint256,uint256,bool))" \
  "$VOTE_ID" --rpc-url "$RPC_URL" | awk 'NR==1{print $2}' | tr -d ',')"
cast rpc anvil_setNextBlockTimestamp "$(( DEADLINE + 1 ))" --rpc-url "$RPC_URL" >/dev/null
cast rpc anvil_mine 1 --rpc-url "$RPC_URL" >/dev/null

cast send "$VOTING_ADDR" "finalize(bytes32)" "$VOTE_ID" \
  --rpc-url "$RPC_URL" --private-key "$ADMIN_PK" >/dev/null

RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $RESULT  (only Voter2 contributed — expected: Yes)"
echo

echo "=== 7) Voter2 unstakes ==="
cast send "$STAKING_ADDR" "unstake(uint256)" 0 \
  --rpc-url "$RPC_URL" --private-key "$VOTER2_PK" >/dev/null

echo
echo "Done: stake_expires_before_vote."
