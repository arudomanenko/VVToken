// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VVToken} from "./VVToken.sol";

contract Staking is ReentrancyGuard {
    VVToken public token;

    struct StakeInfo {
        uint256 stakedAmount;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    mapping(address => StakeInfo[]) public stakeInfos;

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = VVToken(_tokenAddress);
    }

    function stake(uint256 amount, uint256 expiredAt) external nonReentrant {
        require(
            expiredAt > block.timestamp,
            "Expired at must be in the future"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
        stakeInfos[msg.sender].push(
            StakeInfo({
                stakedAmount: amount,
                startTimestamp: block.timestamp,
                endTimestamp: expiredAt
            })
        );
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        StakeInfo[] storage userStakes = stakeInfos[msg.sender];
        require(stakeIndex < userStakes.length, "Invalid stake index");
        StakeInfo memory s = userStakes[stakeIndex];
        require(block.timestamp >= s.endTimestamp, "Stake not yet expired");

        uint256 amount = s.stakedAmount;
        userStakes[stakeIndex] = userStakes[userStakes.length - 1];
        userStakes.pop();

        SafeERC20.safeTransfer(token, msg.sender, amount);
    }

    function getStakeInfo(address userAddress) public view returns (StakeInfo[] memory) {
        return stakeInfos[userAddress];
    }
}
