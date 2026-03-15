// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Staking} from "./Staking.sol";

contract Voting is ReentrancyGuard, Ownable {
    Staking public staking;

    struct VotingInfo {
        bytes32 id;
        uint256 deadline;
        uint256 votingPowerThreshold;
        string description;
        uint256 yesVotes;
    }

    struct UserVote {
        bool vote;
        uint256 votingPower;
    }

    VotingInfo public votingInfo;
    mapping(address => UserVote) public currentVotes;
    address[] public voters;

    constructor(
        address _stakingAddress,
        VotingInfo memory _votingInfo
    ) Ownable(msg.sender) {
        staking = Staking(_stakingAddress);
        votingInfo = _votingInfo;
    }

    function vote(bool userVote) public nonReentrant {
        uint256 votingPower = _getVotingPower(msg.sender);
        voters.push(msg.sender);
        currentVotes[msg.sender] = UserVote({
            vote: userVote,
            votingPower: votingPower
        });
    }

    function finalize() public onlyOwner nonReentrant returns (bool) {
        for (uint256 i = 0; i < voters.length; i++) {
            UserVote memory userVote = currentVotes[voters[i]];
            if (userVote.vote) {
                votingInfo.yesVotes += userVote.votingPower;
            }
        }

        for (uint256 i = 0; i < voters.length; i++) {
            staking.unstakeAllFor(voters[i]);
        }

        return votingInfo.yesVotes >= votingInfo.votingPowerThreshold;
    }

    function getCurrentVoteInfo() public view returns (VotingInfo memory) {
        return votingInfo;
    }

    function _getVotingPower(address user) internal view returns (uint256) {
        Staking.StakeInfo[] memory stakeInfos = staking.getStakeInfo(user);
        uint256 vp = 0;
        for (uint256 i = 0; i < stakeInfos.length; i++) {
            Staking.StakeInfo memory si = stakeInfos[i];
            if (si.endTimestamp <= block.timestamp) continue;
            uint256 dRemain = si.endTimestamp - block.timestamp;
            vp += si.stakedAmount * dRemain;
        }
        return vp;
    }
}
