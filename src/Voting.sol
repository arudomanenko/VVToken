// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Staking} from "./Staking.sol";
import {VotingResult} from "./VotingResult.sol";

contract Voting is ReentrancyGuard, Ownable, Pausable {
    struct VotingInfo {
        bytes32 id;
        uint256 deadline;
        uint256 votingPowerThreshold;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool isOver;
    }

    struct VoterInfo {
        bool hasVoted;
        bool vote;
    }

    event Voted(address indexed voter, bool vote, uint256 votingPower);
    event VotingFinalized(string result, uint256 yesVotes, uint256 noVotes);

    Staking public staking;
    VotingInfo public votingInfo;

    mapping(address => bool) public usersVoted;
    mapping(address => bool) public usersVote;

    VotingResult public votingResult;

    constructor(
        address _stakingAddress,
        VotingInfo memory _votingInfo,
        address _votingResultAddress,
        address _creator
    ) Ownable(_creator) {
        staking = Staking(_stakingAddress);
        votingInfo = _votingInfo;
        votingResult = VotingResult(_votingResultAddress);
    }

    function vote(bool userVote) public nonReentrant whenNotPaused {
        require(!votingInfo.isOver, "Voting is over");
        require(
            block.timestamp < votingInfo.deadline,
            "Voting deadline passed"
        );
        require(!usersVoted[msg.sender], "Already voted");

        uint256 vp = _getVotingPower(msg.sender);
        require(vp > 0, "No active voting power");

        usersVoted[msg.sender] = true;
        usersVote[msg.sender] = userVote;
        _applyNcheckVote(userVote, vp);

        emit Voted(msg.sender, userVote, vp);
    }

    function finalize() public nonReentrant onlyOwner {
        require(!votingInfo.isOver, "Voting already finalized");
        require(block.timestamp >= votingInfo.deadline, "Deadline not reached");
        _endVoting(votingInfo.yesVotes > votingInfo.noVotes ? "Yes" : "No");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getCurrentVoteInfo() public view returns (VotingInfo memory) {
        return votingInfo;
    }

    function getVoterInfo(
        address voter
    ) public view returns (VoterInfo memory) {
        return VoterInfo({hasVoted: usersVoted[voter], vote: usersVote[voter]});
    }

    function _applyNcheckVote(bool isYesVote, uint256 vp) internal {
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
        votingInfo.isOver = true;
        votingResult.mintVotingResult(owner(), result);
        emit VotingFinalized(result, votingInfo.yesVotes, votingInfo.noVotes);
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
