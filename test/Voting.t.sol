// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VVToken} from "../src/VVToken.sol";
import {Staking} from "../src/Staking.sol";
import {Voting} from "../src/Voting.sol";
import {VotingResult} from "../src/VotingResult.sol";

contract VotingTest is Test {
    VVToken internal token;
    Staking internal staking;
    Voting internal voting;
    VotingResult internal votingResult;
    address internal admin = address(0xAD);
    address internal alice = address(0xA1);

    function setUp() public {
        token = new VVToken(1_000_000 ether);
        staking = new Staking(address(token));
        votingResult = new VotingResult();
        voting = new Voting(address(staking), address(votingResult), address(this), admin);
        votingResult.addMinter(address(voting));
        token.transfer(alice, 50_000 ether);
        vm.startPrank(alice);
        token.approve(address(staking), 50_000 ether);
        staking.stake(50_000 ether, block.timestamp + 2 weeks);
        vm.stopPrank();
    }

    function test_voteYesClosesProposalWhenThresholdReached() public {
        vm.prank(admin);
        bytes32 id = voting.createVote(block.timestamp + 7 days, 1, "upgrade");
        vm.prank(alice);
        voting.vote(id, true);
        Voting.VotingInfo memory vi = voting.getVoteInfo(id);
        assertTrue(vi.isOver);
        assertGt(vi.yesVotes, 0);
    }

    function test_finalizeAfterDeadlineRecordsNoWhenNoVotes() public {
        uint256 deadline = block.timestamp + 3 days;
        vm.prank(admin);
        bytes32 id = voting.createVote(deadline, 1_000_000 ether, "upgrade");
        vm.warp(deadline);
        vm.prank(admin);
        voting.finalize(id);
        assertTrue(voting.getVoteInfo(id).isOver);
        assertEq(votingResult.getVotingResult(0), "No");
    }

    function test_voteWithoutStakeReverts() public {
        vm.prank(admin);
        bytes32 id = voting.createVote(block.timestamp + 7 days, 1, "upgrade");
        vm.prank(address(0xDEAD));
        vm.expectRevert();
        voting.vote(id, true);
    }

    function test_doubleVoteReverts() public {
        vm.prank(admin);
        bytes32 id = voting.createVote(block.timestamp + 7 days, 1_000_000 ether, "upgrade");
        vm.startPrank(alice);
        voting.vote(id, true);
        vm.expectRevert();
        voting.vote(id, true);
        vm.stopPrank();
    }

    function test_finalizedVoteMintedNFTToOwner() public {
        vm.prank(admin);
        bytes32 id = voting.createVote(block.timestamp + 7 days, 1, "upgrade");
        vm.prank(alice);
        voting.vote(id, true);
        assertEq(votingResult.ownerOf(0), address(this));
        assertEq(votingResult.getVotingResult(0), "Yes");
    }
}
