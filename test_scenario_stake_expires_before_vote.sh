#!/usr/bin/env bash

set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

ADMIN_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
VOTER1_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
VOTER2_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

VOTER1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
VOTER2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

echo "RPC_URL=$RPC_URL"
echo "Voters: $VOTER1_ADDR (stake expires), $VOTER2_ADDR (active)"
echo

echo "=== 1) Deploy contracts (stake_expires_before_vote) ==="
INITIAL_SUPPLY_WEI="$(cast --to-wei 1000000 ether)"

DEPLOY_OUTPUT="$(
  INITIAL_SUPPLY="$INITIAL_SUPPLY_WEI" \
  VOTING_POWER_THRESHOLD="$(cast --to-wei 10000000 ether)" \
  VOTING_DESCRIPTION="One stake expires before voting" \
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

echo "Starting watchVoteDebug.js (logging to vote_events_stake_expires.log)..."
VOTING_ADDR="$VOTING_ADDR" STAKING_ADDR="$STAKING_ADDR" RPC_URL="$RPC_URL" node watchVoteDebug.js >> vote_events_stake_expires.log 2>&1 &
sleep 2
echo

echo "=== 2) Mint VV to both voters ==="
VOTER_STAKE_AMOUNT_WEI="$(cast --to-wei 1000 ether)"
for ADDR in "$VOTER1_ADDR" "$VOTER2_ADDR"; do
  echo "Minting $VOTER_STAKE_AMOUNT_WEI VV to $ADDR"
  cast send "$VV_TOKEN_ADDR" "mint(address,uint256)" "$ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
    --rpc-url "$RPC_URL" \
    --private-key "$ADMIN_PK" >/dev/null
done
echo

echo "=== 3) Stakes: V1 very short, V2 longer ==="
NOW_TS="$(date +%s)"
V1_END=$((NOW_TS + 5))      # 5 seconds
V2_END=$((NOW_TS + 300))    # 5 minutes

echo "Voter1 stake ends at: $V1_END (will expire before vote)"
echo "Voter2 stake ends at: $V2_END (still active at vote)"
echo

echo "Voter1 short stake"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$V1_END" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 longer stake"
cast send "$VV_TOKEN_ADDR" "approve(address,uint256)" "$STAKING_ADDR" "$VOTER_STAKE_AMOUNT_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null
cast send "$STAKING_ADDR" "stake(uint256,uint256)" "$VOTER_STAKE_AMOUNT_WEI" "$V2_END" \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null
echo

echo "=== 4) Wait for Voter1 stake to expire ==="
sleep 7
echo "Time passed, Voter1 stake should now be expired."
echo

echo "=== 5) Both voters cast YES, but only Voter2 has power ==="
echo "Voter1 votes YES (0 voting power expected)"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER1_PK" >/dev/null

echo "Voter2 votes YES (full voting power)"
cast send "$VOTING_ADDR" "vote(bool)" true \
  --rpc-url "$RPC_URL" \
  --private-key "$VOTER2_PK" >/dev/null
echo

# echo "=== 6) Finalize and read NFT ==="
# cast send "$VOTING_ADDR" "finalize()" \
#   --rpc-url "$RPC_URL" \
#   --private-key "$ADMIN_PK" >/dev/null

RESULT="$(cast call "$VOTING_RESULT_ADDR" "getVotingResult(uint256)(string)" 0 \
  --rpc-url "$RPC_URL")"
echo "VotingResult NFT[0]: $RESULT"
echo

echo "Done: stake_expires_before_vote."

