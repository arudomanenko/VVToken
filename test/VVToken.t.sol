// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VVToken} from "../src/VVToken.sol";

contract VVTokenTest is Test {
    VVToken internal token;
    address internal alice = address(0xA1);

    function setUp() public {
        token = new VVToken(1_000_000 ether);
    }

    function test_deploySetsTotalSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 ether);
        assertEq(token.balanceOf(address(this)), 1_000_000 ether);
    }

    function test_ownerCanMint() public {
        token.mint(alice, 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
    }

    function test_nonOwnerMintReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1 ether);
    }
}
