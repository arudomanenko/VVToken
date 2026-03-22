// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {VVToken} from "../src/VVToken.sol";
import {Staking} from "../src/Staking.sol";
import {Voting} from "../src/Voting.sol";
import {VotingResult} from "../src/VotingResult.sol";

contract Deploy is Script {
    uint256 public constant DEFAULT_INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function run() public {
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", DEFAULT_INITIAL_SUPPLY);

        address deployer = tx.origin;
        address admin    = vm.envOr("VOTING_ADMIN", deployer);

        vm.startBroadcast();

        VVToken vvToken = new VVToken(initialSupply);
        Staking staking = new Staking(address(vvToken));
        VotingResult votingResult = new VotingResult();

        Voting voting = new Voting(
            address(staking),
            address(votingResult),
            deployer,
            admin
        );

        votingResult.addMinter(address(voting));

        uint256 deadline  = block.timestamp + vm.envOr("VOTING_DEADLINE_OFFSET", uint256(7 days));
        uint256 threshold = vm.envOr("VOTING_POWER_THRESHOLD", uint256(1_000_000 * 10 ** 18));
        string memory description = vm.envOr("VOTING_DESCRIPTION", string("Initial governance proposal"));

        voting.createVote(deadline, threshold, description);

        vm.stopBroadcast();
    }
}
