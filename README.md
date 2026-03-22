# VVToken

ERC20 (`VVToken`), time-locked staking (`Staking`), governance voting (`Voting`), and result NFTs (`VotingResult`).


## How voting works

Roles:

- **Owner** (`Voting`): Ownable; receives result NFTs; can `pause` / `unpause` (with `Staking` owner for staking side).
- **Admin** (`Voting`): creates votes and calls `finalize` after the deadline. Set at deploy via `VOTING_ADMIN` or defaults to the deployer.


A vote can end in two ways:

1. **Early**: total yes or no weighted power reaches `votingPowerThreshold` (set when the vote was created).
2. **After deadline**: the admin calls `finalize(voteId)` once `block.timestamp >= deadline`.

When a vote ends, a **VotingResult** ERC721 is minted to the `Voting` **owner** (not the voter), with the outcome string (`"Yes"` or `"No"`) as the token URI.

---

## What to call (typical flow)

**Sepolia (chain id `11155111`) — current deployment**

| Contract | Address |
|----------|---------|
| `VVToken` | `0xB2297aFF52F6B8C7B509385EE627E82CB784C0cf` |
| `Staking` | `0xF4653cAc1Df8221AfF32D760A278A5451C011c64` |
| `VotingResult` | `0x5C188038731Cad3b0DF8462f342b8a4d905C1A37` |
| `Voting` | `0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53` |

Example `unstake` (replace `0` with your stake index from `getStakeInfo`):

```bash
cast send 0xF4653cAc1Df8221AfF32D760A278A5451C011c64 "unstake(uint256)" 0 \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY"
```

### Discover votes and vote

List vote IDs:

```bash
cast call 0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53 "getAllVoteIds()(bytes32[])" --rpc-url "$SEPOLIA_RPC_URL"
```

Inspect one vote (`VOTE_ID` is the hex `bytes32` from `getAllVoteIds`, e.g. `export VOTE_ID=0x…`):

```bash
cast call 0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53 "getVoteInfo(bytes32)((bytes32,uint256,uint256,string,uint256,uint256,bool))" "$VOTE_ID" --rpc-url "$SEPOLIA_RPC_URL"
```

Cast a ballot (`true` = yes, `false` = no):

```bash
cast send 0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53 "vote(bytes32,bool)" "$VOTE_ID" true \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY"
```

You need non-zero voting power, must vote before `deadline`, and can only vote once per `(voteId, address)`.

### Finalize (admin only, if vote did not end early)

After the deadline:

```bash
cast send 0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53 "finalize(bytes32)" "$VOTE_ID" \
  --rpc-url "$SEPOLIA_RPC_URL" --private-key "$ADMIN_PRIVATE_KEY"
```

### Useful views

| Contract | Address | Function | Purpose |
|----------|---------|----------|---------|
| `Staking` | `0xF4653cAc1Df8221AfF32D760A278A5451C011c64` | `getStakeInfo(address)` | Your stakes (amount, start, end) |
| `Voting` | `0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53` | `getVoteInfo(bytes32)` | Deadline, threshold, tallies, `isOver` |
| `Voting` | `0x13EfAa9f13730C29Bb61bC349aaDa7aF69a5EB53` | `getVoterInfo(bytes32,address)` | Whether you voted and your side |
| `VotingResult` | `0x5C188038731Cad3b0DF8462f342b8a4d905C1A37` | `getVotingResult(uint256)` | Outcome string for NFT `tokenId` |

---

## Pause

`Voting` and `Staking` each implement `Pausable`; staking and voting transactions revert while paused. Pausing is restricted to the respective **owner** of each contract (not the voting admin).

### Local scenario scripts (`test_scenations`, Anvil)

Run `anvil` in one terminal (default RPC `http://127.0.0.1:8545`). From the repo root, install watcher deps once with `npm install --prefix test_scenations`, then run a script such as `bash test_scenations/test_scenario_average.sh` (see also `test_scenario_short_locks_vs_long_locks.sh` and `test_scenario_stake_expires_before_vote.sh`). Override `RPC_URL` if your node is not on the default host or port.

---