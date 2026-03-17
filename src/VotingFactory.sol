// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Staking} from "./Staking.sol";
import {Voting} from "./Voting.sol";
import {VotingResult} from "./VotingResult.sol";

contract VotingFactory is Ownable {
    Staking public immutable staking;
    VotingResult public immutable votingResult;

    mapping(bytes32 => bool) public usedVotingIds;

    event VotingCreated(
        address indexed votingAddress,
        bytes32 indexed id,
        address indexed creator
    );

    constructor(
        address _stakingAddress,
        address _votingResultAddress
    ) Ownable(msg.sender) {
        require(_stakingAddress != address(0), "Invalid staking address");
        require(
            _votingResultAddress != address(0),
            "Invalid voting result address"
        );
        staking = Staking(_stakingAddress);
        votingResult = VotingResult(_votingResultAddress);
    }

    function createVoting(
        bytes32 id,
        uint256 deadline,
        uint256 votingPowerThreshold,
        string memory description
    ) external returns (address) {
        require(id != bytes32(0), "Invalid id");
        require(!usedVotingIds[id], "ID already used");
        require(deadline > block.timestamp, "Deadline must be in the future");
        require(votingPowerThreshold > 0, "Threshold must be > 0");

        usedVotingIds[id] = true;

        Voting.VotingInfo memory info = Voting.VotingInfo({
            id: id,
            deadline: deadline,
            votingPowerThreshold: votingPowerThreshold,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            isOver: false
        });

        Voting voting = new Voting(
            address(staking),
            info,
            address(votingResult),
            msg.sender
        );

        emit VotingCreated(address(voting), id, msg.sender);

        return address(voting);
    }
}

