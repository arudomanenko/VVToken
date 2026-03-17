// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VVToken} from "../src/VVToken.sol";
import {Staking} from "../src/Staking.sol";
import {Voting} from "../src/Voting.sol";
import {VotingResult} from "../src/VotingResult.sol";

contract Deploy is Script {
    uint256 public constant DEFAULT_INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function run() public {
        uint256 initialSupply = vm.envOr(
            "INITIAL_SUPPLY",
            DEFAULT_INITIAL_SUPPLY
        );

        vm.startBroadcast();

        VVToken vvToken = new VVToken(initialSupply);
        console.log("VVToken deployed at:", address(vvToken));

        Staking staking = new Staking(address(vvToken));
        console.log("Staking deployed at:", address(staking));

        VotingResult votingResult = new VotingResult();
        console.log("VotingResult deployed at:", address(votingResult));

        uint256 deadline = block.timestamp + 7 days;
        uint256 threshold = vm.envOr(
            "VOTING_POWER_THRESHOLD",
            uint256(1_000_000 * 10 ** 18)
        );
        string memory description = vm.envOr(
            "VOTING_DESCRIPTION",
            string("Initial governance proposal")
        );

        Voting.VotingInfo memory votingInfo = Voting.VotingInfo({
            id: keccak256(abi.encodePacked(block.timestamp, "initial")),
            deadline: deadline,
            votingPowerThreshold: threshold,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            isOver: false
        });

        Voting voting = new Voting(
            address(staking),
            votingInfo,
            address(votingResult),
            tx.origin
        );
        console.log("Voting deployed at:", address(voting));

        staking.setVoting(address(voting));
        votingResult.setVotingContract(address(voting));

        vm.stopBroadcast();
    }
}
