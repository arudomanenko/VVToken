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

    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event VoteCreated(bytes32 indexed voteId, uint256 deadline, uint256 votingPowerThreshold, string description);
    event Voted(bytes32 indexed voteId, address indexed voter, bool vote, uint256 votingPower);
    event VotingFinalized(bytes32 indexed voteId, string result, uint256 yesVotes, uint256 noVotes);

    Staking public staking;
    VotingResult public votingResult;

    address public admin;

    mapping(bytes32 => VotingInfo) public votes;
    bytes32[] public voteIds;

    mapping(bytes32 => mapping(address => bool)) public usersVoted;
    mapping(bytes32 => mapping(address => bool)) public usersVote;

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        require(msg.sender == admin, "Caller is not the admin");
    }

    constructor(
        address _stakingAddress,
        address _votingResultAddress,
        address _creator,
        address _admin
    ) Ownable(_creator) {
        staking = Staking(_stakingAddress);
        votingResult = VotingResult(_votingResultAddress);
        _setAdmin(_admin);
    }
    function setAdmin(address newAdmin) external onlyOwner {
        _setAdmin(newAdmin);
    }

    function createVote(
        uint256 deadline,
        uint256 votingPowerThreshold,
        string calldata description
    ) external onlyAdmin returns (bytes32 voteId) {
        require(deadline > block.timestamp, "Deadline must be in the future");
        require(votingPowerThreshold > 0, "Threshold must be positive");

        voteId = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, description));
        require(votes[voteId].deadline == 0, "Vote ID collision");

        votes[voteId] = VotingInfo({
            id: voteId,
            deadline: deadline,
            votingPowerThreshold: votingPowerThreshold,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            isOver: false
        });
        voteIds.push(voteId);

        emit VoteCreated(voteId, deadline, votingPowerThreshold, description);
    }

    function vote(bytes32 voteId, bool userVote) public nonReentrant whenNotPaused {
        VotingInfo storage vi = votes[voteId];
        require(vi.deadline != 0, "Vote does not exist");
        require(!vi.isOver, "Voting is over");
        require(block.timestamp < vi.deadline, "Voting deadline passed");
        require(!usersVoted[voteId][msg.sender], "Already voted");

        uint256 vp = _getVotingPower(msg.sender);
        require(vp > 0, "No active voting power");

        usersVoted[voteId][msg.sender] = true;
        usersVote[voteId][msg.sender] = userVote;
        _applyNcheckVote(voteId, userVote, vp);

        emit Voted(voteId, msg.sender, userVote, vp);
    }

    function finalize(bytes32 voteId) public nonReentrant onlyAdmin {
        VotingInfo storage vi = votes[voteId];
        require(vi.deadline != 0, "Vote does not exist");
        require(!vi.isOver, "Voting already finalized");
        require(block.timestamp >= vi.deadline, "Deadline not reached");
        _endVoting(voteId, vi.yesVotes > vi.noVotes ? "Yes" : "No");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function getVoteInfo(bytes32 voteId) public view returns (VotingInfo memory) {
        return votes[voteId];
    }

    function getAllVoteIds() public view returns (bytes32[] memory) {
        return voteIds;
    }

    function getVoterInfo(
        bytes32 voteId,
        address voter
    ) public view returns (VoterInfo memory) {
        return VoterInfo({
            hasVoted: usersVoted[voteId][voter],
            vote: usersVote[voteId][voter]
        });
    }


    function _setAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "Admin cannot be zero address");
        emit AdminSet(admin, newAdmin);
        admin = newAdmin;
    }

    function _applyNcheckVote(bytes32 voteId, bool isYesVote, uint256 vp) internal {
        VotingInfo storage vi = votes[voteId];
        if (isYesVote) {
            vi.yesVotes += vp;
            if (vi.yesVotes >= vi.votingPowerThreshold) {
                _endVoting(voteId, "Yes");
            }
        } else {
            vi.noVotes += vp;
            if (vi.noVotes >= vi.votingPowerThreshold) {
                _endVoting(voteId, "No");
            }
        }
    }

    function _endVoting(bytes32 voteId, string memory result) internal {
        VotingInfo storage vi = votes[voteId];
        vi.isOver = true;
        votingResult.mintVotingResult(owner(), result);
        emit VotingFinalized(voteId, result, vi.yesVotes, vi.noVotes);
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
