// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Staking} from "./Staking.sol";
import {VotingResult} from "./VotingResult.sol";

contract Voting is ReentrancyGuard, Ownable {
    struct VotingInfo {
        bytes32 id;
        uint256 deadline;
        uint256 votingPowerThreshold;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool isOver;
    }

    Staking public staking;
    VotingInfo public votingInfo;
    address public creator;

    mapping(address => bool) public usersVoted;
    mapping(address => bool) public usersVote;

    VotingResult public votingResult;

    constructor(
        address _stakingAddress,
        VotingInfo memory _votingInfo,
        address _votingResultAddress,
        address _creator
    ) Ownable(msg.sender) {
        staking = Staking(_stakingAddress);
        votingInfo = _votingInfo;
        votingResult = VotingResult(_votingResultAddress);
        creator = _creator;
    }

    function vote(bool userVote) public nonReentrant {
        require(votingInfo.isOver == false, "Voting is over");
        require(
            block.timestamp < votingInfo.deadline,
            "Voting deadline passed"
        );
        require(usersVoted[msg.sender] == false, "Already voted");

        usersVoted[msg.sender] = true;
        _applyNcheckVote(msg.sender, userVote);
        usersVote[msg.sender] = userVote;
    }

    function finalize() public nonReentrant {
        require(msg.sender == creator, "Only creator can finalize");
        require(!votingInfo.isOver, "Voting already finalized");

        string memory result = "No consensus";
        if (votingInfo.yesVotes >= votingInfo.votingPowerThreshold) {
            result = "Yes";
        } else if (votingInfo.noVotes >= votingInfo.votingPowerThreshold) {
            result = "No";
        }

        _endVoting(result);
    }

    

    function getCurrentVoteInfo() public view returns (VotingInfo memory) {
        return votingInfo;
    }

    function _applyNcheckVote(address voter, bool isYesVote) internal {
        uint256 vp = _getVotingPower(voter);
        if (isYesVote) {
            votingInfo.yesVotes += vp;
            if (votingInfo.yesVotes >= votingInfo.votingPowerThreshold) {
                _endVoting("Yes");
            }
        } else {
            votingInfo.noVotes += vp;
            if (votingInfo.noVotes >= votingInfo.votingPowerThreshold) {
                _endVoting("No");
            }
        }
    }

    function _endVoting(string memory result) internal {
        if (votingInfo.isOver) {
            return;
        }

        votingInfo.isOver = true;
        votingResult.mintVotingResult(creator, result);
    }

    function _getVotingPower(address user) internal view returns (uint256) {
        Staking.StakeInfo[] memory stakeInfos = staking.getStakeInfo(user);
        uint256 vp = 0;
        for (uint256 i = 0; i < stakeInfos.length; i++) {
            Staking.StakeInfo memory si = stakeInfos[i];
            if (si.endTimestamp <= block.timestamp) continue;
            uint256 dRemain = si.endTimestamp - block.timestamp;
            vp += si.stakedAmount * dRemain * dRemain;
        }
        return vp;
    }
}
