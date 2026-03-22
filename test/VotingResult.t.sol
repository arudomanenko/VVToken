// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VotingResult} from "../src/VotingResult.sol";

contract VotingResultTest is Test {
    VotingResult internal vr;
    address internal alice = address(0xA1);
    address internal stranger = address(0x99);

    function setUp() public {
        vr = new VotingResult();
    }

    function test_ownerMintsNFTWithURI() public {
        vr.mintVotingResult(alice, "Yes");
        assertEq(vr.ownerOf(0), alice);
        assertEq(vr.getVotingResult(0), "Yes");
        assertEq(vr.nextTokenId(), 1);
    }

    function test_authorizedMinterCanMint() public {
        vr.addMinter(stranger);
        vm.prank(stranger);
        vr.mintVotingResult(alice, "No");
        assertEq(vr.ownerOf(0), alice);
    }

    function test_unauthorizedMinterReverts() public {
        vm.prank(stranger);
        vm.expectRevert();
        vr.mintVotingResult(alice, "Yes");
    }

    function test_removeMinterRevokesAccess() public {
        vr.addMinter(stranger);
        vr.removeMinter(stranger);
        vm.prank(stranger);
        vm.expectRevert();
        vr.mintVotingResult(alice, "Yes");
    }
}
