// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VVToken} from "./VVToken.sol";

contract Staking is ReentrancyGuard, Ownable {
    VVToken public token;
    address public voting;

    struct StakeInfo {
        uint256 stakedAmount;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    mapping(address => StakeInfo[]) public stakeInfos;

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

    constructor(address _tokenAddress) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = VVToken(_tokenAddress);
    }

    function setVoting(address _voting) external onlyOwner {
        voting = _voting;
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

        uint256 newIndex = stakeInfos[msg.sender].length - 1;
        emit StakeCreated(
            msg.sender,
            newIndex,
            amount,
            block.timestamp,
            expiredAt
        );
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        StakeInfo[] storage userStakes = stakeInfos[msg.sender];
        require(stakeIndex < userStakes.length, "Invalid stake index");
        StakeInfo memory s = userStakes[stakeIndex];

        uint256 amount = s.stakedAmount;
        userStakes[stakeIndex] = userStakes[userStakes.length - 1];
        userStakes.pop();

        SafeERC20.safeTransfer(token, msg.sender, amount);

        emit StakeUnstaked(msg.sender, stakeIndex, amount);
    }

    function getStakeInfo(address userAddress) public view returns (StakeInfo[] memory) {
        return stakeInfos[userAddress];
    }
}
