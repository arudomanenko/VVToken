// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {VVToken} from "./VVToken.sol";

contract Staking is ReentrancyGuard, Ownable, Pausable {
    struct StakeInfo {
        uint256 stakedAmount;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    event StakeCreated(
        address indexed user,
        uint256 indexed index,
        uint256 amount,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    event StakeUnstaked(
        address indexed user,
        uint256 indexed index,
        uint256 amount
    );

    uint256 public constant MIN_STAKE_DURATION = 1 weeks;
    uint256 public constant MAX_STAKE_DURATION = 4 weeks;

    VVToken public token;

    mapping(address => StakeInfo[]) public stakeInfos;

    constructor(address _tokenAddress) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = VVToken(_tokenAddress);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function stake(uint256 amount, uint256 expiredAt) external nonReentrant whenNotPaused {
        require(
            expiredAt > block.timestamp,
            "Expired at must be in the future"
        );
        uint256 duration = expiredAt - block.timestamp;
        require(duration >= MIN_STAKE_DURATION, "Stake duration too short");
        require(duration <= MAX_STAKE_DURATION, "Stake duration too long");
        require(amount > 0, "Amount must be greater than 0");

        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
        stakeInfos[msg.sender].push(
            StakeInfo({
                stakedAmount: amount,
                startTimestamp: block.timestamp,
                endTimestamp: expiredAt
            })
        );

        uint256 newIndex = stakeInfos[msg.sender].length - 1;

        emit StakeCreated(
            msg.sender,
            newIndex,
            amount,
            block.timestamp,
            expiredAt
        );
    }

    function unstake(uint256 stakeIndex) external nonReentrant whenNotPaused {
        StakeInfo[] storage userStakes = stakeInfos[msg.sender];
        require(stakeIndex < userStakes.length, "Invalid stake index");
        StakeInfo storage s = userStakes[stakeIndex];
        require(s.stakedAmount > 0, "Already unstaked");

        uint256 amount = s.stakedAmount;
        s.stakedAmount = 0;

        SafeERC20.safeTransfer(token, msg.sender, amount);
        emit StakeUnstaked(msg.sender, stakeIndex, amount);
    }

    function getStakeInfo(
        address userAddress
    ) public view returns (StakeInfo[] memory) {
        require(userAddress != address(0), "Invalid user address");
        return stakeInfos[userAddress];
    }
}
