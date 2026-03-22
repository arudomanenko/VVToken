// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VVToken} from "../src/VVToken.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    VVToken internal token;
    Staking internal staking;
    address internal alice = address(0xA1);

    function setUp() public {
        token = new VVToken(1_000_000 ether);
        staking = new Staking(address(token));
        token.transfer(alice, 10_000 ether);
    }

    function test_stakeTransfersTokensAndRecordsInfo() public {
        uint256 amount = 1_000 ether;
        uint256 end = block.timestamp + 1 weeks;
        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount, end);
        vm.stopPrank();
        assertEq(token.balanceOf(address(staking)), amount);
        Staking.StakeInfo[] memory s = staking.getStakeInfo(alice);
        assertEq(s[0].stakedAmount, amount);
        assertEq(s[0].endTimestamp, end);
    }

    function test_unstakeReturnsFullBalance() public {
        uint256 amount = 1_000 ether;
        vm.startPrank(alice);
        token.approve(address(staking), amount);
        staking.stake(amount, block.timestamp + 1 weeks);
        uint256 before = token.balanceOf(alice);
        staking.unstake(0);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), before + amount);
        assertEq(staking.getStakeInfo(alice)[0].stakedAmount, 0);
    }

    function test_stakeDurationTooShortReverts() public {
        vm.startPrank(alice);
        token.approve(address(staking), 1 ether);
        vm.expectRevert();
        staking.stake(1 ether, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_pauseBlocksStake() public {
        staking.pause();
        vm.startPrank(alice);
        token.approve(address(staking), 1 ether);
        vm.expectRevert();
        staking.stake(1 ether, block.timestamp + 1 weeks);
        vm.stopPrank();
    }
}
